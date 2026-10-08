import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/config/terminal_config_repository.dart';
import 'discovery/master_beacon.dart';
import 'local_master_server.dart';

export 'discovery/master_beacon.dart'
    show DiscoveredMaster, DiscoveryTransport, MasterBeacon, MasterBeaconCodec;

/// UDP broadcast + active probe + lightweight mDNS for `_itara-pos._tcp`.
class LocalMasterDiscovery extends ChangeNotifier {
  LocalMasterDiscovery._();

  static final LocalMasterDiscovery instance = LocalMasterDiscovery._();
  static const beaconPort = MasterBeacon.udpPort;
  static const mdnsPort = 5353;
  static const serviceType = MasterBeacon.responseType;
  static const probeType = MasterBeacon.probeType;
  static const legacyService = MasterBeacon.legacyService;
  static const mdnsService = '${MasterBeacon.mdnsServiceType}.local';

  RawDatagramSocket? _socket;
  RawDatagramSocket? _mdns;
  Timer? _beacon;
  Timer? _prune;
  bool _started = false;
  bool searching = false;
  final masters = <String, DiscoveredMaster>{};

  String get statusMessage {
    if (searching && visible.isEmpty) {
      return 'Searching for ITARA Master...';
    }
    if (visible.isEmpty) return 'Aucun Master sur le réseau local';
    return 'Masters found';
  }

