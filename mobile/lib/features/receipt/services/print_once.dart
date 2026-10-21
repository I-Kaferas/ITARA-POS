import '../../../core/config/terminal_config_repository.dart';
import '../../../data/local/local_database.dart';
import '../../pos/domain/pos_models.dart';

/// Thrown when this document was already sent and the back-office right
/// [pos.print.once] is active.
class PrintAlreadyDone implements Exception {
  const PrintAlreadyDone();
}

/// One physical copy of the receipt and of the kitchen ticket.
///
/// The lock is the back-office right `pos.print.once`. When that right is
/// off, every print is allowed. When it is on, a successful send is remembered
/// on this terminal and a second send of the same document is refused.
class PrintOnce {
  PrintOnce._();

  static const permission = 'pos.print.once';

  static final _done = <String>{};
  static Future<void>? _loading;

  static bool get enabled =>
      TerminalConfigRepository.instance.config.permissions.contains(permission);

  static Future<bool> claim(String key) async {
    if (!enabled) return true;
    await _ensureLoaded();
    final normalized = key.trim();
    if (normalized.isEmpty) return true;
    if (!_done.add(normalized)) return false;
    await _persist([normalized]);
    return true;
  }

  static Future<void> release(String key) => releaseAll([key]);

  /// Claims every alias of one document. If any alias was already sent,
  /// the whole set stays claimed and this returns false.
  static Future<bool> claimAll(Iterable<String> keys) async {
    if (!enabled) return true;
    await _ensureLoaded();
    final normalized = keys.map((key) => key.trim()).where((key) => key.isNotEmpty).toSet();
    if (normalized.isEmpty) return true;
    final known = normalized.any(_done.contains);
    final fresh = <String>[];
    for (final key in normalized) {
      if (_done.add(key)) fresh.add(key);
    }
    if (fresh.isNotEmpty) await _persist(fresh);
    return !known;
  }

  static Future<void> releaseAll(Iterable<String> keys) async {
    final normalized = keys.map((key) => key.trim()).where((key) => key.isNotEmpty).toSet();
    if (normalized.isEmpty) return;
    for (final key in normalized) {
      _done.remove(key);
    }
    if (!enabled) return;
    final db = await LocalDatabase.instance.database;
    final batch = db.batch();
    for (final key in normalized) {
      batch.delete('printed_documents', where: 'doc_key = ?', whereArgs: [key]);
    }
    await batch.commit(noResult: true);
  }

  static List<String> kitchenKeys(PosHeldSale sale, String station) {
    final stationKey = station.trim().toLowerCase();
    final id = sale.id.trim();
    final stableId = id.isEmpty || id == 'hold-print' ? '' : id;
    final serverId = (sale.serverId ?? '').trim();
    final label = sale.label.trim();
    return [
      if (stableId.isNotEmpty) 'kitchen:$stationKey:$stableId',
      if (serverId.isNotEmpty) 'kitchen:$stationKey:$serverId',
      if (label.isNotEmpty) 'kitchen:$stationKey:label:$label',
    ];
  }

  static Future<void> _ensureLoaded() {
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query('printed_documents', columns: ['doc_key']);
    for (final row in rows) {
      final key = row['doc_key']?.toString().trim() ?? '';
      if (key.isNotEmpty) _done.add(key);
    }
  }

  static Future<void> _persist(List<String> keys) async {
    if (keys.isEmpty) return;
    final db = await LocalDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final key in keys) {
      batch.insert('printed_documents', {
        'doc_key': key,
        'printed_at': now,
      });
    }
    await batch.commit(noResult: true);
  }
}
