import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Local balance of one product in one sale warehouse.
///
/// The row id is deterministic so a replay of the same delta replaces the row
/// instead of inserting a second balance.
class SaleStock {
  static String rowId({
    required String productId,
    required String storeId,
    String? warehouseId,
    String? variantId,
  }) {
    final store = storeId.trim().isEmpty ? '_' : storeId.trim();
    final warehouse = _token(warehouseId);
    final variant = _token(variantId);
    return '$productId:$store:$warehouse:$variant';
  }

  static String balanceKey({
    required String productId,
    String? warehouseId,
    String? variantId,
  }) =>
      '$productId|${_token(warehouseId)}|${_token(variantId)}';

  static String _token(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '_' : text;
  }

  static String? _stored(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// Applies a signed delta (negative = sale). When the row is missing and
  /// [seed] is null, the balance starts at 0. [createIfMissing] false leaves
  /// an absent row untouched and returns null.
  static Future<int?> applyDelta({
    required DatabaseExecutor txn,
    required String productId,
    required String storeId,
    String? warehouseId,
    String? variantId,
    required int delta,
    int? seed,
    bool createIfMissing = true,
  }) async {
    if (productId.isEmpty || delta == 0 && seed == null) return null;
    final id = rowId(
      productId: productId,
      storeId: storeId,
      warehouseId: warehouseId,
      variantId: variantId,
    );
    var rows = await txn.query('stocks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) {
      // Legacy rows used a shorter id. Match the balance key so a new sale
      // updates that row instead of violating the unique index.
      rows = await txn.query(
        'stocks',
        where: "product_id = ? AND IFNULL(store_id, '') = ? AND IFNULL(warehouse_id, '') = ? AND IFNULL(variant_id, '') = ?",
        whereArgs: [
          productId,
          storeId.trim(),
          _stored(warehouseId) ?? '',
          _stored(variantId) ?? '',
        ],
        limit: 1,
      );
    }
    if (rows.isEmpty && !createIfMissing && seed == null) return null;
    final storedId = rows.isEmpty ? id : rows.first['id'].toString();
    final current = rows.isEmpty ? (seed ?? 0) : _asInt(rows.first['quantity']);
    final next = delta == 0 && seed != null ? seed : current + delta;
    final reserved = rows.isEmpty ? 0 : _asInt(rows.first['reserved']);
    await txn.insert(
      'stocks',
      {
        'id': storedId,
        'product_id': productId,
        'store_id': storeId.trim().isEmpty ? null : storeId.trim(),
        'warehouse_id': _stored(warehouseId),
        'variant_id': _stored(variantId),
        'quantity': next,
        'reserved': reserved,
        'json': jsonEncode({
          'product_id': productId,
          'store_id': storeId,
          'warehouse_id': _stored(warehouseId),
          'variant_id': _stored(variantId),
          'quantity': next,
        }),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return next;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
