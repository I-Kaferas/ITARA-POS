import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/sync/sale_stock.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

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
        },
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('a sale decrements only the warehouse of that sale', () async {
    await db.transaction((txn) async {
      await SaleStock.applyDelta(
        txn: txn,
        productId: 'p1',
        storeId: 'store',
        warehouseId: 'depot-a',
        delta: 0,
        seed: 10,
      );
      await SaleStock.applyDelta(
        txn: txn,
        productId: 'p1',
        storeId: 'store',
        warehouseId: 'depot-b',
        delta: 0,
        seed: 7,
      );
      await SaleStock.applyDelta(
        txn: txn,
        productId: 'p1',
        storeId: 'store',
        warehouseId: 'depot-a',
        delta: -3,
      );
    });

    final depotA = await db.query('stocks', where: 'warehouse_id = ?', whereArgs: ['depot-a']);
    final depotB = await db.query('stocks', where: 'warehouse_id = ?', whereArgs: ['depot-b']);
    expect(depotA.single['quantity'], 7);
    expect(depotB.single['quantity'], 7);
    expect(
      SaleStock.rowId(productId: 'p1', storeId: 'store', warehouseId: 'depot-a'),
      'p1:store:depot-a:_',
    );
  });

  test('replaying the same row id replaces the balance instead of doubling it', () async {
    await db.transaction((txn) async {
      await SaleStock.applyDelta(
        txn: txn,
        productId: 'p1',
        storeId: 'store',
        warehouseId: 'depot-a',
        delta: 0,
        seed: 10,
      );
      await SaleStock.applyDelta(
        txn: txn,
        productId: 'p1',
        storeId: 'store',
        warehouseId: 'depot-a',
        delta: -2,
      );
      await SaleStock.applyDelta(
        txn: txn,
        productId: 'p1',
        storeId: 'store',
        warehouseId: 'depot-a',
        delta: 0,
        seed: 8,
      );
    });
    final rows = await db.query('stocks', where: 'product_id = ?', whereArgs: ['p1']);
    expect(rows, hasLength(1));
    expect(rows.single['quantity'], 8);
  });

  test('void adds the sold quantity back on the same warehouse', () async {
    await db.transaction((txn) async {
      await SaleStock.applyDelta(
        txn: txn,
        productId: 'p1',
        storeId: 'store',
        warehouseId: 'depot-a',
        delta: 0,
        seed: 4,
      );
      await SaleStock.applyDelta(
        txn: txn,
        productId: 'p1',
        storeId: 'store',
        warehouseId: 'depot-a',
        delta: 4,
      );
    });
    final rows = await db.query('stocks');
    expect(rows.single['quantity'], 8);
  });
}
