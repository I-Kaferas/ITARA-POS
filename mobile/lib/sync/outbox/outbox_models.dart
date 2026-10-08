/// Outbox locale §30 — `sync_outbox`.
enum OutboxStatus {
  pending('PENDING'),
  syncing('SYNCING'),
  synced('SYNCED'),
  failed('FAILED'),
  conflict('CONFLICT');

  const OutboxStatus(this.wire);

  final String wire;

  static OutboxStatus parse(String? raw) {
    final value = (raw ?? '').trim().toUpperCase();
    return OutboxStatus.values.firstWhere(
      (s) => s.wire == value || s.name.toUpperCase() == value,
      orElse: () {
        // Compat ancienne sync_queue (minuscules).
        return switch ((raw ?? '').toLowerCase()) {
          'processing' || 'syncing' => OutboxStatus.syncing,
          'synced' => OutboxStatus.synced,
          'failed' || 'retrying' => OutboxStatus.failed,
          'conflict' => OutboxStatus.conflict,
          _ => OutboxStatus.pending,
        };
      },
    );
  }
}

class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    required this.status,
    this.retryCount = 0,
    this.lastError,
  });

  final String id;
  final String entity;
  final String entityId;
  final String operation;
  final String payload;
  final DateTime createdAt;
  final OutboxStatus status;
  final int retryCount;
  final String? lastError;

  Map<String, dynamic> toRow() => {
        'id': id,
        'entity': entity,
        'entity_id': entityId,
        'operation': operation,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
        'status': status.wire,
        'retry_count': retryCount,
        'last_error': lastError,
      };

  factory OutboxEntry.fromRow(Map<String, dynamic> row) {
    return OutboxEntry(
      id: row['id']?.toString() ?? '',
      entity: (row['entity'] ?? row['entity_type'])?.toString() ?? '',
      entityId: row['entity_id']?.toString() ?? '',
      operation: row['operation']?.toString() ?? '',
      payload: row['payload']?.toString() ?? '{}',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      status: OutboxStatus.parse(row['status']?.toString()),
      retryCount: int.tryParse(
            (row['retry_count'] ?? row['attempts'])?.toString() ?? '0',
          ) ??
          0,
      lastError: (row['last_error'] ?? row['error_message'])?.toString(),
    );
  }

  /// Map compatible SyncEngine / OfflineStore (anciens noms de colonnes).
  Map<String, dynamic> toCompatMap() => {
        'id': id,
        'entity': entity,
        'entity_type': entity,
        'entity_id': entityId,
        'operation': operation,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
        'status': status.wire,
        'retry_count': retryCount,
        'attempts': retryCount,
        'last_error': lastError,
        'error_message': lastError,
        'priority': 0,
      };
}
