import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/terminal_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../sync/local_master_server.dart';

class PinAuthService {
  PinAuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static Future<bool>? _refreshing;

  static List<String> _apiBases(TerminalConfig config) {
    final local = LocalMasterServer.clientBaseUrl();
    final cloud = config.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    return [
      if (local != null && local.isNotEmpty) local,
      if (local != cloud) cloud,
    ];
  }

  static String pinVerifier(String userId, String pin) {
    return sha256.convert(utf8.encode('itara-pos|$userId|$pin')).toString();
  }

  Future<({
    String name,
    String id,
    String token,
    String refreshToken,
    int expiresIn,
    List<String> permissions,
    List<String> roles,
  })> login(String pin) async {
    final config = TerminalConfigRepository.instance.config;
    if (config.tenantId.isEmpty) {
      throw Exception('Tenant ID manquant. Configurez le terminal.');
    }

    final bases = _apiBases(config);

    http.Response? response;
    Object? lastError;
    for (final base in bases) {
      try {
        response = await _client
            .post(
              Uri.parse('$base/auth/pin-login'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'X-Tenant-ID': config.tenantId,
              },
              body: jsonEncode({
                'pin': pin,
                'device_name': config.deviceName.isEmpty ? 'pos-mobile' : config.deviceName,
                if (config.deviceId.isNotEmpty) 'device_id': config.deviceId,
                if (config.deviceIdentifier.isNotEmpty) 'device_identifier': config.deviceIdentifier,
              }),
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200 || response.statusCode == 422) break;
      } catch (error) {
        lastError = error;
      }
    }

    if (response == null || response.statusCode >= 500) {
      final offline = _offlineSession(pin);
      if (offline != null) return offline;
      if (config.pinVerifier.isNotEmpty) {
        throw Exception('PIN refusé');
      }
      throw Exception(lastError?.toString() ?? 'Serveur injoignable');
    }

    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}

    if (response.statusCode != 200) {
      final errors = body['errors'] as Map<String, dynamic>?;
      final pinError = (errors?['pin'] as List?)?.first?.toString();
      final deviceError = (errors?['device_id'] as List?)?.first?.toString();
      throw Exception(pinError ?? deviceError ?? body['message']?.toString() ?? 'PIN refusé');
    }

    final user = body['user'] as Map<String, dynamic>? ?? {};
    final token = body['access_token'] as String? ?? '';
    if (token.isEmpty) {
      throw Exception('Jeton d\'accès absent');
    }

    final userId = user['id'] as String? ?? '';
    await _heartbeat(token, config);
    return (
      name: user['name'] as String? ?? 'Caissier',
      id: userId,
      token: token,
      refreshToken: body['refresh_token'] as String? ?? '',
      expiresIn: (body['expires_in'] as num?)?.toInt() ?? 3600,
      permissions: _stringList(user['permissions']),
      roles: _stringList(user['roles']),
    );
  }

  ({
    String name,
    String id,
    String token,
    String refreshToken,
    int expiresIn,
    List<String> permissions,
    List<String> roles,
  })? _offlineSession(String pin) {
    final config = TerminalConfigRepository.instance.config;
    if (config.pinVerifier.isEmpty || config.authToken.isEmpty || config.cashierId.isEmpty) return null;
    if (pinVerifier(config.cashierId, pin) != config.pinVerifier) return null;
    return (
      name: config.cashierName.isEmpty ? 'Caissier' : config.cashierName,
      id: config.cashierId,
      token: config.authToken,
      refreshToken: config.refreshToken,
      expiresIn: 3600,
      permissions: config.permissions,
      roles: config.roles,
    );
  }

  Future<void> _heartbeat(String token, TerminalConfig config) async {
    if (config.deviceId.isEmpty || token.isEmpty) return;
    final bases = _apiBases(config);
    for (final base in bases) {
      try {
        final response = await _client
            .post(
              Uri.parse('$base/devices/${config.deviceId}/heartbeat'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
                if (config.tenantId.isNotEmpty) 'X-Tenant-ID': config.tenantId,
              },
              body: jsonEncode({
                'app_version': '0.1.0',
                if (config.masterHost.isNotEmpty) 'local_server': config.masterHost,
              }),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 || response.statusCode == 403) return;
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>?> downloadCompanyProfile({
    required String token,
    required String tenantId,
  }) async {
    final config = TerminalConfigRepository.instance.config;
    final bases = _apiBases(config);

    for (final base in bases) {
      try {
        final response = await _client
            .get(
              Uri.parse('$base/tenant/profile'),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
                if (tenantId.isNotEmpty) 'X-Tenant-ID': tenantId,
              },
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['data'] is Map<String, dynamic>) {
          return decoded['data'] as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    return null;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }

  static Future<bool> refreshIfNeeded({bool force = false}) {
    final pending = _refreshing;
    if (pending != null) return pending;
    final run = _refreshIfNeeded(force: force);
    _refreshing = run;
    return run.whenComplete(() {
      if (identical(_refreshing, run)) _refreshing = null;
    });
  }

  static Future<bool> _refreshIfNeeded({required bool force}) async {
    final repo = TerminalConfigRepository.instance;
    final config = repo.config;
    final refreshToken = config.refreshToken.trim();
    if (refreshToken.isEmpty) return !force && config.authToken.trim().isNotEmpty;

    final expiresAt = DateTime.tryParse(config.tokenExpiresAt);
    final stillValid = expiresAt != null && expiresAt.isAfter(DateTime.now().add(const Duration(seconds: 90)));
    if (!force && stillValid && config.authToken.trim().isNotEmpty) return true;

    final bases = _apiBases(config);

    for (final base in bases.toSet()) {
      try {
        final response = await http
            .post(
              Uri.parse('$base/auth/refresh'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                if (config.tenantId.isNotEmpty) 'X-Tenant-ID': config.tenantId,
              },
              body: jsonEncode({'refresh_token': refreshToken}),
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) continue;
        final access = (decoded['access_token'] as String? ?? '').trim();
        if (access.isEmpty) continue;
        final nextRefresh = (decoded['refresh_token'] as String? ?? '').trim();
        final expiresIn = (decoded['expires_in'] as num?)?.toInt() ?? 3600;
        await repo.save(repo.config.copyWith(
          authToken: access,
          refreshToken: nextRefresh.isEmpty ? refreshToken : nextRefresh,
          tokenExpiresAt: DateTime.now().add(Duration(seconds: expiresIn)).toIso8601String(),
        ));
        return true;
      } catch (_) {}
    }
    return false;
  }

  static Future<void> signOut() async {
    final repo = TerminalConfigRepository.instance;
    try {
      await PinAuthService().logout();
    } catch (_) {}
    await repo.save(repo.config.copyWith(
      authToken: '',
      refreshToken: '',
      tokenExpiresAt: '',
      cashierId: '',
      cashierName: '',
      permissions: const [],
      roles: const [],
      pinVerifier: '',
      isSignedIn: false,
    ));
  }

  Future<void> logout() async {
    final config = TerminalConfigRepository.instance.config;
    if (config.authToken.isEmpty) return;
    final base = config.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    try {
      await _client
          .post(
            Uri.parse('$base/auth/logout'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer ${config.authToken}',
              if (config.tenantId.isNotEmpty) 'X-Tenant-ID': config.tenantId,
            },
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }
}
