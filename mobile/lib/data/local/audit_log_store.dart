import 'package:uuid/uuid.dart';

import 'document_dao.dart';

class AuditLogStore {
  AuditLogStore._();

  static final AuditLogStore instance = AuditLogStore._();

  Future<void> record({
    required String action,
    String? actorId,
    String? entityType,
    String? entityId,
    Map<String, dynamic> meta = const {},
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    await DataModelDaos.auditLogs.upsert({
      'id': id,
      'actor_id': actorId,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'meta': meta,
      'created_at': now,
    }, columns: {
      'id': id,
      'actor_id': actorId,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'created_at': now,
    });
  }

  Future<List<Map<String, dynamic>>> recent({int limit = 50}) {
    return DataModelDaos.auditLogs.list(orderBy: 'created_at DESC', limit: limit);
  }
}
