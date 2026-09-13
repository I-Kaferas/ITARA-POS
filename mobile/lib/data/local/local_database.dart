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
    if (existing != null) return existing;
    _db = await _open();
    return _db!;
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
      version: 2,
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
        await _createCustomers(db);
        await _createPaymentMethods(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCustomers(db);
          await _createPaymentMethods(db);
        }
      },
    );
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
}
