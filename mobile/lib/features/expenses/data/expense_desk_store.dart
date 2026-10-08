import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../data/local/audit_log_store.dart';
import '../../../data/local/local_database.dart';
import '../../accounting/data/ledger_store.dart';

class ExpenseDeskStore {
  ExpenseDeskStore._();

  static final ExpenseDeskStore instance = ExpenseDeskStore._();

  static const categories = [
    ['transport', 'Transport'],
    ['electricity', 'Électricité'],
    ['rent', 'Loyer'],
    ['salary', 'Salaire'],
    ['urgent_purchase', 'Achat urgent'],
    ['maintenance', 'Entretien'],
  ];

  Future<Database> get _db => LocalDatabase.instance.database;

  Future<Map<String, dynamic>> snapshot() async {
    final db = await _db;
    final rows = await db.query(
      'expenses',
      orderBy: 'created_at DESC',
      limit: 40,
    );
    final config = TerminalConfigRepository.instance.config;
    return {
      'categories': [
        for (final row in categories) {'code': row[0], 'name': row[1]},
      ],
      'context': {
        'branch': _branchLabel(config),
        'cash_session_id': config.cashSessionId,
        'user': config.cashierName.isEmpty ? 'Caissier' : config.cashierName,
      },
      'expenses': rows.map((row) {
        Map<String, dynamic> json = {};
        try {
          final decoded = jsonDecode(row['json'] as String? ?? '{}');
          if (decoded is Map) json = Map<String, dynamic>.from(decoded);
        } catch (_) {}
        return {...json, 'id': row['id']};
      }).toList(),
    };
  }

  Future<Map<String, dynamic>> record(Map<String, dynamic> action) async {
    final amount = (action['amount'] as num?)?.toInt() ?? 0;
    final description = action['description']?.toString().trim() ?? '';
    final code = action['category']?.toString() ?? '';
    List<String>? category;
    for (final row in categories) {
      if (row[0] == code) category = row;
    }
    if (amount <= 0) throw Exception('Montant invalide');
    if (description.isEmpty) throw Exception('Libellé requis');
    if (category == null) throw Exception('Catégorie requise');

    final config = TerminalConfigRepository.instance.config;
    final sessionId = action['cash_session_id']?.toString().isNotEmpty == true
        ? action['cash_session_id'].toString()
        : config.cashSessionId;
    final userName = action['user_name']?.toString().trim().isNotEmpty == true
        ? action['user_name'].toString().trim()
        : (config.cashierName.isEmpty ? 'Caissier' : config.cashierName);
    final branch = action['branch']?.toString().trim().isNotEmpty == true
        ? action['branch'].toString().trim()
        : _branchLabel(config);
    final linkSession = action['link_session'] == false ? '' : sessionId;

    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    final json = {
      'id': id,
      'category': category[0],
      'category_name': category[1],
      'description': description,
      'amount': amount,
      'branch': branch,
      'cash_session_id': linkSession,
      'user_id': config.cashierId,
      'user_name': userName,
      'created_at': now,
    };
    final db = await _db;
    await db.insert('expenses', {
      'id': id,
      'category': category[0],
      'description': description,
      'amount': amount,
      'cash_session_id': linkSession.isEmpty ? null : linkSession,
      'user_id': config.cashierId,
      'branch': branch,
      'status': 'recorded',
      'json': jsonEncode(json),
      'created_at': now,
    });
    // Keep legacy hospitality mirror for Master API consumers still filtering by kind.
    await db.insert(
      'hospitality_docs',
      {
        'id': id,
        'kind': 'expense_ticket',
        'parent_id': linkSession.isEmpty ? null : linkSession,
        'status': 'recorded',
        'json': jsonEncode(json),
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await LedgerStore.instance.expense({
      'amount': amount,
      'memo': '${category[1]} · $description',
      'settlement': linkSession.isEmpty ? 'payable' : 'cash',
    });
    await AuditLogStore.instance.record(
      action: 'expense.recorded',
      actorId: config.cashierId,
      entityType: 'expense',
      entityId: id,
      meta: {'amount': amount, 'category': category[0]},
    );
    return snapshot();
  }

  String _branchLabel(dynamic config) {
    final brand = config.brandName?.toString().trim() ?? '';
    if (brand.isNotEmpty) return brand;
    final store = config.storeId?.toString() ?? '';
    return store.isEmpty ? 'Succursale' : 'Magasin $store';
  }
}
