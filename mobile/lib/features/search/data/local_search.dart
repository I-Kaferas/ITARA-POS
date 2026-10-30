import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../domain/search_hit.dart';

/// Local lookup across the SQLite cache. Nothing is sent to the network.
class LocalSearch {
  static Future<List<SearchHit>> query(DatabaseExecutor db, String raw) async {
    final text = raw.trim();
    if (text.length < 2) return const [];
    final like = '%${text.replaceAll('%', '').replaceAll('_', '')}%';
    final hits = <SearchHit>[];

    final products = await db.query(
      'products',
      where: 'name LIKE ? OR sku LIKE ? OR json LIKE ?',
      whereArgs: [like, like, like],
      limit: 8,
    );
    for (final row in products) {
      hits.add(SearchHit(
        kind: SearchKind.product,
        id: row['product_id']?.toString() ?? '',
        title: row['name']?.toString() ?? '',
        subtitle: row['sku']?.toString() ?? '',
      ));
    }

    final sales = await db.query(
      'sales',
      where: 'reference LIKE ? OR id LIKE ?',
      whereArgs: [like, like],
      orderBy: 'created_at DESC',
      limit: 8,
    );
    for (final row in sales) {
      hits.add(SearchHit(
        kind: SearchKind.sale,
        id: row['id']?.toString() ?? '',
        title: row['reference']?.toString() ?? '',
        subtitle: row['method']?.toString() ?? '',
      ));
    }

    final customers = await db.query(
      'customers',
      where: 'name LIKE ? OR phone LIKE ? OR code LIKE ? OR email LIKE ?',
      whereArgs: [like, like, like, like],
      limit: 8,
    );
    for (final row in customers) {
      hits.add(SearchHit(
        kind: SearchKind.customer,
        id: row['id']?.toString() ?? '',
        title: row['name']?.toString() ?? '',
        subtitle: row['phone']?.toString() ?? row['email']?.toString() ?? '',
      ));
    }

    final orders = await db.query(
      'restaurant_orders',
      where: 'id LIKE ? OR status LIKE ? OR json LIKE ?',
      whereArgs: [like, like, like],
      limit: 8,
    );
    for (final row in orders) {
      hits.add(SearchHit(
        kind: SearchKind.order,
        id: row['id']?.toString() ?? '',
        title: row['id']?.toString() ?? '',
        subtitle: row['status']?.toString() ?? '',
      ));
    }

    final tables = await db.query(
      'restaurant_tables',
      where: 'name LIKE ? OR id LIKE ?',
      whereArgs: [like, like],
      limit: 8,
    );
    for (final row in tables) {
      hits.add(SearchHit(
        kind: SearchKind.table,
        id: row['id']?.toString() ?? '',
        title: row['name']?.toString() ?? '',
        subtitle: row['status']?.toString() ?? '',
      ));
    }

    final suppliers = await db.query(
      'suppliers',
      where: 'name LIKE ? OR phone LIKE ? OR code LIKE ?',
      whereArgs: [like, like, like],
      limit: 8,
    );
    for (final row in suppliers) {
      hits.add(SearchHit(
        kind: SearchKind.supplier,
        id: row['id']?.toString() ?? '',
        title: row['name']?.toString() ?? '',
        subtitle: row['phone']?.toString() ?? '',
      ));
    }

    return hits.where((hit) => hit.id.isNotEmpty && hit.title.isNotEmpty).toList();
  }
}