  List<DiscoveredMaster> get visible {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 12));
    final config = TerminalConfigRepository.instance.config;
    return masters.values
        .where((item) => item.seenAt.isAfter(cutoff))
        .where((item) =>
            config.storeId.isEmpty ||
            item.storeId.isEmpty ||
            item.storeId == config.storeId)
        .where((item) =>
            config.tenantId.isEmpty ||
            item.tenantId.isEmpty ||
            item.tenantId == config.tenantId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        beaconPort,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;
      _socket = socket;
      socket.listen(_onUdpEvent);
    } catch (_) {
      _started = false;
      return;
    }

    try {
      final mdns = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        mdnsPort,
        reuseAddress: true,
        reusePort: true,
      );
      mdns.joinMulticast(InternetAddress('224.0.0.251'));
      mdns.multicastHops = 1;
      _mdns = mdns;
      mdns.listen(_onMdnsEvent);
    } catch (_) {
      // mDNS optional — UDP probe remains primary.
    }

    _beacon = Timer.periodic(const Duration(seconds: 2), (_) {
      _announce();
      _announceMdns();
    });
    _prune = Timer.periodic(const Duration(seconds: 3), (_) => notifyListeners());
    _announce();
    _announceMdns();
  }

  void stop() {
    _started = false;
    searching = false;
    _beacon?.cancel();
    _beacon = null;
    _prune?.cancel();
    _prune = null;
    _socket?.close();
    _socket = null;
    try {
      _mdns?.leaveMulticast(InternetAddress('224.0.0.251'));
    } catch (_) {}
    _mdns?.close();
    _mdns = null;
  }

  /// Active search: "Searching for ITARA Master…"
  Future<List<DiscoveredMaster>> search({
    Duration wait = const Duration(seconds: 3),
  }) async {
    searching = true;
    notifyListeners();
    _sendProbe();
    _sendMdnsQuery();
    await Future<void>.delayed(wait);
    searching = false;
    notifyListeners();
    return visible;
  }

  Future<void> searchNow() async {
    await search();
  }

  void _announce() {
    final socket = _socket;
    final server = LocalMasterServer.instance;
    if (socket == null || !server.listening) return;
    final host = server.lanAddress;
    if (host == null || host.isEmpty) return;
    final payload = MasterBeaconCodec.encode(_masterPayload(host));
    for (final target in _broadcastTargets(host)) {
      try {
        socket.send(payload, InternetAddress(target), beaconPort);
      } catch (_) {}
    }
  }

  /// Payload §7 `ITARA_MASTER_RESPONSE`.
  Map<String, dynamic> _masterPayload(String host) {
    final config = TerminalConfigRepository.instance.config;
    return MasterBeaconCodec.buildResponse(
      masterId: config.deviceId.isNotEmpty
          ? config.deviceId
          : config.deviceIdentifier,
      name: config.deviceName.isEmpty ? 'ITARA POS Master' : config.deviceName,
      ip: host,
      port: LocalMasterServer.port,
      tenantId: config.tenantId,
      branchId: config.storeId,
      version: AppConfig.appVersion,
      deviceId: config.deviceId,
    );
  }

  void _sendProbe() {
    final socket = _socket;
    if (socket == null) return;
    final config = TerminalConfigRepository.instance.config;
    final payload = MasterBeaconCodec.encode(
      MasterBeaconCodec.buildQuery(
        tenantId: config.tenantId,
        storeId: config.storeId,
        deviceId: config.deviceId,
      ),
    );
    for (final target in const ['255.255.255.255']) {
      try {
        socket.send(payload, InternetAddress(target), beaconPort);
      } catch (_) {}
    }
    unawaited(_probeSubnets(payload));
  }

  Future<void> _probeSubnets(List<int> payload) async {
    final socket = _socket;
    if (socket == null) return;
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          final bcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
          try {
            socket.send(payload, InternetAddress(bcast), beaconPort);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Set<String> _broadcastTargets(String host) {
    final targets = <String>{'255.255.255.255'};
    final parts = host.split('.');
    if (parts.length == 4) {
      targets.add('${parts[0]}.${parts[1]}.${parts[2]}.255');
    }
    return targets;
  }

  void _onUdpEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final socket = _socket;
    if (socket == null) return;
    final packet = socket.receive();
    if (packet == null) return;
    final body = MasterBeaconCodec.decode(packet.data);
    if (body == null) return;

    if (MasterBeaconCodec.isQuery(body)) {
      _replyToProbe(packet.address);
      return;
    }

    if (!MasterBeaconCodec.isResponse(body)) return;
    _ingestMaster(body, transport: DiscoveryTransport.udp);
  }

  void _replyToProbe(InternetAddress requester) {
    final server = LocalMasterServer.instance;
    if (!server.listening) return;
    final host = server.lanAddress;
    if (host == null || host.isEmpty) return;
    final socket = _socket;
    if (socket == null) return;
    final payload = MasterBeaconCodec.encode(_masterPayload(host));
    try {
      socket.send(payload, requester, beaconPort);
    } catch (_) {}
  }

  void _ingestMaster(
    Map<String, dynamic> body, {
    required DiscoveryTransport transport,
  }) {
    final found = MasterBeaconCodec.parseResponse(
      body,
      transport: transport,
      selfLanAddress: LocalMasterServer.instance.lanAddress,
    );
    if (found == null) return;
    masters[found.host] = found;
    if (searching) searching = false;
    notifyListeners();
    unawaited(_reconnectIfNeeded(found));
  }

  /// Minimal mDNS announce for `_itara-pos._tcp.local` (TXT carries JSON fields).
  void _announceMdns() {
    final mdns = _mdns;
    final server = LocalMasterServer.instance;
    if (mdns == null || !server.listening) return;
    final host = server.lanAddress;
    if (host == null || host.isEmpty) return;
    final config = TerminalConfigRepository.instance.config;
    final instanceName = (config.deviceName.isEmpty ? 'ITARA-POS-MASTER' : config.deviceName)
        .replaceAll(RegExp(r'[^A-Za-z0-9-]'), '-');
    final packet = _buildMdnsAnnouncement(
      instance: '$instanceName.local',
      host: host,
      port: LocalMasterServer.port,
      txt: {
        'type': serviceType,
        'master_id': config.deviceId.isNotEmpty ? config.deviceId : config.deviceIdentifier,
        'name': config.deviceName.isEmpty ? 'ITARA POS Master' : config.deviceName,
        'tenant_id': config.tenantId,
        'branch_id': config.storeId,
        'version': AppConfig.appVersion,
      },
    );
    try {
      mdns.send(packet, InternetAddress('224.0.0.251'), mdnsPort);
    } catch (_) {}
  }

  void _sendMdnsQuery() {
    final mdns = _mdns;
    if (mdns == null) return;
    try {
      mdns.send(_buildMdnsPtrQuery(), InternetAddress('224.0.0.251'), mdnsPort);
    } catch (_) {}
  }

  void _onMdnsEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final mdns = _mdns;
    if (mdns == null) return;
    final packet = mdns.receive();
    if (packet == null) return;
    // If we are Master, answer PTR queries for our service.
    if (LocalMasterServer.instance.listening && _looksLikePtrQuery(packet.data)) {
      _announceMdns();
      return;
    }
    final txt = _extractTxtFromMdns(packet.data);
    if (txt == null) return;
    if (txt['type'] != serviceType && txt['mdns_service'] != mdnsService) {
      if (!(txt.containsKey('master_id') && txt.containsKey('branch_id'))) return;
    }
    final host = (txt['ip'] ?? txt['host'])?.toString() ?? '';
    if (host.isEmpty) {
      _ingestMaster({
        ...txt,
        'type': serviceType,
        'ip': packet.address.address,
        'port': txt['port'] ?? LocalMasterServer.port,
      }, transport: DiscoveryTransport.mdns);
      return;
    }
    _ingestMaster({...txt, 'type': serviceType}, transport: DiscoveryTransport.mdns);
  }

  bool _looksLikePtrQuery(List<int> data) {
    if (data.length < 12) return false;
    // Very loose: contains the service label bytes.
    final hay = String.fromCharCodes(data.where((b) => b >= 32 && b < 127));
    return hay.contains('_itara-pos');
  }

  Map<String, String>? _extractTxtFromMdns(List<int> data) {
    // Best-effort: scan for printable TXT key=value pairs we emit.
    final text = String.fromCharCodes(data.where((b) => b >= 32 && b < 127));
    if (!text.contains('master_id=') && !text.contains('type=ITARA')) return null;
    final map = <String, String>{};
    for (final part in text.split(RegExp(r'[\x00-\x1f]+'))) {
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      final key = part.substring(0, eq).trim();
      final value = part.substring(eq + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      if (key.length > 40) continue;
      map[key] = value;
    }
    if (map.isEmpty) return null;
    map.putIfAbsent('type', () => serviceType);
    return map;
  }

  Uint8List _buildMdnsPtrQuery() {
    final builder = BytesBuilder();
    // Header: one question
    builder.add([0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
    builder.add(_dnsName('_itara-pos._tcp.local'));
    builder.add([0x00, 0x0c, 0x00, 0x01]); // PTR IN
    return builder.toBytes();
  }

  Uint8List _buildMdnsAnnouncement({
    required String instance,
    required String host,
    required int port,
    required Map<String, String> txt,
  }) {
    final builder = BytesBuilder();
    // Header: 0 questions, 3 answers (PTR, SRV, TXT) — response + authoritative
    builder.add([0x00, 0x00, 0x84, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00]);

    // PTR _itara-pos._tcp.local → instance
    builder.add(_dnsName('_itara-pos._tcp.local'));
    builder.add([0x00, 0x0c, 0x00, 0x01, 0x00, 0x00, 0x00, 0x78]); // PTR IN TTL 120
    final ptrData = _dnsName(instance);
    builder.add([(ptrData.length >> 8) & 0xff, ptrData.length & 0xff]);
    builder.add(ptrData);

    // SRV instance → port + host
    builder.add(_dnsName(instance));
    builder.add([0x00, 0x21, 0x00, 0x01, 0x00, 0x00, 0x00, 0x78]); // SRV
    final target = _dnsName('$host.local');
    final srvLen = 6 + target.length;
    builder.add([(srvLen >> 8) & 0xff, srvLen & 0xff]);
    builder.add([0x00, 0x00, 0x00, 0x00, (port >> 8) & 0xff, port & 0xff]);
    builder.add(target);

    // TXT with our metadata (+ ip/port for easy parsing)
    final txtPairs = <String>[
      'type=${txt['type'] ?? serviceType}',
      'master_id=${txt['master_id'] ?? ''}',
      'name=${txt['name'] ?? ''}',
      'ip=$host',
      'port=$port',
      'tenant_id=${txt['tenant_id'] ?? ''}',
      'branch_id=${txt['branch_id'] ?? ''}',
      'version=${txt['version'] ?? ''}',
    ];
    builder.add(_dnsName(instance));
    builder.add([0x00, 0x10, 0x00, 0x01, 0x00, 0x00, 0x00, 0x78]); // TXT
    final txtBytes = BytesBuilder();
    for (final pair in txtPairs) {
      final encoded = utf8.encode(pair);
      if (encoded.length > 255) continue;
      txtBytes.addByte(encoded.length);
      txtBytes.add(encoded);
    }
    final rawTxt = txtBytes.toBytes();
    builder.add([(rawTxt.length >> 8) & 0xff, rawTxt.length & 0xff]);
    builder.add(rawTxt);

    return builder.toBytes();
  }

  List<int> _dnsName(String name) {
    final out = <int>[];
    for (final label in name.split('.')) {
      if (label.isEmpty) continue;
      final bytes = utf8.encode(label);
      out.add(bytes.length);
      out.addAll(bytes);
    }
    out.add(0);
    return out;
  }

  /// Auto-reconnect when already paired and master IP changed.
  Future<void> _reconnectIfNeeded(DiscoveredMaster found) async {
    final repo = TerminalConfigRepository.instance;
    final config = repo.config;
    if (!config.isSlave) return;
    if (config.masterPairToken.trim().isEmpty) return;

    final knownMasterId = config.masterDeviceId.trim();
    if (knownMasterId.isNotEmpty &&
        found.masterId.isNotEmpty &&
        knownMasterId != found.masterId) {
      return;
    }
    if (config.storeId.isNotEmpty &&
        found.storeId.isNotEmpty &&
        found.storeId != config.storeId) {
      return;
    }

    final currentHost = config.masterHost.trim();
    final nextHost = '${found.host}:${found.port}';
    final currentIp = currentHost.split(':').first;
    if (currentIp == found.host) return;

    await repo.save(config.copyWith(
      masterHost: nextHost,
      masterDeviceId:
          found.masterId.isEmpty ? config.masterDeviceId : found.masterId,
    ));
  }
}
