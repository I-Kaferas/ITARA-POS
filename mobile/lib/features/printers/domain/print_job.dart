import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'print_group.dart';
import 'print_job_status.dart';

class PrintJob {
  const PrintJob({
    required this.id,
    required this.group,
    required this.documentType,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.printerId = '',
    this.error = '',
    this.attempts = 0,
    this.maxAttempts = 5,
    this.categoryId = '',
    this.productId = '',
    this.updatedAt,
    this.nextRetryAt,
  });

  final String id;
  final PrintGroup group;
  final String documentType;
  final Map<String, dynamic> payload;
  final PrintJobStatus status;
  final DateTime createdAt;
  final String printerId;
  final String error;
  final int attempts;
  final int maxAttempts;
  final String categoryId;
  final String productId;
  final DateTime? updatedAt;
  final DateTime? nextRetryAt;

  factory PrintJob.create({
    required PrintGroup group,
    required String documentType,
    required Map<String, dynamic> payload,
    String? printerId,
    String categoryId = '',
    String productId = '',
  }) {
    final now = DateTime.now();
    return PrintJob(
      id: const Uuid().v4(),
      group: group,
      documentType: documentType,
      payload: payload,
      status: PrintJobStatus.pending,
      createdAt: now,
      updatedAt: now,
      printerId: printerId ?? '',
      categoryId: categoryId,
      productId: productId,
    );
  }

  factory PrintJob.fromRow(Map<String, Object?> row) {
    Map<String, dynamic> payload = {};
    try {
      final decoded = jsonDecode(row['payload_json'] as String? ?? '{}');
      if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
    } catch (_) {}

    return PrintJob(
      id: row['id'] as String,
      group: PrintGroup.fromString(row['print_group'] as String?),
      documentType: row['document_type'] as String? ?? 'receipt',
      payload: payload,
      status: PrintJobStatus.fromString(row['status'] as String?),
      printerId: row['printer_id'] as String? ?? '',
      error: row['error'] as String? ?? '',
      attempts: (row['attempts'] as int?) ?? 0,
      maxAttempts: (row['max_attempts'] as int?) ?? 5,
      categoryId: row['category_id'] as String? ?? '',
      productId: row['product_id'] as String? ?? '',
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
      nextRetryAt: DateTime.tryParse(row['next_retry_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'group': group.name,
        'document_type': documentType,
        'payload': payload,
        'status': status.name,
        'printer_id': printerId,
        'error': error,
        'attempts': attempts,
        'max_attempts': maxAttempts,
        'category_id': categoryId,
        'product_id': productId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': (updatedAt ?? createdAt).toIso8601String(),
        'next_retry_at': nextRetryAt?.toIso8601String(),
      };

  Map<String, Object?> toRow() => {
        'id': id,
        'print_group': group.name,
        'document_type': documentType,
        'payload_json': jsonEncode(payload),
        'status': status.name,
        'printer_id': printerId,
        'error': error,
        'attempts': attempts,
        'max_attempts': maxAttempts,
        'category_id': categoryId,
        'product_id': productId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': (updatedAt ?? createdAt).toIso8601String(),
        'next_retry_at': nextRetryAt?.toIso8601String(),
      };

  PrintJob copyWith({
    PrintJobStatus? status,
    String? printerId,
    String? error,
    int? attempts,
    DateTime? updatedAt,
    DateTime? nextRetryAt,
    bool clearNextRetryAt = false,
  }) {
    return PrintJob(
      id: id,
      group: group,
      documentType: documentType,
      payload: payload,
      status: status ?? this.status,
      createdAt: createdAt,
      printerId: printerId ?? this.printerId,
      error: error ?? this.error,
      attempts: attempts ?? this.attempts,
      maxAttempts: maxAttempts,
      categoryId: categoryId,
      productId: productId,
      updatedAt: updatedAt ?? this.updatedAt,
      nextRetryAt: clearNextRetryAt ? null : (nextRetryAt ?? this.nextRetryAt),
    );
  }
}
