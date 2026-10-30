import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/features/inventory/data/inventory_ledger.dart';
import 'package:pos_mobile/features/inventory/domain/inventory_exception.dart';
import 'package:pos_mobile/features/inventory/domain/inventory_movement_type.dart';
import 'package:pos_mobile/features/inventory/domain/unit_converter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late InventoryLedger ledger;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE products (
              product_id TEXT PRIMARY KEY,
              store_id TEXT NOT NULL,
              sku TEXT,
              name TEXT,
              price INTEGER,
              category_id TEXT,
              json TEXT NOT NULL,
              updated_at TEXT
            )
          ''');
          await database.execute('''
            CREATE TABLE stocks (
              id TEXT PRIMARY KEY,
              product_id TEXT NOT NULL,
              store_id TEXT,
              warehouse_id TEXT,
              variant_id TEXT,
              quantity INTEGER NOT NULL DEFAULT 0,
              reserved INTEGER NOT NULL DEFAULT 0,
              json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE stock_movements (
              id TEXT PRIMARY KEY,
              sale_id TEXT NOT NULL,
              product_id TEXT NOT NULL,
              quantity INTEGER NOT NULL,
              type TEXT NOT NULL,
              created_at TEXT NOT NULL,
              warehouse_id TEXT,
              variant_id TEXT,
              sync_status TEXT NOT NULL DEFAULT 'pending'
            )
          ''');
          await database.execute('''
            CREATE TABLE sync_outbox (
              id TEXT PRIMARY KEY,
              entity TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              operation TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at TEXT NOT NULL,
              status TEXT NOT NULL,
              retry_count INTEGER NOT NULL DEFAULT 0,
              last_error TEXT
            )
          ''');
          await database.execute('''
            CREATE TABLE stock_counts (
              id TEXT PRIMARY KEY,
              store_id TEXT,
              warehouse_id TEXT,
              status TEXT NOT NULL DEFAULT 'draft',
              json TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE stock_count_items (
              id TEXT PRIMARY KEY,
              stock_count_id TEXT NOT NULL,
              product_id TEXT NOT NULL,
              expected_qty INTEGER NOT NULL DEFAULT 0,
              counted_qty INTEGER,
              json TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    ledger = InventoryLedger(
      database: () async => db,
      storeId: 'store',
    );
    await _product(db, id: 'milk', onHand: 1000);
  });

  tearDown(() async {
    await db.close();
  });

  test('two bottles of 750 ml become 1500 base units', () {
    expect(UnitConverter.toBase(quantity: 2, factor: 750), 1500);
    expect(() => UnitConverter.toBase(quantity: 0, factor: 1), throwsA(isA<UnitConversionException>()));
  });

  test('stock in converts the unit and a replay does not double the balance', () async {
    final first = await ledger.record(
      id: 'move-1',
      productId: 'milk',
      type: InventoryMovementType.purchase,
      quantity: 2,
      factor: 750,
      warehouseId: 'depot-a',
      enteredUnitId: 'bottle',
    );
    expect(first.signedQuantity, 1500);
    expect(first.quantityOnHand, 2500);
    expect(first.alreadyProcessed, isFalse);

    final replay = await ledger.record(
      id: 'move-1',
      productId: 'milk',
      type: InventoryMovementType.purchase,
      quantity: 2,
      factor: 750,
      warehouseId: 'depot-a',
    );
    expect(replay.alreadyProcessed, isTrue);
    expect(await _onHand(db), 2500);

    final depot = await db.query('stocks', where: 'warehouse_id = ?', whereArgs: ['depot-a']);
    expect(depot.single['quantity'], 2500);
    final queued = await db.query('sync_outbox', where: 'entity_id = ?', whereArgs: ['move-1']);
    final payload = jsonDecode(queued.single['payload'] as String) as Map<String, dynamic>;
    expect(payload['delta'], 1500);
    expect(payload['entered_quantity'], 2);
    expect(payload['factor'], 750);
  });

  test('stock out and waste refuse a quantity above the balance', () async {
    await expectLater(
      () => ledger.record(
        productId: 'milk',
        type: InventoryMovementType.loss,
        quantity: 1001,
      ),
      throwsA(isA<InventoryException>()),
    );
    await ledger.record(
      productId: 'milk',
      type: InventoryMovementType.damage,
      quantity: 100,
    );
    expect(await _onHand(db), 900);
  });

  test('a transfer keeps the catalog total and moves the warehouse balance', () async {
    await ledger.record(
      productId: 'milk',
      type: InventoryMovementType.purchase,
      quantity: 10,
      warehouseId: 'depot-a',
    );
    final legs = await ledger.transfer(
      productId: 'milk',
      quantity: 4,
      sourceWarehouseId: 'depot-a',
      destinationWarehouseId: 'depot-b',
      documentId: 'xfer-1',
    );
    expect(legs.map((leg) => leg.type), [
      InventoryMovementType.transferOut,
      InventoryMovementType.transferIn,
    ]);
    expect(await _onHand(db), 1010);
    final source = await db.query('stocks', where: 'warehouse_id = ?', whereArgs: ['depot-a']);
    final dest = await db.query('stocks', where: 'warehouse_id = ?', whereArgs: ['depot-b']);
    expect(source.single['quantity'], 1006);
    expect(dest.single['quantity'], 4);

    await ledger.transfer(
      productId: 'milk',
      quantity: 4,
      sourceWarehouseId: 'depot-a',
      destinationWarehouseId: 'depot-b',
      documentId: 'xfer-1',
    );
    final destAgain = await db.query('stocks', where: 'warehouse_id = ?', whereArgs: ['depot-b']);
    expect(destAgain.single['quantity'], 4);
    expect(await _onHand(db), 1010);
  });

  test('a full count posts the variance as an adjustment', () async {
    final sheet = await ledger.startCount(
      id: 'count-1',
      kind: StockCountKind.full,
      lines: const [
        StockCountLine(productId: 'milk', name: 'Lait', expectedQty: 1000, countedQty: 970),
      ],
    );
    final posted = await ledger.postCount(countId: sheet.id);
    expect(posted.single.signedQuantity, -30);
    expect(posted.single.type, InventoryMovementType.adjustmentOut);
    expect(await _onHand(db), 970);
    final again = await ledger.postCount(countId: sheet.id);
    expect(again, isEmpty);
    expect(await _onHand(db), 970);
  });

  test('verification records the gap without changing stock until it is applied', () async {
    final sheet = await ledger.startCount(
      id: 'verify-1',
      kind: StockCountKind.verification,
      lines: const [
        StockCountLine(productId: 'milk', name: 'Lait', expectedQty: 1000, countedQty: 990),
      ],
    );
    final checked = await ledger.postCount(countId: sheet.id, applyAdjustments: false);
    expect(checked, isEmpty);
    expect(await _onHand(db), 1000);
    final row = await db.query('stock_counts', where: 'id = ?', whereArgs: ['verify-1']);
    expect(row.single['status'], 'variance');

    await ledger.postCount(countId: sheet.id, applyAdjustments: true);
    expect(await _onHand(db), 990);
  });

  test('a cycle count adjusts only the lines that were counted', () async {
    await _product(db, id: 'bread', onHand: 20);
    final sheet = await ledger.startCount(
      id: 'cycle-1',
      kind: StockCountKind.cycle,
      lines: const [
        StockCountLine(productId: 'milk', name: 'Lait', expectedQty: 1000, countedQty: 1000),
        StockCountLine(productId: 'bread', name: 'Pain', expectedQty: 20, countedQty: 18),
      ],
    );
    await ledger.postCount(countId: sheet.id);
    expect(await _onHand(db), 1000);
    expect(await _onHand(db, 'bread'), 18);
  });
}

Future<void> _product(Database db, {required String id, required int onHand}) {
  return db.insert('products', {
    'product_id': id,
    'store_id': 'store',
    'name': id,
    'json': jsonEncode({'product_id': id, 'name': id, 'quantity_on_hand': onHand, 'stock_version': 1}),
  });
}

Future<int> _onHand(Database db, [String id = 'milk']) async {
  final rows = await db.query('products', where: 'product_id = ?', whereArgs: [id]);
  final json = jsonDecode(rows.single['json'] as String) as Map<String, dynamic>;
  return json['quantity_on_hand'] as int;
}
