import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../sync/outbox/sync_outbox.dart';
import '../../../sync/sale_stock.dart';
import '../domain/inventory_exception.dart';
import '../domain/inventory_movement_type.dart';
import '../domain/inventory_posting.dart';
import '../domain/stock_count.dart';
import '../domain/unit_converter.dart';

export '../domain/inventory_posting.dart';
export '../domain/stock_count.dart';

/// Local stock ledger: stock in/out, waste, transfers and counts (§29).
///
/// Every movement is a signed delta in base units, keyed by a stable id so a
/// replay never applies twice, and queued in `sync_outbox` as entity `stock`.
class InventoryLedger {
  InventoryLedger({
    required Future<Database> Function() database,
    required this.storeId,
    this.saleWarehouseId,
    this.deviceId = '',
    this.userId = '',
  }) : _database = database;

  /// Movements on another depot than the sale one do not change what the POS
  /// can sell; they are excluded from pending on-hand deltas.
  static const otherWarehouseStatus = 'other_warehouse';

  final Future<Database> Function() _database;
  final String storeId;
  final String? saleWarehouseId;
  final String deviceId;
  final String userId;

  Future<InventoryPosting> record({
    String? id,
    required String productId,
    required InventoryMovementType type,
    required num quantity,
    num factor = 1,
    String? warehouseId,
    String? enteredUnitId,
    String? documentId,
    String? reason,
  }) async {
    final base = UnitConverter.toBase(quantity: quantity, factor: factor);
    final movementId = _id(id);
    final db = await _database();
    return db.transaction((txn) => _post(
          txn,
          movementId: movementId,
          productId: productId,
          type: type,
          baseQuantity: base,
          warehouseId: _warehouse(warehouseId),
          documentId: documentId,
          reason: reason,
          extra: {
            'entered_quantity': quantity,
            'factor': factor,
            if (enteredUnitId != null && enteredUnitId.isNotEmpty) 'entered_unit_id': enteredUnitId,
          },
        ));
  }

  /// Two legs under one document id; replaying the document is a no-op.
  Future<List<InventoryPosting>> transfer({
    required String productId,
    required num quantity,
    required String sourceWarehouseId,
    required String destinationWarehouseId,
    num factor = 1,
    String? documentId,
    String? reason,
  }) async {
    final source = sourceWarehouseId.trim();
    final destination = destinationWarehouseId.trim();
    if (source.isEmpty || destination.isEmpty) {
      throw const InventoryException('Choisissez le dépôt source et le dépôt de destination');
    }
    if (source == destination) {
      throw const InventoryException('Le dépôt de destination doit être différent de la source');
    }
    final base = UnitConverter.toBase(quantity: quantity, factor: factor);
    final document = _id(documentId);
    final db = await _database();
    return db.transaction((txn) async {
      final out = await _post(
        txn,
        movementId: '$document:out',
        productId: productId,
        type: InventoryMovementType.transferOut,
        baseQuantity: base,
        warehouseId: source,
        documentId: document,
        reason: reason,
        extra: {'transfer_id': document, 'counterpart_warehouse_id': destination},
      );
      final inbound = await _post(
        txn,
        movementId: '$document:in',
        productId: productId,
        type: InventoryMovementType.transferIn,
        baseQuantity: base,
        warehouseId: destination,
        documentId: document,
        reason: reason,
        extra: {'transfer_id': document, 'counterpart_warehouse_id': source},
      );
      return [out, inbound];
    });
  }

