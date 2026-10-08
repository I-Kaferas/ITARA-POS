import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../data/local/local_database.dart';
import '../domain/print_group.dart';
import '../domain/print_job.dart';
import '../domain/print_job_status.dart';

/// Persistent print job queue with retry (mobile.md §37 / §42).
class PrintQueue extends ChangeNotifier {
  PrintQueue({
    Future<Database> Function()? database,
    this.maxAttempts = 5,
    this.baseRetryDelay = const Duration(seconds: 3),
  }) : _database = database ?? (() => LocalDatabase.instance.database);

  final Future<Database> Function() _database;
  final int maxAttempts;
  final Duration baseRetryDelay;

  static final PrintQueue instance = PrintQueue();

  Future<PrintJob> enqueue({
    required PrintGroup group,
    required String documentType,
    required Map<String, dynamic> payload,
    String? printerId,
    String categoryId = '',
    String productId = '',
  }) async {
    final job = PrintJob.create(
      group: group,
      documentType: documentType,
      payload: payload,
      printerId: printerId,
      categoryId: categoryId,
      productId: productId,
    );
    final db = await _database();
    await db.insert('print_jobs', job.toRow());
    notifyListeners();
    return job;
  }

  Future<List<PrintJob>> list({int limit = 50, PrintJobStatus? status}) async {
    final db = await _database();
    final rows = status == null
        ? await db.query('print_jobs', orderBy: 'created_at DESC', limit: limit)
        : await db.query(
            'print_jobs',
            where: 'status = ?',
            whereArgs: [status.name],
            orderBy: 'created_at DESC',
            limit: limit,
          );
    return rows.map(PrintJob.fromRow).toList();
  }

  Future<PrintJob?> findById(String id) async {
    final db = await _database();
    final rows = await db.query('print_jobs', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return PrintJob.fromRow(rows.first);
  }

  /// Jobs ready to run: pending, or retrying whose next_retry_at has passed.
  Future<List<PrintJob>> claimNext({int limit = 5}) async {
    final db = await _database();
    final now = DateTime.now().toIso8601String();
    final rows = await db.rawQuery(
      '''
      SELECT * FROM print_jobs
      WHERE status = ?
         OR (status = ? AND (next_retry_at IS NULL OR next_retry_at <= ?))
      ORDER BY created_at ASC
      LIMIT ?
      ''',
      [
        PrintJobStatus.pending.name,
        PrintJobStatus.retrying.name,
        now,
        limit,
      ],
    );
    return rows.map(PrintJob.fromRow).toList();
  }

  Future<PrintJob> markPrinting(PrintJob job, {required String printerId}) async {
    return _update(
      job.copyWith(
        status: PrintJobStatus.printing,
        printerId: printerId,
        error: '',
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<PrintJob> markPrinted(PrintJob job, {required String printerId}) async {
    return _update(
      job.copyWith(
        status: PrintJobStatus.printed,
        printerId: printerId,
        error: '',
        updatedAt: DateTime.now(),
        clearNextRetryAt: true,
      ),
    );
  }

  Future<PrintJob> markFailedOrRetry(PrintJob job, Object error) async {
    final attempts = job.attempts + 1;
    final message = error.toString();
    if (attempts < (job.maxAttempts > 0 ? job.maxAttempts : maxAttempts)) {
      final delay = baseRetryDelay * attempts;
      return _update(
        job.copyWith(
          status: PrintJobStatus.retrying,
          attempts: attempts,
          error: message,
          updatedAt: DateTime.now(),
          nextRetryAt: DateTime.now().add(delay),
        ),
      );
    }
    return _update(
      job.copyWith(
        status: PrintJobStatus.failed,
        attempts: attempts,
        error: message,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<PrintJob> cancel(String id) async {
    final job = await findById(id);
    if (job == null) throw StateError('Job introuvable: $id');
    if (job.status.isTerminal) return job;
    return _update(
      job.copyWith(
        status: PrintJobStatus.cancelled,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<PrintJob> requeue(String id) async {
    final job = await findById(id);
    if (job == null) throw StateError('Job introuvable: $id');
    return _update(
      job.copyWith(
        status: PrintJobStatus.pending,
        error: '',
        attempts: 0,
        updatedAt: DateTime.now(),
        clearNextRetryAt: true,
      ),
    );
  }

  Future<PrintJob> _update(PrintJob job) async {
    final db = await _database();
    await db.update(
      'print_jobs',
      job.toRow(),
      where: 'id = ?',
      whereArgs: [job.id],
    );
    notifyListeners();
    return job;
  }
}
