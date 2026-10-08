import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'document_dao.dart';
import 'local_database.dart';

/// Ensures §14 reference rows exist (safe to call on every boot).
class DataModelBootstrap {
  DataModelBootstrap._();

  static Future<void> ensureDefaults() async {
    final db = await LocalDatabase.instance.database;
    const groups = <List<String>>[
      ['cashier', 'Caisse'],
      ['kitchen', 'Cuisine'],
      ['bar', 'Bar'],
      ['label', 'Étiquettes'],
    ];
    for (final group in groups) {
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
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Touch DAOs so missing-table failures surface early after upgrades.
    await DataModelDaos.expenses.list(limit: 1);
  }
}
