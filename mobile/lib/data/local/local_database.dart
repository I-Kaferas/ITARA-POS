import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;
    _db = await _open();
    return _db!;
  }

  Future<String> sqlitePath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'pos_offline.sqlite');
  }

  Future<void> checkpoint() async {
    final db = await database;
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  Future<void> close() async {
    final existing = _db;
    _db = null;
    if (existing != null && existing.isOpen) {
      await existing.close();
    }
  }

  static Future<void> ensureInitialized() async {
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isAndroid) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> _open() async {
    await ensureInitialized();
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'pos_offline.sqlite');
    return openDatabase(
      path,
      version: 14,
      onCreate: (db, version) async {
        await db.execute('''
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
        await db.execute('''
          CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            store_id TEXT NOT NULL,
            name TEXT,
            parent_id TEXT,
            json TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sales (
            id TEXT PRIMARY KEY,
            reference TEXT NOT NULL,
            store_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            total INTEGER NOT NULL,
            paid_amount INTEGER NOT NULL,
            outstanding_amount INTEGER NOT NULL,
            method TEXT,
            sync_status TEXT NOT NULL,
            server_id TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE stock_movements (
            id TEXT PRIMARY KEY,
            sale_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            type TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_queue (
            id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            operation TEXT NOT NULL,
            payload TEXT NOT NULL,
            priority INTEGER NOT NULL,
            status TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_attempt_at TEXT,
            next_retry_at TEXT,
            error_message TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            level TEXT NOT NULL,
            message TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE checkpoints (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status, priority, created_at)');
        await _createSyncOutbox(db);
        await _createCatalogIndexes(db);
        await _createCustomers(db);
        await _createPaymentMethods(db);
        await _createSaleLedger(db);
        await _createLanes(db);
        await _createHospitality(db);
        await _createReferenceData(db);
        await _createLanDevices(db);
        await _createPrintSpooler(db);
        await _createDataModelV12(db);
        await _createAppLogs(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCustomers(db);
          await _createPaymentMethods(db);
        }
        if (oldVersion < 3) {
          await _createSaleLedger(db);
        }
        if (oldVersion < 4) {
          await _createLanes(db);
        }
        if (oldVersion < 5) {
          await _createHospitality(db);
        }
        if (oldVersion < 6) {
          await _createReferenceData(db);
        }
        if (oldVersion < 7) {
          await _createCatalogIndexes(db);
        }
        if (oldVersion < 8) {
          await _createLanDevices(db);
        }
        if (oldVersion < 9) {
          await _createPrintSpooler(db);
        }
        if (oldVersion < 10) {
          await _upgradeLanDevicesV10(db);
        }
        if (oldVersion < 11) {
          await _upgradePrinterManagementV11(db);
        }
        if (oldVersion < 12) {
          await _createDataModelV12(db);
          await _migrateExpensesFromHospitality(db);
        }
        if (oldVersion < 13) {
          await _createSyncOutbox(db);
          await _migrateSyncQueueToOutbox(db);
        }
        if (oldVersion < 14) {
          await _createAppLogs(db);
        }
      },
    );
  }

  /// Diagnostic / support logs (§57 LOGGING).
  static Future<void> _createAppLogs(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_logs (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        severity TEXT NOT NULL,
        message TEXT NOT NULL,
        tag TEXT,
        error TEXT,
        stack_trace TEXT,
        context TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_logs_created ON app_logs(created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_logs_type ON app_logs(type, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_logs_severity ON app_logs(severity, created_at)',
    );
  }

  /// Outbox locale §30.
  static Future<void> _createSyncOutbox(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
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
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_status ON sync_outbox(status, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_entity ON sync_outbox(entity, entity_id)',
    );
  }

  static Future<void> _migrateSyncQueueToOutbox(Database db) async {
    await _createSyncOutbox(db);
    final existing = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='sync_queue'",
    );
    if (existing.isEmpty) return;

    final rows = await db.query('sync_queue');
    for (final row in rows) {
      final statusRaw = (row['status']?.toString() ?? 'pending').toLowerCase();
      final status = switch (statusRaw) {
        'processing' => 'SYNCING',
        'synced' => 'SYNCED',
        'failed' || 'retrying' => 'FAILED',
        'conflict' => 'CONFLICT',
        _ => 'PENDING',
      };
      await db.insert(
        'sync_outbox',
        {
          'id': row['id'],
          'entity': row['entity_type'] ?? 'sale',
          'entity_id': row['entity_id'],
          'operation': row['operation'] ?? 'create',
          'payload': row['payload'] ?? '{}',
          'created_at': row['created_at'] ?? DateTime.now().toIso8601String(),
          'status': status,
          'retry_count': row['attempts'] ?? 0,
          'last_error': row['error_message'],
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static Future<void> _createPrintSpooler(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lan_printers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        print_group TEXT NOT NULL DEFAULT 'cashier',
        host TEXT,
        port INTEGER NOT NULL DEFAULT 9100,
        model TEXT,
        connection TEXT,
        format TEXT,
        paper_width_mm INTEGER NOT NULL DEFAULT 80,
        usb_path TEXT,
        bluetooth_address TEXT,
        system_name TEXT,
        enabled INTEGER NOT NULL DEFAULT 1,
        priority INTEGER NOT NULL DEFAULT 100,
        online INTEGER NOT NULL DEFAULT 1,
        last_error TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lan_printers_group ON lan_printers(print_group, enabled)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS print_jobs (
        id TEXT PRIMARY KEY,
        print_group TEXT NOT NULL,
        document_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        status TEXT NOT NULL,
        printer_id TEXT,
        error TEXT,
        attempts INTEGER NOT NULL DEFAULT 0,
        max_attempts INTEGER NOT NULL DEFAULT 5,
        category_id TEXT,
        product_id TEXT,
        next_retry_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_print_jobs_status ON print_jobs(status, created_at)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS print_routes (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        match_key TEXT NOT NULL,
        print_group TEXT NOT NULL,
        printer_id TEXT,
        enabled INTEGER NOT NULL DEFAULT 1,
        priority INTEGER NOT NULL DEFAULT 100,
        label TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_print_routes_kind ON print_routes(kind, match_key)',
    );
  }

  static Future<void> _upgradePrinterManagementV11(Database db) async {
    await _createPrintSpooler(db);
    await _addColumnIfMissing(db, 'print_routes', 'label', 'TEXT');
    await _addColumnIfMissing(db, 'lan_printers', 'paper_width_mm', 'INTEGER NOT NULL DEFAULT 80');
    await _addColumnIfMissing(db, 'lan_printers', 'usb_path', 'TEXT');
    await _addColumnIfMissing(db, 'lan_printers', 'bluetooth_address', 'TEXT');
    await _addColumnIfMissing(db, 'lan_printers', 'system_name', 'TEXT');
    await _addColumnIfMissing(db, 'lan_printers', 'priority', 'INTEGER NOT NULL DEFAULT 100');
    await _addColumnIfMissing(db, 'lan_printers', 'online', 'INTEGER NOT NULL DEFAULT 1');
    await _addColumnIfMissing(db, 'lan_printers', 'last_error', 'TEXT');
    await _addColumnIfMissing(db, 'print_jobs', 'attempts', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'print_jobs', 'max_attempts', 'INTEGER NOT NULL DEFAULT 5');
    await _addColumnIfMissing(db, 'print_jobs', 'category_id', 'TEXT');
    await _addColumnIfMissing(db, 'print_jobs', 'product_id', 'TEXT');
    await _addColumnIfMissing(db, 'print_jobs', 'next_retry_at', 'TEXT');
    // Normalize legacy job statuses.
    await db.execute("UPDATE print_jobs SET status = 'pending' WHERE status = 'queued'");
    await db.execute("UPDATE print_jobs SET status = 'printed' WHERE status = 'done'");
    // Normalize legacy connection alias.
    await db.execute("UPDATE lan_printers SET connection = 'lan' WHERE connection = 'network'");
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (exists) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  static Future<void> _createLanDevices(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lan_devices (
        device_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        device_type TEXT NOT NULL DEFAULT 'pos',
        os TEXT,
        ip TEXT,
        tenant_id TEXT,
        branch_id TEXT,
        store_id TEXT,
        user_id TEXT,
        user_name TEXT,
        role TEXT NOT NULL DEFAULT 'slave',
        version TEXT,
        status TEXT NOT NULL DEFAULT 'offline',
        last_seen TEXT NOT NULL,
        paired_at TEXT,
        approved INTEGER NOT NULL DEFAULT 0,
        pair_token_hash TEXT,
        pending INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lan_devices_status ON lan_devices(status, last_seen)',
    );
  }

  /// §9 Device Registry — branch + signed-in user on Master list.
  static Future<void> _upgradeLanDevicesV10(Database db) async {
    await _createLanDevices(db);
    await _addColumn(db, 'lan_devices', 'branch_id', 'TEXT');
    await _addColumn(db, 'lan_devices', 'user_id', 'TEXT');
    await _addColumn(db, 'lan_devices', 'user_name', 'TEXT');
    await db.execute(
      "UPDATE lan_devices SET branch_id = store_id WHERE (branch_id IS NULL OR branch_id = '') AND store_id IS NOT NULL AND store_id != ''",
    );
  }

  static Future<void> _createCatalogIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_store ON products(store_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_store_category ON products(store_id, category_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_categories_store ON categories(store_id)');
  }

  static Future<void> _createCustomers(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        name TEXT NOT NULL,
        code TEXT,
        email TEXT,
        phone TEXT,
        json TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)');
  }

  static Future<void> _createSaleLedger(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        method TEXT NOT NULL,
        amount INTEGER NOT NULL,
        currency TEXT NOT NULL DEFAULT 'BIF',
        reference TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS payments_sale ON payments(sale_id)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_events (
        id TEXT PRIMARY KEY,
        store_id TEXT,
        device_id TEXT,
        sequence INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS sync_events_sequence ON sync_events(sequence)');
    await db.execute('CREATE INDEX IF NOT EXISTS sync_events_entity ON sync_events(entity_type, entity_id)');
  }

  static Future<void> _createHospitality(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS hospitality_docs (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        parent_id TEXT,
        status TEXT,
        json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS hospitality_kind ON hospitality_docs(kind, status)');
  }

  static Future<void> _createLanes(Database db) async {
    await _addColumn(db, 'sales', 'device_id', 'TEXT');
    await _addColumn(db, 'sales', 'cash_register_id', 'TEXT');
    await _addColumn(db, 'sales', 'cash_session_id', 'TEXT');
    await _addColumn(db, 'sales', 'user_id', 'TEXT');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lane_sessions (
        device_id TEXT PRIMARY KEY,
        cash_register_id TEXT NOT NULL,
        cash_session_id TEXT NOT NULL,
        user_id TEXT,
        opened_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _addColumn(Database db, String table, String column, String type) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    if (info.any((row) => row['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
  }

  static Future<void> _createPaymentMethods(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_methods (
        value TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        label_fr TEXT,
        requires_customer INTEGER NOT NULL DEFAULT 0,
        supports_change INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        json TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createReferenceData(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS units (
        id TEXT PRIMARY KEY,
        code TEXT,
        name TEXT,
        symbol TEXT,
        is_fractional INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        json TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS currencies (
        id TEXT PRIMARY KEY,
        code TEXT,
        name TEXT,
        symbol TEXT,
        is_default INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        json TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS taxes (
        id TEXT PRIMARY KEY,
        code TEXT,
        name TEXT,
        rate REAL,
        is_inclusive INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        json TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS permissions (
        id TEXT PRIMARY KEY,
        slug TEXT NOT NULL,
        name TEXT,
        group_name TEXT,
        json TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS permissions_slug ON permissions(slug)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS roles (
        id TEXT PRIMARY KEY,
        slug TEXT NOT NULL,
        name TEXT,
        is_system INTEGER NOT NULL DEFAULT 0,
        json TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS roles_slug ON roles(slug)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        pin_verifier TEXT NOT NULL,
        json TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS users_pin_verifier ON users(pin_verifier)');
  }

  /// mobile.md §14 — entités absentes des versions ≤11.
  static Future<void> _createDataModelV12(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tenants (
        id TEXT PRIMARY KEY,
        code TEXT,
        name TEXT,
        json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS organizations (
        id TEXT PRIMARY KEY,
        tenant_id TEXT,
        name TEXT,
        json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS branches (
        id TEXT PRIMARY KEY,
        tenant_id TEXT,
        organization_id TEXT,
        name TEXT,
        code TEXT,
        json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_branches_tenant ON branches(tenant_id)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS terminals (
        id TEXT PRIMARY KEY,
        device_id TEXT,
        branch_id TEXT,
        store_id TEXT,
        name TEXT,
        role TEXT,
        json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS unit_conversions (
        id TEXT PRIMARY KEY,
        from_unit_id TEXT NOT NULL,
        to_unit_id TEXT NOT NULL,
        factor REAL NOT NULL,
        json TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_unit_conversions_from ON unit_conversions(from_unit_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_prices (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        store_id TEXT,
        currency TEXT,
        price INTEGER NOT NULL,
        price_list TEXT,
        json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_product_prices_product ON product_prices(product_id, store_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        name TEXT NOT NULL,
        code TEXT,
        email TEXT,
        phone TEXT,
        json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS carts (
        id TEXT PRIMARY KEY,
        store_id TEXT,
        device_id TEXT,
        user_id TEXT,
        customer_id TEXT,
        status TEXT NOT NULL DEFAULT 'open',
        json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_carts_status ON carts(status, updated_at)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_items (
        id TEXT PRIMARY KEY,
        cart_id TEXT NOT NULL,
        product_id TEXT,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price INTEGER NOT NULL DEFAULT 0,
        json TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cart_items_cart ON cart_items(cart_id)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price INTEGER NOT NULL DEFAULT 0,
        line_total INTEGER NOT NULL DEFAULT 0,
        json TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS refunds (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        method TEXT,
        reason TEXT,
        status TEXT NOT NULL DEFAULT 'recorded',
        json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_refunds_sale ON refunds(sale_id)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_registers (
        id TEXT PRIMARY KEY,
        store_id TEXT,
        code TEXT,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_movements (
        id TEXT PRIMARY KEY,
        cash_register_id TEXT,
        cash_session_id TEXT,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        memo TEXT,
        user_id TEXT,
        json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cash_movements_session ON cash_movements(cash_session_id, created_at)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id TEXT PRIMARY KEY,
        cash_register_id TEXT,
        cash_session_id TEXT,
        user_id TEXT,
        status TEXT NOT NULL DEFAULT 'open',
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        json TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shifts_status ON shifts(status, opened_at)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stocks (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        store_id TEXT,
        warehouse_id TEXT,
        quantity INTEGER NOT NULL DEFAULT 0,
        reserved INTEGER NOT NULL DEFAULT 0,
        json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_stocks_product_store ON stocks(product_id, store_id, warehouse_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_counts (
        id TEXT PRIMARY KEY,
        store_id TEXT,
        warehouse_id TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_count_items (
        id TEXT PRIMARY KEY,
        stock_count_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        expected_qty INTEGER NOT NULL DEFAULT 0,
        counted_qty INTEGER,
        json TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_count_items ON stock_count_items(stock_count_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        supplier_id TEXT,
        store_id TEXT,
        reference TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        total INTEGER NOT NULL DEFAULT 0,
        json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_purchases_status ON purchases(status, created_at)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_items (
        id TEXT PRIMARY KEY,
        purchase_id TEXT NOT NULL,
        product_id TEXT,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_cost INTEGER NOT NULL DEFAULT 0,
        line_total INTEGER NOT NULL DEFAULT 0,
        json TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase ON purchase_items(purchase_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id TEXT PRIMARY KEY,
        category TEXT,
        description TEXT,
        amount INTEGER NOT NULL DEFAULT 0,
        cash_session_id TEXT,
        user_id TEXT,
        branch TEXT,
        status TEXT NOT NULL DEFAULT 'recorded',
        json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_created ON expenses(created_at)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_tables (
        id TEXT PRIMARY KEY,
        store_id TEXT,
        name TEXT NOT NULL,
        seats INTEGER,
        status TEXT NOT NULL DEFAULT 'free',
        json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_orders (
        id TEXT PRIMARY KEY,
        table_id TEXT,
        store_id TEXT,
        status TEXT NOT NULL DEFAULT 'open',
        json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_restaurant_orders_table ON restaurant_orders(table_id, status)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_order_items (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        product_id TEXT,
        quantity INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'pending',
        json TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_restaurant_order_items ON restaurant_order_items(order_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kitchen_tickets (
        id TEXT PRIMARY KEY,
        order_id TEXT,
        station TEXT,
        status TEXT NOT NULL DEFAULT 'new',
        json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_kitchen_tickets_status ON kitchen_tickets(status, created_at)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS modifiers (
        id TEXT PRIMARY KEY,
        product_id TEXT,
        name TEXT NOT NULL,
        price_delta INTEGER NOT NULL DEFAULT 0,
        json TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_modifiers_product ON modifiers(product_id)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS extras (
        id TEXT PRIMARY KEY,
        product_id TEXT,
        name TEXT NOT NULL,
        price INTEGER NOT NULL DEFAULT 0,
        json TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_extras_product ON extras(product_id)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS printer_groups (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        json TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_printer_groups_code ON printer_groups(code)');
    const defaultGroups = <List<String>>[
      ['cashier', 'Caisse'],
      ['kitchen', 'Cuisine'],
      ['bar', 'Bar'],
      ['label', 'Étiquettes'],
    ];
    for (final group in defaultGroups) {
      final code = group[0];
      final name = group[1];
      await db.insert(
        'printer_groups',
        {
          'id': code,
          'code': code,
          'name': name,
          'json': '{"id":"$code","code":"$code","name":"$name"}',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_conflicts (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        reason TEXT,
        local_json TEXT,
        remote_json TEXT,
        status TEXT NOT NULL DEFAULT 'open',
        created_at TEXT NOT NULL,
        resolved_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_conflicts_status ON sync_conflicts(status, created_at)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT,
        read_at TEXT,
        json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id TEXT PRIMARY KEY,
        actor_id TEXT,
        action TEXT NOT NULL,
        entity_type TEXT,
        entity_id TEXT,
        json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at)',
    );
  }

  static Future<void> _migrateExpensesFromHospitality(Database db) async {
    final rows = await db.query(
      'hospitality_docs',
      where: "kind = 'expense_ticket'",
    );
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final existing = await db.query('expenses', where: 'id = ?', whereArgs: [id], limit: 1);
      if (existing.isNotEmpty) continue;
      final raw = row['json']?.toString() ?? '{}';
      await db.insert('expenses', {
        'id': id,
        'category': _jsonStringField(raw, 'category'),
        'description': _jsonStringField(raw, 'description'),
        'amount': _jsonIntField(raw, 'amount'),
        'cash_session_id':
            _jsonStringField(raw, 'cash_session_id') ?? row['parent_id']?.toString(),
        'user_id': _jsonStringField(raw, 'user_id'),
        'branch': _jsonStringField(raw, 'branch'),
        'status': row['status']?.toString() ?? 'recorded',
        'json': raw,
        'created_at': _jsonStringField(raw, 'created_at') ??
            row['updated_at']?.toString() ??
            DateTime.now().toIso8601String(),
      });
    }
  }

  /// Minimal JSON string field reader (avoids dart:convert dependency here).
  static String? _jsonStringField(String raw, String key) {
    final match = RegExp('"$key"\\s*:\\s*"([^"]*)"').firstMatch(raw);
    return match?.group(1);
  }

  static int _jsonIntField(String raw, String key) {
    final match = RegExp('"$key"\\s*:\\s*(-?\\d+)').firstMatch(raw);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}
