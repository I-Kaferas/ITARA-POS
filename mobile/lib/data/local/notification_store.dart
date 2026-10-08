import 'package:uuid/uuid.dart';

import 'document_dao.dart';

class NotificationStore {
  NotificationStore._();

  static final NotificationStore instance = NotificationStore._();

  Future<String> push({
    required String kind,
    required String title,
    String? body,
    Map<String, dynamic> meta = const {},
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    await DataModelDaos.notifications.upsert({
      'id': id,
      'kind': kind,
      'title': title,
      'body': body,
      'meta': meta,
      'created_at': now,
    }, columns: {
      'id': id,
      'kind': kind,
      'title': title,
      'body': body,
      'created_at': now,
    });
    return id;
  }

  Future<List<Map<String, dynamic>>> unread({int limit = 40}) {
    return DataModelDaos.notifications.list(
      where: 'read_at IS NULL',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<void> markRead(String id) async {
    final existing = await DataModelDaos.notifications.find(id);
    if (existing == null) return;
    final now = DateTime.now().toIso8601String();
    await DataModelDaos.notifications.upsert({
      ...existing,
      'read_at': now,
    }, columns: {
      'id': id,
      'kind': existing['kind']?.toString() ?? 'info',
      'title': existing['title']?.toString() ?? '',
      'body': existing['body']?.toString(),
      'read_at': now,
      'created_at': existing['created_at']?.toString() ?? now,
    });
  }
}
