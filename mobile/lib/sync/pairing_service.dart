import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../core/config/terminal_config.dart';
import '../core/config/terminal_config_repository.dart';
import '../core/logging/app_logger.dart';
import 'device_registry.dart';
import 'local_master_server.dart';
import 'local_realtime.dart';
import 'master_config_store.dart';
import 'pairing_models.dart';

export 'pairing_models.dart';

/// Secure pairing §8 :
/// Discovery → Handshake → Authentication → Pairing → Authorization → Register.
class PairingService extends ChangeNotifier {
  PairingService({AppLogger? logger})
      : _log = (logger ?? AppLogger()).tagged('pairing');

  static final PairingService instance = PairingService();

  final AppLogger _log;
  final _random = Random.secure();
  final _client = http.Client();
  final _pending = <String, PairingRequest>{};

  String? _code;
  DateTime? _expiresAt;
  Timer? _rotate;

  String? get activeCode =>
      _expiresAt != null && DateTime.now().isBefore(_expiresAt!) ? _code : null;

  DateTime? get expiresAt => _expiresAt;

  bool get hasActiveCode => activeCode != null;

  List<PairingRequest> get pendingRequests =>
      _pending.values.where((r) => !r.completer.isCompleted).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// QR affiché sur le Master (host + code courant).
  PairingQrPayload? get masterQrPayload {
    final server = LocalMasterServer.instance;
    final host = server.lanAddress;
    final code = activeCode;
    if (host == null || host.isEmpty || code == null) return null;
    final config = TerminalConfigRepository.instance.config;
    return PairingQrPayload(
      masterId: config.deviceId.isNotEmpty
          ? config.deviceId
          : config.deviceIdentifier,
      ip: host,
      port: LocalMasterServer.port,
      name: config.deviceName.isEmpty ? 'ITARA POS Master' : config.deviceName,
      code: code,
      tenantId: config.tenantId,
      branchId: config.storeId,
    );
  }

  void startMasterSession() {
    _rotate?.cancel();
    _issueCode();
    _rotate = Timer.periodic(const Duration(minutes: 4), (_) => _issueCode());
  }

  void stopMasterSession() {
    _rotate?.cancel();
    _rotate = null;
    _code = null;
    _expiresAt = null;
    for (final req in _pending.values) {
      if (!req.completer.isCompleted) {
        req.phase = PairingPhase.rejected;
        req.completer.complete(
          const PairingDecision.rejected(reason: 'Session Master arrêtée.'),
        );
      }
    }
    _pending.clear();
    notifyListeners();
  }

  void refreshCode() => _issueCode();

  void _issueCode() {
    _code = (_random.nextInt(900000) + 100000).toString();
    _expiresAt = DateTime.now().add(const Duration(minutes: 5));
    _log.pairing('Pairing code refreshed');
    notifyListeners();
  }

  bool validateCode(String code) {
    final active = activeCode;
    if (active == null) return false;
    return active == code.trim();
  }

