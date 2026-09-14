import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/local_database.dart';

class LedgerStore {
  LedgerStore._();

  static final LedgerStore instance = LedgerStore._();

  Future<Database> get _db => LocalDatabase.instance.database;

  Future<Map<String, dynamic>> snapshot() async {
    final db = await _db;
    final sales = await db.query('sales', orderBy: 'created_at DESC');
    final payments = await db.query('payments', orderBy: 'created_at DESC');
    final movements = await db.query('stock_movements', orderBy: 'created_at DESC');
    final products = await db.query('products');
    final entries = (await db.query(
      'hospitality_docs',
      where: "kind = 'ledger_entry'",
      orderBy: 'updated_at DESC',
    )).map(_decode).toList();

    final names = <String, String>{};
    final prices = <String, int>{};
    var inventory = 0;
    for (final row in products) {
      final json = jsonDecode(row['json'] as String) as Map<String, dynamic>;
      final id = row['product_id'] as String;
      names[id] = json['name']?.toString() ?? row['name']?.toString() ?? id;
      final price = (row['price'] as num?)?.toInt() ??
          (json['price'] as num?)?.toInt() ??
          (json['cost_price'] as num?)?.toInt() ??
          0;
      prices[id] = price;
      final qty = (json['quantity_on_hand'] as num?)?.toInt();
      if (qty == null || qty <= 0 || price <= 0) continue;
      inventory += qty * price;
    }

    final revenue = sales.fold<int>(0, (sum, row) => sum + ((row['total'] as num?)?.toInt() ?? 0));
    final receivable = sales.fold<int>(0, (sum, row) {
      final due = (row['outstanding_amount'] as num?)?.toInt() ?? 0;
      return sum + (due > 0 ? due : 0);
    });
    final collected = payments.fold<int>(0, (sum, row) {
      if ((row['method']?.toString() ?? '') == 'credit') return sum;
      return sum + ((row['amount'] as num?)?.toInt() ?? 0);
    });
    final expenses = entries.where((row) => row['entry_type'] == 'expense');
    final expenseTotal = expenses.fold<int>(0, (sum, row) => sum + ((row['amount'] as num?)?.toInt() ?? 0));
    final payableRaised = expenses
        .where((row) => row['settlement'] == 'payable')
        .fold<int>(0, (sum, row) => sum + ((row['amount'] as num?)?.toInt() ?? 0));
    final payablePaid = entries
        .where((row) => row['entry_type'] == 'payable_payment')
        .fold<int>(0, (sum, row) => sum + ((row['amount'] as num?)?.toInt() ?? 0));
    final cashOut = expenses
            .where((row) => row['settlement'] != 'payable')
            .fold<int>(0, (sum, row) => sum + ((row['amount'] as num?)?.toInt() ?? 0)) +
        payablePaid;
    final payable = payableRaised - payablePaid;
    final cash = collected - cashOut;
    final profit = revenue - expenseTotal;

    return {
      'payable_open': payable < 0 ? 0 : payable,
      'books': [
        _book('revenue', 'Recettes', revenue, [
          for (final row in sales.take(40))
            _line(row['created_at'], row['reference'], (row['total'] as num?)?.toInt() ?? 0),
        ]),
        _book('expense', 'Dépenses', expenseTotal, [
          for (final row in expenses)
            _line(row['created_at'], row['memo'], (row['amount'] as num?)?.toInt() ?? 0),
        ]),
        _book('receivable', 'Créances', receivable, [
          for (final row in sales.take(40))
            if (((row['outstanding_amount'] as num?)?.toInt() ?? 0) > 0)
              _line(row['created_at'], row['reference'], (row['outstanding_amount'] as num?)?.toInt() ?? 0),
        ]),
        _book('payable', 'Dettes', payable < 0 ? 0 : payable, [
          for (final row in entries)
            if (row['entry_type'] == 'expense' && row['settlement'] == 'payable')
              _line(row['created_at'], row['memo'], (row['amount'] as num?)?.toInt() ?? 0)
            else if (row['entry_type'] == 'payable_payment')
              _line(row['created_at'], row['memo'] ?? 'Règlement', -((row['amount'] as num?)?.toInt() ?? 0)),
        ]),
        _book('cash', 'Caisse', cash, [
          for (final row in payments.take(40))
            if ((row['method']?.toString() ?? '') != 'credit')
              _line(row['created_at'], 'Encaissement ${row['method']}', (row['amount'] as num?)?.toInt() ?? 0),
          for (final row in expenses)
            if (row['settlement'] != 'payable')
              _line(row['created_at'], row['memo'], -((row['amount'] as num?)?.toInt() ?? 0)),
          for (final row in entries)
            if (row['entry_type'] == 'payable_payment')
              _line(row['created_at'], row['memo'] ?? 'Règlement', -((row['amount'] as num?)?.toInt() ?? 0)),
        ]),
        _book('inventory', 'Stock', inventory, [
          for (final row in movements.take(40))
            _line(
              row['created_at'],
              '${row['type']} · ${names[row['product_id']] ?? row['product_id']}',
              ((row['quantity'] as num?)?.toInt() ?? 0) * (prices[row['product_id'] as String? ?? ''] ?? 0),
            ),
        ]),
        _book('profit', 'Profit', profit, [
          _line(DateTime.now().toIso8601String(), 'Recettes − dépenses', profit),
        ]),
      ],
    };
  }