  Future<StockCountSheet> startCount({
    String? id,
    required StockCountKind kind,
    required List<StockCountLine> lines,
    String? warehouseId,
  }) async {
    if (lines.isEmpty) throw const InventoryException('Aucun article à compter');
    final countId = _id(id);
    final db = await _database();
    final existing = await loadCount(countId, executor: db);
    if (existing != null) return existing;
    final now = DateTime.now().toIso8601String();
    final warehouse = _warehouse(warehouseId);
    await db.transaction((txn) async {
      await txn.insert('stock_counts', {
        'id': countId,
        'store_id': storeId,
        'warehouse_id': warehouse,
        'status': StockCountStatusWire.draft,
        'json': jsonEncode({
          'kind': kind.wire,
          if (userId.isNotEmpty) 'user_id': userId,
          if (deviceId.isNotEmpty) 'device_id': deviceId,
        }),
        'created_at': now,
        'updated_at': now,
      });
      for (final line in lines) {
        await txn.insert('stock_count_items', {
          'id': '$countId:${line.productId}',
          'stock_count_id': countId,
          'product_id': line.productId,
          'expected_qty': line.expectedQty,
          'counted_qty': line.countedQty,
          'json': jsonEncode({'name': line.name}),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    return (await loadCount(countId, executor: db))!;
  }

  Future<void> setCounted({
    required String countId,
    required String productId,
    int? countedQty,
  }) async {
    if (countedQty != null && countedQty < 0) {
      throw const InventoryException('La quantité comptée ne peut pas être négative');
    }
    final db = await _database();
    final count = await loadCount(countId, executor: db);
    if (count == null) throw const InventoryException('Inventaire introuvable');
    if (count.isPosted) throw const InventoryException('Cet inventaire est déjà validé');
    await db.update(
      'stock_count_items',
      {'counted_qty': countedQty},
      where: 'stock_count_id = ? AND product_id = ?',
      whereArgs: [countId, productId],
    );
    await db.update(
      'stock_counts',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [countId],
    );
  }

  /// Writes counted − expected for every counted line. With
  /// [applyAdjustments] false the gaps are only recorded (verification).
  Future<List<InventoryPosting>> postCount({
    required String countId,
    bool applyAdjustments = true,
  }) async {
    final db = await _database();
    return db.transaction((txn) async {
      final count = await loadCount(countId, executor: txn);
      if (count == null) throw const InventoryException('Inventaire introuvable');
      if (count.isPosted) return const <InventoryPosting>[];
      final gaps = count.lines.where((line) => (line.variance ?? 0) != 0).toList();
      final now = DateTime.now().toIso8601String();
      if (!applyAdjustments) {
        await txn.update(
          'stock_counts',
          {
            'status': gaps.isEmpty ? StockCountStatusWire.verified : StockCountStatusWire.variance,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [countId],
        );
        return const <InventoryPosting>[];
      }
      final postings = <InventoryPosting>[];
      for (final line in gaps) {
        final gap = line.variance!;
        postings.add(await _post(
          txn,
          movementId: '$countId:${line.productId}',
          productId: line.productId,
          type: gap > 0 ? InventoryMovementType.adjustmentIn : InventoryMovementType.adjustmentOut,
          baseQuantity: gap.abs(),
          warehouseId: count.warehouseId,
          documentId: countId,
          reason: 'count:${count.kind.wire}',
          // The shelf was counted: the gap is posted even if sales since then
          // would push the balance below zero.
          allowNegative: true,
          extra: {
            'stock_count_id': countId,
            'expected_qty': line.expectedQty,
            'counted_qty': line.countedQty,
          },
        ));
      }
      await txn.update(
        'stock_counts',
        {'status': StockCountStatusWire.posted, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [countId],
      );
      return postings;
    });
  }

  Future<StockCountSheet?> loadCount(String countId, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _database();
    final rows = await db.query('stock_counts', where: 'id = ?', whereArgs: [countId], limit: 1);
    if (rows.isEmpty) return null;
    final items = await db.query(
      'stock_count_items',
      where: 'stock_count_id = ?',
      whereArgs: [countId],
      orderBy: 'rowid ASC',
    );
    return _sheet(rows.first, items);
  }

  Future<List<StockCountSheet>> listCounts({int limit = 30}) async {
    final db = await _database();
    final rows = await db.query('stock_counts', orderBy: 'created_at DESC', limit: limit);
    final sheets = <StockCountSheet>[];
    for (final row in rows) {
      final items = await db.query(
        'stock_count_items',
        where: 'stock_count_id = ?',
        whereArgs: [row['id']],
      );
      sheets.add(_sheet(row, items));
    }
    return sheets;
  }

  /// Non-sale movements, newest first.
  Future<List<InventoryMovementRecord>> history({String? productId, int limit = 100}) async {
    final db = await _database();
    final rows = await db.rawQuery(
      '''
      SELECT m.*, p.name AS product_name,
        (SELECT o.status FROM sync_outbox o
          WHERE o.entity = 'stock' AND o.entity_id = m.id LIMIT 1) AS outbox_status
      FROM stock_movements m
      LEFT JOIN products p ON p.product_id = m.product_id
      WHERE UPPER(m.type) != 'SALE'
        ${productId == null ? '' : 'AND m.product_id = ?'}
      ORDER BY m.created_at DESC
      LIMIT ?
      ''',
      [?productId, limit],
    );
    return rows
        .map((row) => InventoryMovementRecord(
              id: row['id']?.toString() ?? '',
              productId: row['product_id']?.toString() ?? '',
              productName: row['product_name']?.toString() ?? row['product_id']?.toString() ?? '',
              type: row['type']?.toString() ?? '',
              quantity: _asInt(row['quantity']),
              createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
              warehouseId: row['warehouse_id']?.toString(),
              syncStatus: row['outbox_status']?.toString(),
            ))
        .toList();
  }

  Future<InventoryPosting> _post(
    Transaction txn, {
    required String movementId,
    required String productId,
    required InventoryMovementType type,
    required int baseQuantity,
    String? warehouseId,
    String? documentId,
    String? reason,
    bool allowNegative = false,
    Map<String, dynamic> extra = const {},
  }) async {
    final product = await _productRow(txn, productId);
    if (product == null) throw const InventoryException('Article introuvable dans le catalogue local');
    final storedId = product['product_id'].toString();
    final json = Map<String, dynamic>.from(jsonDecode(product['json'] as String) as Map);
    final onHand = _asInt(json['quantity_on_hand']);

    final existing = await txn.query('stock_movements', where: 'id = ?', whereArgs: [movementId], limit: 1);
    if (existing.isNotEmpty) {
      return InventoryPosting(
        id: movementId,
        productId: storedId,
        type: InventoryMovementType.tryParse(existing.first['type']?.toString()) ?? type,
        signedQuantity: _asInt(existing.first['quantity']),
        quantityOnHand: onHand,
        warehouseId: existing.first['warehouse_id']?.toString(),
        alreadyProcessed: true,
      );
    }

    final signed = type.sign * baseQuantity;
    final affectsOnHand = _affectsOnHand(warehouseId);
    final name = json['name']?.toString() ?? 'Article';

    int? seed;
    if (warehouseId != null) {
      final anyBalance = await txn.query('stocks', where: 'product_id = ?', whereArgs: [storedId], limit: 1);
      // First depot balance for a product inherits the catalog figure.
      if (anyBalance.isEmpty) seed = onHand;
    }

    if (signed < 0 && !allowNegative) {
      if (warehouseId != null) {
        final balance = await _warehouseBalance(txn, storedId, warehouseId) ?? seed ?? 0;
        if (balance + signed < 0) {
          throw InventoryException('Stock insuffisant pour $name dans ce dépôt ($balance disponible)');
        }
      }
      if (affectsOnHand && onHand + signed < 0) {
        throw InventoryException('Stock insuffisant pour $name ($onHand disponible)');
      }
    }

    await SaleStock.applyDelta(
      txn: txn,
      productId: storedId,
      storeId: storeId,
      warehouseId: warehouseId,
      delta: signed,
      seed: warehouseId == null ? onHand : seed,
    );

    var next = onHand;
    if (affectsOnHand) {
      next = onHand + signed;
      json['quantity_on_hand'] = next;
      json['stock_version'] = _asInt(json['stock_version']) + 1;
      await txn.update(
        'products',
        {'json': jsonEncode(json)},
        where: 'product_id = ?',
        whereArgs: [storedId],
      );
    }

    final now = DateTime.now().toIso8601String();
    await txn.insert('stock_movements', {
      'id': movementId,
      'sale_id': documentId ?? movementId,
      'product_id': storedId,
      'quantity': signed,
      'type': type.wire,
      'created_at': now,
      'warehouse_id': warehouseId,
      'sync_status': affectsOnHand ? 'pending' : otherWarehouseStatus,
    });

    await SyncOutbox.instance.enqueue(
      entity: 'stock',
      entityId: movementId,
      operation: 'create',
      payload: {
        ...extra,
        'idempotency_key': movementId,
        'product_id': storedId,
        'quantity': signed,
        'delta': signed,
        'type': type.wire,
        'affects_on_hand': affectsOnHand,
        'warehouse_id': ?warehouseId,
        'document_id': ?documentId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (storeId.isNotEmpty) 'store_id': storeId,
        if (deviceId.isNotEmpty) 'device_id': deviceId,
        if (deviceId.isNotEmpty) 'pos_id': deviceId,
        if (userId.isNotEmpty) 'user_id': userId,
        'occurred_at': now,
      },
      executor: txn,
    );

    return InventoryPosting(
      id: movementId,
      productId: storedId,
      type: type,
      signedQuantity: signed,
      quantityOnHand: next,
      warehouseId: warehouseId,
    );
  }

  bool _affectsOnHand(String? warehouseId) {
    final sale = saleWarehouseId?.trim() ?? '';
    return warehouseId == null || sale.isEmpty || warehouseId == sale;
  }

  String? _warehouse(String? value) {
    final text = value?.trim() ?? '';
    if (text.isNotEmpty) return text;
    final sale = saleWarehouseId?.trim() ?? '';
    return sale.isEmpty ? null : sale;
  }

  Future<int?> _warehouseBalance(Transaction txn, String productId, String warehouseId) async {
    final rows = await txn.query(
      'stocks',
      where: "product_id = ? AND IFNULL(warehouse_id, '') = ? AND IFNULL(variant_id, '') = ''",
      whereArgs: [productId, warehouseId],
      limit: 1,
    );
    return rows.isEmpty ? null : _asInt(rows.first['quantity']);
  }

  Future<Map<String, Object?>?> _productRow(Transaction txn, String productId) async {
    final rows = await txn.query('products', where: 'product_id = ?', whereArgs: [productId], limit: 1);
    if (rows.isNotEmpty) return rows.first;
    final like = await txn.query('products', where: 'json LIKE ?', whereArgs: ['%"$productId"%']);
    for (final row in like) {
      try {
        final decoded = jsonDecode(row['json'] as String);
        if (decoded is! Map) continue;
        if (decoded['product_id']?.toString() == productId ||
            decoded['store_product_id']?.toString() == productId) {
          return row;
        }
      } catch (_) {}
    }
    return null;
  }

  StockCountSheet _sheet(Map<String, Object?> row, List<Map<String, Object?>> items) {
    Map<String, dynamic> meta = const {};
    try {
      final decoded = jsonDecode(row['json']?.toString() ?? '{}');
      if (decoded is Map) meta = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return StockCountSheet(
      id: row['id'].toString(),
      kind: StockCountKind.parse(meta['kind']?.toString()),
      status: row['status']?.toString() ?? StockCountStatusWire.draft,
      warehouseId: row['warehouse_id']?.toString(),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
      lines: items.map((item) {
        var name = item['product_id']?.toString() ?? '';
        try {
          final decoded = jsonDecode(item['json']?.toString() ?? '{}');
          if (decoded is Map && decoded['name'] != null) name = decoded['name'].toString();
        } catch (_) {}
        final counted = item['counted_qty'];
        return StockCountLine(
          productId: item['product_id']?.toString() ?? '',
          name: name,
          expectedQty: _asInt(item['expected_qty']),
          countedQty: counted == null ? null : _asInt(counted),
        );
      }).toList(),
    );
  }

  static String _id(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? const Uuid().v4() : text;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
