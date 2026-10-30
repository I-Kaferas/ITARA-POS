import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/features/health/domain/pos_health.dart';
import 'package:pos_mobile/features/search/data/local_search.dart';
import 'package:pos_mobile/features/search/domain/search_hit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('health lights follow database, network and the sync queue', () {
    final healthy = PosHealth.resolve(
      databaseOpen: true,
      isMaster: true,
      masterReachable: true,
      internetReachable: true,
      cloudReachable: true,
      printersKnown: 1,
      printersOnline: 1,
      syncFailed: 0,
      syncPending: 0,
    );
    expect(healthy.rows.every((row) => row.level == HealthLevel.ok), isTrue);

    final isolated = PosHealth.resolve(
      databaseOpen: true,
      isMaster: false,
      masterReachable: false,
      internetReachable: false,
      cloudReachable: false,
      printersKnown: 0,
      printersOnline: 0,
      syncFailed: 0,
      syncPending: 3,
    );
    expect(isolated.database, HealthLevel.ok);
    expect(isolated.master, HealthLevel.warn);
    expect(isolated.internet, HealthLevel.warn);
    expect(isolated.cloud, HealthLevel.down);
    expect(isolated.printer, HealthLevel.warn);
    expect(isolated.sync, HealthLevel.warn);

    final broken = PosHealth.resolve(
      databaseOpen: false,
      isMaster: false,
      masterReachable: false,
      internetReachable: true,
      cloudReachable: false,
      printersKnown: 2,
      printersOnline: 0,
      syncFailed: 1,
      syncPending: 0,
    );
    expect(broken.database, HealthLevel.down);
    expect(broken.printer, HealthLevel.down);
    expect(broken.sync, HealthLevel.down);
  });

  test('local search finds products, sales, customers and tables', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute(
            'CREATE TABLE products (product_id TEXT, store_id TEXT, sku TEXT, name TEXT, json TEXT)',
          );
          await database.execute(
            'CREATE TABLE sales (id TEXT, reference TEXT, store_id TEXT, method TEXT, created_at TEXT)',
          );
          await database.execute(
            'CREATE TABLE customers (id TEXT, name TEXT, phone TEXT, code TEXT, email TEXT)',
          );
          await database.execute(
            'CREATE TABLE restaurant_orders (id TEXT, status TEXT, json TEXT)',
          );
          await database.execute(
            'CREATE TABLE restaurant_tables (id TEXT, name TEXT, status TEXT)',
          );
          await database.execute(
            'CREATE TABLE suppliers (id TEXT, name TEXT, phone TEXT, code TEXT)',
          );
        },
      ),
    );
    await db.insert('products', {
      'product_id': 'p1',
      'store_id': 's',
      'sku': 'LAIT',
      'name': 'Lait frais',
      'json': '{}',
    });
    await db.insert('sales', {
      'id': 'sale-1',
      'reference': 'SALE-0009',
      'store_id': 's',
      'method': 'cash',
      'created_at': '2026-10-30',
    });
    await db.insert('customers', {
      'id': 'c1',
      'name': 'Aline Ndayishimiye',
      'phone': '79000000',
      'code': 'C-1',
      'email': '',
    });
    await db.insert('restaurant_tables', {
      'id': 't1',
      'name': 'Table terrasse',
      'status': 'free',
    });
    await db.insert('suppliers', {
      'id': 'sup1',
      'name': 'Laiterie locale',
      'phone': '',
      'code': 'L1',
    });

    expect(await LocalSearch.query(db, 'l'), isEmpty);
    final hits = await LocalSearch.query(db, 'lait');
    expect(hits.map((hit) => hit.kind).toSet(), {SearchKind.product, SearchKind.supplier});
    final sale = await LocalSearch.query(db, 'SALE-0009');
    expect(sale.single.kind, SearchKind.sale);
    final table = await LocalSearch.query(db, 'terrasse');
    expect(table.single.kind, SearchKind.table);
    await db.close();
  });
}
