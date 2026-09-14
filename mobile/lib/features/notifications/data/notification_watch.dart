import 'dart:convert';

import '../../../core/config/terminal_config_repository.dart';
import '../../../data/local/local_database.dart';
import '../../../sync/offline_store.dart';

class NotificationWatch {
  NotificationWatch._();

  static final NotificationWatch instance = NotificationWatch._();

  Future<List<Map<String, dynamic>>> snapshot() async {
    final db = await LocalDatabase.instance.database;
    final items = <Map<String, dynamic>>[];
    final products = await db.query('products');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lowStock = <Map<String, dynamic>>[];
    final expired = <Map<String, dynamic>>[];
    for (final row in products) {
      final json = jsonDecode(row['json'] as String) as Map<String, dynamic>;
      final name = json['name']?.toString() ?? row['name']?.toString() ?? 'Article';
      final qty = (json['quantity_on_hand'] as num?)?.toInt();
      final rawThreshold = json['low_stock_threshold'];
      final threshold = rawThreshold == null ? 10 : (rawThreshold as num).toInt();
      if (qty != null && threshold > 0 && qty <= threshold) {
        lowStock.add({'kind': 'low_stock', 'title': name, 'detail': 'Stock $qty · seuil $threshold'});
      }
      final expires = DateTime.tryParse(json['expires_at']?.toString() ?? '');
      if (expires != null && expires.isBefore(today)) {
        expired.add({'kind': 'expired', 'title': name, 'detail': json['expires_at'].toString()});
      }
    }
    items.addAll(lowStock.take(12));
    items.addAll(expired.take(12));

    final failed = await db.query(
      'sync_queue',
      where: "status IN ('failed', 'retrying', 'conflict')",
      limit: 12,
    );
    for (final row in failed) {
      items.add({
        'kind': 'sync_failed',
        'title': row['entity_type']?.toString() ?? 'Sync',
        'detail': row['error_message']?.toString() ?? 'Sync échouée',
      });
    }

    final config = TerminalConfigRepository.instance.config;
    if (config.cashSessionId.isNotEmpty) {
      items.add({
        'kind': 'cash_open',
        'title': 'Caisse ouverte',
        'detail': config.cashierName.isEmpty ? 'Session en cours' : config.cashierName,
      });
    }

    final sales = await db.query('sales', where: 'outstanding_amount > 0');
    var credits = 0;
    for (final row in sales) {
      if (credits >= 12) break;
      final payload = jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
      final due = DateTime.tryParse(payload['due_date']?.toString() ?? '');
      if (due == null || !due.isBefore(today)) continue;
      credits++;
      items.add({
        'kind': 'credit_overdue',
        'title': row['reference']?.toString() ?? 'Crédit',
        'detail': payload['due_date'].toString(),
      });
    }

    final holds = await OfflineStore.instance.loadLocalHolds();
    for (final hold in holds.take(12)) {
      items.add({
        'kind': 'order_pending',
        'title': hold['reference']?.toString() ?? hold['client_reference']?.toString() ?? 'Commande',
        'detail': 'En attente',
      });
    }

    final orders = await db.query(
      'hospitality_docs',
      where: "kind = 'order' AND status NOT IN ('paid', 'closed', 'cancelled')",
      limit: 12,
    );
    for (final row in orders) {
      final json = jsonDecode(row['json'] as String) as Map<String, dynamic>;
      items.add({
        'kind': 'order_pending',
        'title': json['table_label']?.toString() ?? 'Commande',
        'detail': 'En attente',
      });
    }

    return items;
  }
}
