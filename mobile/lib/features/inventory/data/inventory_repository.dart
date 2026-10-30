import 'dart:async';

import '../../../core/config/terminal_config_repository.dart';
import '../../../data/local/audit_log_store.dart';
import '../../../data/local/local_database.dart';
import '../../../sync/offline_store.dart';
import '../../../sync/sync_engine.dart';
import '../../pos/domain/pos_models.dart';
import '../domain/inventory_movement_type.dart';
import '../domain/unit_converter.dart';
import 'inventory_ledger.dart';

/// Terminal-bound access to [InventoryLedger] for the inventory screens.
class InventoryRepository {
  InventoryRepository._();

  static final InventoryRepository instance = InventoryRepository._();

  Future<InventoryLedger> _ledger() async {
    final config = TerminalConfigRepository.instance.config;
    final saleWarehouse = (await OfflineStore.instance.checkpoint('sale_warehouse_id'))?.trim();
    return InventoryLedger(
      database: () => LocalDatabase.instance.database,
      storeId: config.storeId,
      saleWarehouseId: saleWarehouse == null || saleWarehouse.isEmpty ? null : saleWarehouse,
      deviceId: config.deviceId.isNotEmpty ? config.deviceId : config.deviceIdentifier,
      userId: config.cashierId,
    );
  }

  /// Stock-tracked products of the local catalog.
  Future<List<PosProduct>> products() async {
    final catalog = await SyncEngine.instance.cachedCatalog();
    final items = (catalog?.products ?? const <PosProduct>[]).where((p) => p.tracksStock).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Future<List<InventoryWarehouse>> warehouses() async {
    final sale = (await OfflineStore.instance.checkpoint('sale_warehouse_id'))?.trim();
    final rows = await OfflineStore.instance.warehouseDocuments();
    final list = rows
        .map((row) => InventoryWarehouse.fromJson(row, saleWarehouseId: sale))
        .where((warehouse) => warehouse.id.isNotEmpty)
        .toList();
    if (sale != null && sale.isNotEmpty && !list.any((warehouse) => warehouse.id == sale)) {
      list.insert(0, InventoryWarehouse(id: sale, name: 'Dépôt de vente', isSale: true));
    }
    return list;
  }

  /// Base unit plus the packagings the product is sold in (bottle → ml…).
  List<InventoryUnit> unitsFor(PosProduct product) {
    final base = InventoryUnit(id: '', label: product.unit?.isNotEmpty == true ? product.unit! : 'Unité', factor: 1);
    final packs = product.saleUnits
        .where((unit) => unit.volumeMl > 1)
        .map((unit) => InventoryUnit(
              id: unit.id,
              label: '${unit.name} (${unit.volumeMl} ml)',
              factor: unit.volumeMl,
            ));
    return [base, ...packs];
  }

  Future<InventoryPosting> record({
    required PosProduct product,
    required InventoryMovementType type,
    required num quantity,
    InventoryUnit? unit,
    String? warehouseId,
    String? reason,
  }) async {
    final ledger = await _ledger();
    final posting = await OfflineStore.instance.exclusiveStock(() => ledger.record(
          productId: product.productId,
          type: type,
          quantity: quantity,
          factor: unit?.factor ?? 1,
          enteredUnitId: unit?.id,
          warehouseId: warehouseId,
          reason: reason,
        ));
    await _after(
      action: 'inventory.${type.wire.toLowerCase()}',
      entityId: posting.id,
      postings: [posting],
      meta: {
        'product_id': product.productId,
        'product_name': product.name,
        'quantity': posting.signedQuantity,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return posting;
  }

  Future<List<InventoryPosting>> transfer({
    required PosProduct product,
    required num quantity,
    required String sourceWarehouseId,
    required String destinationWarehouseId,
    InventoryUnit? unit,
    String? reason,
  }) async {
    final ledger = await _ledger();
    final legs = await OfflineStore.instance.exclusiveStock(() => ledger.transfer(
          productId: product.productId,
          quantity: quantity,
          factor: unit?.factor ?? 1,
          sourceWarehouseId: sourceWarehouseId,
          destinationWarehouseId: destinationWarehouseId,
          reason: reason,
        ));
    await _after(
      action: 'inventory.transfer',
      entityId: legs.first.id.split(':').first,
      postings: legs,
      meta: {
        'product_id': product.productId,
        'product_name': product.name,
        'quantity': legs.first.signedQuantity.abs(),
        'from': sourceWarehouseId,
        'to': destinationWarehouseId,
      },
    );
    return legs;
  }

  Future<StockCountSheet> startCount({
    required StockCountKind kind,
    required List<PosProduct> products,
  }) async {
    final ledger = await _ledger();
    return ledger.startCount(
      kind: kind,
      lines: [
        for (final product in products)
          StockCountLine(
            productId: product.productId,
            name: product.name,
            expectedQty: product.quantityOnHand ?? 0,
          ),
      ],
    );
  }

  /// Products never counted first, then the oldest counted ones.
  Future<List<PosProduct>> cycleCandidates({int size = 20}) async {
    final all = await products();
    final db = await LocalDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT i.product_id AS product_id, MAX(c.updated_at) AS counted_at
      FROM stock_count_items i
      INNER JOIN stock_counts c ON c.id = i.stock_count_id
      WHERE c.status = 'posted' AND i.counted_qty IS NOT NULL
      GROUP BY i.product_id
    ''');
    final lastCounted = {
      for (final row in rows) row['product_id']?.toString() ?? '': row['counted_at']?.toString() ?? '',
    };
    all.sort((a, b) => (lastCounted[a.productId] ?? '').compareTo(lastCounted[b.productId] ?? ''));
    return all.take(size).toList();
  }

  Future<StockCountSheet?> loadCount(String id) async => (await _ledger()).loadCount(id);

  Future<List<StockCountSheet>> counts() async => (await _ledger()).listCounts();

  Future<void> setCounted(String countId, String productId, int? counted) async =>
      (await _ledger()).setCounted(countId: countId, productId: productId, countedQty: counted);

  Future<List<InventoryPosting>> postCount(String countId, {bool applyAdjustments = true}) async {
    final ledger = await _ledger();
    final postings = await OfflineStore.instance.exclusiveStock(
      () => ledger.postCount(countId: countId, applyAdjustments: applyAdjustments),
    );
    await _after(
      action: applyAdjustments ? 'inventory.count_posted' : 'inventory.count_verified',
      entityId: countId,
      postings: postings,
      meta: {'adjusted_lines': postings.length},
    );
    return postings;
  }

  Future<List<InventoryMovementRecord>> history({String? productId, int limit = 100}) async =>
      (await _ledger()).history(productId: productId, limit: limit);

  Future<void> _after({
    required String action,
    required String entityId,
    required List<InventoryPosting> postings,
    Map<String, dynamic> meta = const {},
  }) async {
    final config = TerminalConfigRepository.instance.config;
    await AuditLogStore.instance.record(
      action: action,
      actorId: config.cashierId.isEmpty ? null : config.cashierId,
      entityType: 'stock',
      entityId: entityId,
      meta: meta,
    );
    final applied = postings.where((posting) => !posting.alreadyProcessed).toList();
    if (applied.isEmpty) return;
    SyncEngine.instance.markCatalogChanged(stock: [
      for (final posting in applied)
        {'product_id': posting.productId, 'quantity_on_hand': posting.quantityOnHand},
    ]);
    await SyncEngine.instance.refreshCounts();
    unawaited(SyncEngine.instance.runCycle());
  }
}