  /// AUTHENTICATION : valide le code, crée une demande en attente d’ACCEPT/REJECT.
  Future<PairingDecision> submitPairRequest({
    required String code,
    required String deviceId,
    required String deviceName,
    required String deviceType,
    required String os,
    required String ip,
    required String role,
    required String version,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (!validateCode(code)) {
      throw Exception('Code d\'appairage invalide ou expiré.');
    }

    final id = const Uuid().v4();
    final request = PairingRequest(
      id: id,
      deviceId: deviceId.trim().isEmpty ? const Uuid().v4() : deviceId.trim(),
      deviceName: deviceName.trim().isEmpty ? 'POS Slave' : deviceName.trim(),
      deviceType: deviceType.trim().isEmpty ? 'pos' : deviceType.trim(),
      os: os,
      ip: ip,
      role: role.trim().isEmpty ? 'slave' : role.trim(),
      version: version,
      code: code.trim(),
    );
    _pending[id] = request;
    _log.pairing('Pair request pending id=$id name=${request.deviceName}');
    notifyListeners();

    try {
      return await request.completer.future.timeout(timeout, onTimeout: () {
        request.phase = PairingPhase.rejected;
        _pending.remove(id);
        notifyListeners();
        return const PairingDecision.rejected(
          reason: 'Délai d\'approbation dépassé.',
        );
      });
    } finally {
      _pending.remove(id);
      notifyListeners();
    }
  }

  /// AUTHORIZATION — Master ACCEPT → REGISTER DEVICE.
  Future<void> acceptRequest(String requestId) async {
    final request = _pending[requestId];
    if (request == null || request.completer.isCompleted) {
      throw Exception('Demande d\'appairage introuvable.');
    }
    if (!validateCode(request.code)) {
      request.phase = PairingPhase.rejected;
      request.completer.complete(
        const PairingDecision.rejected(reason: 'Code expiré.'),
      );
      _pending.remove(requestId);
      notifyListeners();
      return;
    }

    final result = await _registerDevice(
      deviceId: request.deviceId,
      deviceName: request.deviceName,
      deviceType: request.deviceType,
      os: request.os,
      ip: request.ip,
      role: request.role,
      version: request.version,
    );
    request.phase = PairingPhase.registered;
    request.completer.complete(PairingDecision.accepted(
      pairToken: result.pairToken,
      deviceId: result.device.id,
    ));
    _pending.remove(requestId);
    notifyListeners();
  }

  /// AUTHORIZATION — Master REJECT.
  void rejectRequest(String requestId, {String reason = 'Refusé par le Master.'}) {
    final request = _pending[requestId];
    if (request == null || request.completer.isCompleted) return;
    request.phase = PairingPhase.rejected;
    request.completer.complete(PairingDecision.rejected(reason: reason));
    _pending.remove(requestId);
    notifyListeners();
  }

  /// Compat : accept immédiat (tests / bootstrap) après validation code.
  Future<({String pairToken, LanDevice device})> acceptPair({
    required String code,
    required String deviceId,
    required String deviceName,
    required String deviceType,
    required String os,
    required String ip,
    required String role,
    required String version,
  }) async {
    if (!validateCode(code)) {
      throw Exception('Code d\'appairage invalide ou expiré.');
    }
    return _registerDevice(
      deviceId: deviceId,
      deviceName: deviceName,
      deviceType: deviceType,
      os: os,
      ip: ip,
      role: role,
      version: version,
    );
  }

  Future<({String pairToken, LanDevice device})> _registerDevice({
    required String deviceId,
    required String deviceName,
    required String deviceType,
    required String os,
    required String ip,
    required String role,
    required String version,
  }) async {
    final config = TerminalConfigRepository.instance.config;
    final id = deviceId.trim().isEmpty ? const Uuid().v4() : deviceId.trim();
    final token = const Uuid().v4().replaceAll('-', '');
    final device = LanDevice(
      id: id,
      name: deviceName.trim().isEmpty ? id : deviceName.trim(),
      deviceType: deviceType.trim().isEmpty ? 'pos' : deviceType.trim(),
      os: os,
      ip: ip,
      tenantId: config.tenantId,
      branchId: config.storeId,
      storeId: config.storeId,
      userId: '',
      userName: '',
      role: role.trim().isEmpty ? 'slave' : role.trim(),
      version: version,
      status: LanDeviceStatus.online,
      lastSeen: DateTime.now(),
      pairedAt: DateTime.now(),
      approved: true,
      pairTokenHash: DeviceRegistry.hashToken(token),
    );
    await DeviceRegistry.instance.upsert(device);
    _log.pairing('Device registered id=$id name=${device.name}');
    notifyListeners();
    return (pairToken: token, device: device);
  }

  /// Slave: POST /pair (attend ACCEPT Master) puis persiste le token.
  Future<void> pairWithMaster({
    required String host,
    required String code,
    String? masterDeviceId,
  }) async {
    final config = TerminalConfigRepository.instance.config;
    final base = LocalMasterServer.baseUrlForHost(host);
    final deviceId = config.deviceId.isNotEmpty
        ? config.deviceId
        : (config.deviceIdentifier.isNotEmpty
            ? config.deviceIdentifier
            : const Uuid().v4());

    // HANDSHAKE
    try {
      final handshake = await _client
          .get(Uri.parse('$base/discovery'), headers: {
            'Accept': 'application/json',
            if (config.tenantId.isNotEmpty) 'X-Tenant-ID': config.tenantId,
            if (config.storeId.isNotEmpty) 'X-Store-ID': config.storeId,
          })
          .timeout(const Duration(seconds: 5));
      if (handshake.statusCode >= 500) {
        throw Exception('Master injoignable (handshake).');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('handshake')) rethrow;
      // discovery endpoint optional — continue to pair
    }

    final response = await _client
        .post(
          Uri.parse('$base/pair'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            if (config.tenantId.isNotEmpty) 'X-Tenant-ID': config.tenantId,
            if (config.storeId.isNotEmpty) 'X-Store-ID': config.storeId,
            'X-Device-ID': deviceId,
            if (config.deviceName.isNotEmpty) 'X-Device-Name': config.deviceName,
          },
          body: jsonEncode({
            'code': code.trim(),
            'device_id': deviceId,
            'name': config.deviceName.isEmpty ? 'POS Slave' : config.deviceName,
            'device_type': 'pos',
            'os': defaultTargetPlatform.name,
            'tenant_id': config.tenantId,
            'branch_id': config.storeId,
            'store_id': config.storeId,
            'user_id': config.cashierId,
            'user_name': config.cashierName,
            'role': 'slave',
            'version': AppConfig.appVersion,
          }),
        )
        .timeout(const Duration(seconds: 100));

    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}

    if (response.statusCode != 200) {
      throw Exception(
        body['message']?.toString() ??
            'Appairage refusé (${response.statusCode})',
      );
    }

    final data = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : body;
    final token = data['pair_token']?.toString().trim() ?? '';
    final masterId =
        data['master_id']?.toString().trim() ?? masterDeviceId ?? '';
    if (token.isEmpty) {
      throw Exception('Jeton d\'appairage absent.');
    }

    await TerminalConfigRepository.instance.save(config.copyWith(
      masterHost: host.contains(':') ? host : '$host:${LocalMasterServer.port}',
      masterDeviceId: masterId.isEmpty ? config.masterDeviceId : masterId,
      deviceId: deviceId,
      masterPairToken: token,
      posRole: PosRole.slave,
    ));

    final shared = data['config'];
    if (shared is Map) {
      await MasterConfigStore.instance
          .applyToTerminal(Map<String, dynamic>.from(shared));
    }

    await LocalRealtimeClient.instance.startIfSlave();
    _log.pairing('Paired with master host=$host');
    notifyListeners();
  }

  /// Slave: appairage via QR scanné.
  Future<void> pairWithQr(String raw) async {
    final payload = PairingQrPayload.tryParse(raw);
    if (payload == null) {
      throw Exception('QR d\'appairage invalide.');
    }
    if (payload.code.isEmpty) {
      throw Exception('QR sans code — saisissez le code Master.');
    }
    await pairWithMaster(
      host: payload.hostEndpoint,
      code: payload.code,
      masterDeviceId: payload.masterId,
    );
  }
}
