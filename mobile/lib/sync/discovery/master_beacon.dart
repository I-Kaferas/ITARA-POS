import 'dart:convert';
import 'dart:typed_data';

import '../local_master_server.dart';
import '../sync_numbers.dart';

/// Constantes Master Discovery (mobile.md §6–§7).
abstract final class MasterBeacon {
  static const mdnsServiceType = '_itara-pos._tcp';
  static const mdnsInstanceName = 'ITARA-POS-MASTER';
  static const udpPort = 8002;

  static const responseType = 'ITARA_MASTER_RESPONSE';
  static const queryType = 'ITARA_MASTER_QUERY';
  static const probeType = 'ITARA_MASTER_PROBE';
  static const legacyService = 'itara-local-master';
}

enum DiscoveryTransport { mdns, udp }

class DiscoveredMaster {
  const DiscoveredMaster({
    required this.host,
    required this.port,
    required this.name,
    required this.storeId,
    required this.seenAt,
    this.masterId = '',
    this.tenantId = '',
    this.version = '',
    this.transport = DiscoveryTransport.udp,
  });

  final String host;
  final int port;
  final String name;
  final String storeId;
  final DateTime seenAt;
  final String masterId;
  final String tenantId;
  final String version;
  final DiscoveryTransport transport;

  /// Alias §7 (`branch_id`).
  String get branchId => storeId;

  String get url => LocalMasterServer.baseUrlForHost('$host:$port');

  /// IP seule (affichage Slave §7).
  String get displayHost => host;

  String get displayEndpoint => '$host:$port';

  /// Compat anciens appels.
  String get source => transport.name;

  bool get isOnline =>
      DateTime.now().difference(seenAt) < const Duration(seconds: 12);

  bool get isFresh => isOnline;

  /// Payload canonique §7.
  Map<String, dynamic> toResponseJson() => {
        'type': MasterBeacon.responseType,
        'master_id': masterId,
        'name': name,
        'ip': host,
        'port': port,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'version': version,
      };
}

/// Encode / decode des beacons (testable sans réseau).
abstract final class MasterBeaconCodec {
  /// Réponse Master §7 (+ champs compat).
  static Map<String, dynamic> buildResponse({
    required String masterId,
    required String name,
    required String ip,
    required int port,
    required String tenantId,
    required String branchId,
    required String version,
    String deviceId = '',
  }) {
    return {
      'type': MasterBeacon.responseType,
      'master_id': masterId,
      'name': name,
      'ip': ip,
      'port': port,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'version': version,
      'service': MasterBeacon.legacyService,
      'host': ip,
      'store_id': branchId,
      'device_id': deviceId.isEmpty ? masterId : deviceId,
    };
  }

  static Map<String, dynamic> buildQuery({
    String? tenantId,
    String? storeId,
    String? deviceId,
  }) {
    return {
      'type': MasterBeacon.queryType,
      if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
      if (storeId != null && storeId.isNotEmpty) 'store_id': storeId,
      if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
    };
  }

  static List<int> encode(Map<String, dynamic> body) =>
      utf8.encode(jsonEncode(body));

  static Map<String, dynamic>? decode(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  static bool isResponse(Map<String, dynamic> body) {
    final type = body['type']?.toString();
    final service = body['service']?.toString();
    return type == MasterBeacon.responseType ||
        service == MasterBeacon.legacyService;
  }

  static bool isQuery(Map<String, dynamic> body) {
    final type = body['type']?.toString();
    return type == MasterBeacon.queryType || type == MasterBeacon.probeType;
  }

  static DiscoveredMaster? parseResponse(
    Map<String, dynamic> body, {
    DiscoveryTransport transport = DiscoveryTransport.udp,
    String? selfLanAddress,
  }) {
    if (!isResponse(body)) return null;

    final host = (body['ip'] ?? body['host'])?.toString().trim() ?? '';
    if (host.isEmpty) return null;
    if (selfLanAddress != null &&
        selfLanAddress.isNotEmpty &&
        host == selfLanAddress) {
      return null;
    }

    return DiscoveredMaster(
      host: host,
      port: syncAsInt(body['port'], LocalMasterServer.port),
      name: body['name']?.toString().trim().isNotEmpty == true
          ? body['name'].toString()
          : host,
      storeId: (body['store_id'] ?? body['branch_id'])?.toString() ?? '',
      masterId: (body['master_id'] ?? body['device_id'])?.toString() ?? '',
      tenantId: body['tenant_id']?.toString() ?? '',
      version: body['version']?.toString() ?? '',
      seenAt: DateTime.now(),
      transport: transport,
    );
  }

  static Map<String, Uint8List?> txtRecords({
    required String masterId,
    required String name,
    required String tenantId,
    required String branchId,
    required String version,
    required String ip,
  }) {
    Uint8List enc(String value) => Uint8List.fromList(utf8.encode(value));
    return {
      'master_id': enc(masterId),
      'name': enc(name),
      'tenant_id': enc(tenantId),
      'branch_id': enc(branchId),
      'store_id': enc(branchId),
      'version': enc(version),
      'ip': enc(ip),
      'type': enc(MasterBeacon.responseType),
    };
  }

  static String? txtString(Map<String, Uint8List?>? txt, String key) {
    final raw = txt?[key];
    if (raw == null || raw.isEmpty) return null;
    return utf8.decode(raw);
  }
}
