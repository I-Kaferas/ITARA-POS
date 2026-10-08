import 'dart:async';
import 'dart:convert';

/// Étapes du secure pairing (mobile.md §8).
enum PairingPhase {
  discovery,
  handshake,
  authentication,
  pairing,
  authorization,
  registered,
  rejected,
}

extension PairingPhaseX on PairingPhase {
  String get label => switch (this) {
        PairingPhase.discovery => 'Discovery',
        PairingPhase.handshake => 'Handshake',
        PairingPhase.authentication => 'Authentication',
        PairingPhase.pairing => 'Pairing',
        PairingPhase.authorization => 'Authorization',
        PairingPhase.registered => 'Registered',
        PairingPhase.rejected => 'Rejected',
      };
}

/// Demande d’appairage en attente d’approbation Master.
class PairingRequest {
  PairingRequest({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.os,
    required this.ip,
    required this.role,
    required this.version,
    required this.code,
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        phase = PairingPhase.authorization,
        completer = Completer<PairingDecision>();

  final String id;
  final String deviceId;
  final String deviceName;
  final String deviceType;
  final String os;
  final String ip;
  final String role;
  final String version;
  final String code;
  final DateTime createdAt;
  PairingPhase phase;
  final Completer<PairingDecision> completer;

  String get wantsToConnectLabel =>
      '${deviceName.isEmpty ? deviceId : deviceName} wants to connect.';

  bool get isExpired =>
      DateTime.now().difference(createdAt) > const Duration(minutes: 2);
}

class PairingDecision {
  const PairingDecision.accepted({
    required this.pairToken,
    required this.deviceId,
  })  : accepted = true,
        reason = null;

  const PairingDecision.rejected({this.reason})
      : accepted = false,
        pairToken = null,
        deviceId = null;

  final bool accepted;
  final String? pairToken;
  final String? deviceId;
  final String? reason;
}

/// Payload QR pour appairage Slave ↔ Master.
class PairingQrPayload {
  const PairingQrPayload({
    required this.masterId,
    required this.ip,
    required this.port,
    required this.name,
    this.code = '',
    this.tenantId = '',
    this.branchId = '',
  });

  final String masterId;
  final String ip;
  final int port;
  final String name;
  final String code;
  final String tenantId;
  final String branchId;

  static const type = 'ITARA_PAIR';

  String get hostEndpoint => '$ip:$port';

  Map<String, dynamic> toJson() => {
        'type': type,
        'master_id': masterId,
        'ip': ip,
        'port': port,
        'name': name,
        if (code.isNotEmpty) 'code': code,
        if (tenantId.isNotEmpty) 'tenant_id': tenantId,
        if (branchId.isNotEmpty) 'branch_id': branchId,
      };

  String encode() => jsonEncode(toJson());

  static PairingQrPayload? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final body = Map<String, dynamic>.from(decoded);
      if (body['type']?.toString() != type) return null;
      final ip = body['ip']?.toString().trim() ?? '';
      if (ip.isEmpty) return null;
      final port = int.tryParse(body['port']?.toString() ?? '') ?? 8001;
      return PairingQrPayload(
        masterId: body['master_id']?.toString() ?? '',
        ip: ip,
        port: port,
        name: body['name']?.toString() ?? 'ITARA Master',
        code: body['code']?.toString() ?? '',
        tenantId: body['tenant_id']?.toString() ?? '',
        branchId: body['branch_id']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
