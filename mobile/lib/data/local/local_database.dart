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
      version: 7,
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
        await _createCatalogIndexes(db);
        await _createCustomers(db);
        await _createPaymentMethods(db);
        await _createSaleLedger(db);
        await _createLanes(db);
        await _createHospitality(db);
        await _createReferenceData(db);
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
      },
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
}