  Future<Map<String, dynamic>> expense(Map<String, dynamic> action) async {
    final amount = (action['amount'] as num?)?.toInt() ?? 0;
    final memo = action['memo']?.toString().trim() ?? '';
    if (amount <= 0) throw Exception('Montant invalide');
    if (memo.isEmpty) throw Exception('Libellé requis');
    final settlement = action['settlement']?.toString() == 'payable' ? 'payable' : 'cash';
    await _save({
      'entry_type': 'expense',
      'amount': amount,
      'settlement': settlement,
      'memo': memo,
      'created_at': DateTime.now().toIso8601String(),
    });
    return snapshot();
  }

  Future<Map<String, dynamic>> payPayable(Map<String, dynamic> action) async {
    final amount = (action['amount'] as num?)?.toInt() ?? 0;
    if (amount <= 0) throw Exception('Montant invalide');
    final current = await snapshot();
    final open = (current['payable_open'] as num?)?.toInt() ?? 0;
    if (amount > open) throw Exception('Montant supérieur à la dette');
    await _save({
      'entry_type': 'payable_payment',
      'amount': amount,
      'memo': (action['memo']?.toString().trim().isNotEmpty == true)
          ? action['memo'].toString().trim()
          : 'Règlement fournisseur',
      'created_at': DateTime.now().toIso8601String(),
    });
    return snapshot();
  }

  Map<String, dynamic> _book(String code, String label, int balance, List<Map<String, dynamic>> lines) {
    return {
      'code': code,
      'label': label,
      'balance': balance,
      'lines': lines.take(40).toList(),
    };
  }

  Map<String, dynamic> _line(Object? at, Object? memo, int amount) {
    return {
      'at': at?.toString() ?? '',
      'memo': memo?.toString() ?? '',
      'amount': amount,
    };
  }

  Map<String, dynamic> _decode(Map<String, Object?> row) {
    final json = jsonDecode(row['json'] as String) as Map<String, dynamic>;
    return {...json, 'id': row['id']};
  }

  Future<void> _save(Map<String, dynamic> json) async {
    final db = await _db;
    final id = const Uuid().v4();
    json['id'] = id;
    await db.insert('hospitality_docs', {
      'id': id,
      'kind': 'ledger_entry',
      'parent_id': null,
      'status': json['entry_type'],
      'json': jsonEncode(json),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
