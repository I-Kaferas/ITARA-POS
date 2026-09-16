import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/config/terminal_config_repository.dart';
import 'local_master_server.dart';
import 'sync_numbers.dart';

class DiscoveredMaster {
  const DiscoveredMaster({
    required this.host,
    required this.port,
    required this.name,
    required this.storeId,
    required this.seenAt,
  });

  final String host;
  final int port;
  final String name;
  final String storeId;
  final DateTime seenAt;

  String get url => LocalMasterServer.baseUrlForHost('$host:$port');
}

class LocalMasterDiscovery extends ChangeNotifier {
  LocalMasterDiscovery._();

  static final LocalMasterDiscovery instance = LocalMasterDiscovery._();
  static const beaconPort = 8002;

  RawDatagramSocket? _socket;
  Timer? _beacon;
  bool _started = false;
  final masters = <String, DiscoveredMaster>{};

  List<DiscoveredMaster> get visible {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 12));
    final config = TerminalConfigRepository.instance.config;
    return masters.values
        .where((item) => item.seenAt.isAfter(cutoff))
        .where((item) => config.storeId.isEmpty || item.storeId.isEmpty || item.storeId == config.storeId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, beaconPort, reuseAddress: true);
      socket.broadcastEnabled = true;
      _socket = socket;
      socket.listen(_onEvent);
    } catch (_) {
      _started = false;
      return;
    }
    _beacon = Timer.periodic(const Duration(seconds: 2), (_) => _announce());
    _announce();
  }

  void stop() {
    _started = false;
    _beacon?.cancel();
    _beacon = null;
    _socket?.close();
    _socket = null;
  }

  void _announce() {
    final socket = _socket;
    final server = LocalMasterServer.instance;
    if (socket == null || !server.listening) return;
    final host = server.lanAddress;
    if (host == null || host.isEmpty) return;
    final config = TerminalConfigRepository.instance.config;
    final payload = utf8.encode(jsonEncode({
      'service': 'itara-local-master',
      'host': host,
      'port': LocalMasterServer.port,
      'name': config.deviceName,
      'store_id': config.storeId,
      'device_id': config.deviceId,
    }));
    final targets = <String>{'255.255.255.255'};
    final parts = host.split('.');
    if (parts.length == 4) {
      targets.add('${parts[0]}.${parts[1]}.${parts[2]}.255');
    }
    for (final target in targets) {
      try {
        socket.send(payload, InternetAddress(target), beaconPort);
      } catch (_) {}
    }
  }

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final socket = _socket;
    if (socket == null) return;
    final packet = socket.receive();
    if (packet == null) return;
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(utf8.decode(packet.data));
      if (decoded is! Map) return;
      body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }
    if (body['service']?.toString() != 'itara-local-master') return;
    final host = body['host']?.toString().trim() ?? '';
    if (host.isEmpty || host == LocalMasterServer.instance.lanAddress) return;
    final found = DiscoveredMaster(
      host: host,
      port: syncAsInt(body['port'], LocalMasterServer.port),
      name: body['name']?.toString().trim().isNotEmpty == true ? body['name'].toString() : host,
      storeId: body['store_id']?.toString() ?? '',
      seenAt: DateTime.now(),
    );
    masters[host] = found;
    notifyListeners();
    unawaited(_adoptIfNeeded(found));
  }

  Future<void> _adoptIfNeeded(DiscoveredMaster found) async {
    final repo = TerminalConfigRepository.instance;
    final config = repo.config;
    if (!config.isSlave || config.masterHost.trim().isNotEmpty) return;
    if (config.storeId.isNotEmpty && found.storeId.isNotEmpty && found.storeId != config.storeId) return;
    await repo.save(config.copyWith(masterHost: found.host));
  }
}
