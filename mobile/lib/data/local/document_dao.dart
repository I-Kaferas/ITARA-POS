import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'local_database.dart';

/// Lightweight JSON-document DAO for §14 entity tables.
class DocumentDao {
  DocumentDao(this.table, {this.idColumn = 'id'});

  final String table;
  final String idColumn;

  Future<Database> get _db => LocalDatabase.instance.database;

  Future<List<Map<String, dynamic>>> list({
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await _db;
    final rows = await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
    return rows.map(_rowToDocument).toList();
  }

  Future<Map<String, dynamic>?> find(String id) async {
    final db = await _db;
    final rows = await db.query(
      table,
      where: '$idColumn = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToDocument(rows.first);
  }

  Future<String> upsert(
    Map<String, dynamic> document, {
    Map<String, Object?> columns = const {},
  }) async {
    final id = document[idColumn]?.toString().isNotEmpty == true
        ? document[idColumn].toString()
        : (columns[idColumn]?.toString().isNotEmpty == true
            ? columns[idColumn].toString()
            : const Uuid().v4());
    final payload = {...document, idColumn: id};
    final row = <String, Object?>{
      ...columns,
      idColumn: id,
      'json': jsonEncode(payload),
    };
    // Keep scalar mirrors in sync when present on the document.
    for (final key in columns.keys) {
      if (row[key] != null) continue;
      final value = payload[key];
      if (value != null) row[key] = value is bool ? (value ? 1 : 0) : value;
    }
    final db = await _db;
    await db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete(table, where: '$idColumn = ?', whereArgs: [id]);
  }

  Map<String, dynamic> _rowToDocument(Map<String, Object?> row) {
    Map<String, dynamic> json = {};
    try {
      final decoded = jsonDecode(row['json']?.toString() ?? '{}');
      if (decoded is Map) json = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {
      ...json,
      ...{
        for (final entry in row.entries)
          if (entry.key != 'json') entry.key: entry.value,
      },
      idColumn: row[idColumn] ?? json[idColumn],
    };
  }
}

/// Named DAOs for mobile.md §14 entities.
class DataModelDaos {
  DataModelDaos._();

  static final tenants = DocumentDao('tenants');
  static final organizations = DocumentDao('organizations');
  static final branches = DocumentDao('branches');
  static final terminals = DocumentDao('terminals');
  static final unitConversions = DocumentDao('unit_conversions');
  static final productPrices = DocumentDao('product_prices');
  static final suppliers = DocumentDao('suppliers');
  static final carts = DocumentDao('carts');
  static final cartItems = DocumentDao('cart_items');
  static final saleItems = DocumentDao('sale_items');
  static final refunds = DocumentDao('refunds');
  static final cashRegisters = DocumentDao('cash_registers');
  static final cashMovements = DocumentDao('cash_movements');
  static final shifts = DocumentDao('shifts');
  static final stocks = DocumentDao('stocks');
  static final stockCounts = DocumentDao('stock_counts');
  static final stockCountItems = DocumentDao('stock_count_items');
  static final purchases = DocumentDao('purchases');
  static final purchaseItems = DocumentDao('purchase_items');
  static final expenses = DocumentDao('expenses');
  static final restaurantTables = DocumentDao('restaurant_tables');
  static final restaurantOrders = DocumentDao('restaurant_orders');
  static final restaurantOrderItems = DocumentDao('restaurant_order_items');
  static final kitchenTickets = DocumentDao('kitchen_tickets');
  static final modifiers = DocumentDao('modifiers');
  static final extras = DocumentDao('extras');
  static final printerGroups = DocumentDao('printer_groups');
  static final syncConflicts = DocumentDao('sync_conflicts');
  static final notifications = DocumentDao('notifications');
  static final auditLogs = DocumentDao('audit_logs');
}
