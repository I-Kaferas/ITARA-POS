import 'dart:convert';

import '../../../core/config/terminal_config_repository.dart';
import '../../../data/local/local_database.dart';

class ReportsStore {
  ReportsStore._();

  static final ReportsStore instance = ReportsStore._();

  Future<Map<String, dynamic>> build(String period) async {
    final start = _start(period);
    final db = await LocalDatabase.instance.database;
    final sales = await db.query('sales', orderBy: 'created_at DESC');
    final products = await db.query('products');
    final categories = await db.query('categories');
    final movements = await db.query('stock_movements', orderBy: 'created_at DESC');
    final entries = await db.query('hospitality_docs', where: "kind = 'ledger_entry'", orderBy: 'updated_at DESC');

    final categoryNames = {for (final row in categories) row['id'] as String: row['name']?.toString() ?? ''};
    final productInfo = <String, Map<String, dynamic>>{};
    for (final row in products) {
      final json = jsonDecode(row['json'] as String) as Map<String, dynamic>;
      final id = row['product_id'] as String;
      final categoryId = row['category_id']?.toString() ?? json['category_id']?.toString();
      productInfo[id] = {
        'name': json['name'] ?? row['name'] ?? id,
        'price': (row['price'] as num?)?.toInt() ?? (json['price'] as num?)?.toInt() ?? 0,
        'cost': (json['cost_price'] as num?)?.toInt() ?? 0,
        'qty': (json['quantity_on_hand'] as num?)?.toInt(),
        'threshold': (json['low_stock_threshold'] as num?)?.toInt() ?? 10,
        'category': json['category_name'] ?? categoryNames[categoryId] ?? 'Sans catégorie',
        'expires_at': json['expires_at'],
        'track_expiration': json['track_expiration'] == true,
      };
    }

    final inPeriod = sales.where((row) => _inPeriod(row['created_at'], start)).toList();
    final byProduct = <String, _Bucket>{};
    final byCategory = <String, _Bucket>{};
    final byCashier = <String, _Bucket>{};
    final byStore = <String, _Bucket>{};
    var revenue = 0;
    var credit = 0;
    var cogs = 0;
    for (final row in inPeriod) {
      final total = (row['total'] as num?)?.toInt() ?? 0;
      final due = (row['outstanding_amount'] as num?)?.toInt() ?? 0;
      revenue += total;
      if (due > 0) credit += due;
      final payload = jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
      final cashier = _cashier(payload);
      final store = _store(row['store_id']?.toString() ?? payload['store_id']?.toString() ?? '');
      _add(byCashier, cashier, cashier, 1, total);
      _add(byStore, store, store, 1, total);
      final items = payload['items'] as List<dynamic>? ?? [];
      for (final raw in items.whereType<Map>()) {
        final productId = raw['product_id']?.toString() ?? '';
        final info = productInfo[productId];
        final name = raw['name']?.toString() ?? info?['name']?.toString() ?? 'Article';
        final qty = (raw['quantity'] as num?)?.toInt() ?? 0;
        final amount = ((raw['unit_price'] as num?)?.toInt() ?? 0) * qty;
        final category = info?['category']?.toString() ?? 'Sans catégorie';
        _add(byProduct, productId.isEmpty ? name : productId, name, qty, amount);
        _add(byCategory, category, category, qty, amount);
        cogs += ((info?['cost'] as num?)?.toInt() ?? 0) * qty;
      }
    }

    final current = <Map<String, dynamic>>[];
    final low = <Map<String, dynamic>>[];
    final expiration = <Map<String, dynamic>>[];
    var valuation = 0;
    for (final info in productInfo.values) {
      final qty = info['qty'] as int?;
      if (qty == null) continue;
      final price = info['price'] as int;
      valuation += qty * price;
      current.add({'label': info['name'], 'quantity': qty, 'amount': qty * price});
      final threshold = info['threshold'] as int;
      if (qty <= threshold) {
        low.add({'label': info['name'], 'quantity': qty, 'detail': 'seuil $threshold'});
      }
      final expires = info['expires_at']?.toString();
      if (expires != null && expires.isNotEmpty) {
        expiration.add({'label': info['name'], 'detail': expires});
      } else if (info['track_expiration'] == true) {
        expiration.add({'label': info['name'], 'detail': 'Suivi, sans date'});
      }
    }
    current.sort((a, b) => (a['label'] as String).compareTo(b['label'] as String));
    low.sort((a, b) => (a['quantity'] as int).compareTo(b['quantity'] as int));

    final periodMoves = movements.where((row) => _inPeriod(row['created_at'], start)).toList();
    final moveLines = <Map<String, dynamic>>[];
    final lossLines = <Map<String, dynamic>>[];
    var lossValue = 0;
    for (final row in periodMoves) {
      final productId = row['product_id'] as String? ?? '';
      final info = productInfo[productId];
      final qty = (row['quantity'] as num?)?.toInt() ?? 0;
      final type = row['type']?.toString() ?? '';
      final amount = qty * ((info?['price'] as int?) ?? 0);
      moveLines.add({'label': '${info?['name'] ?? productId} · $type', 'quantity': qty, 'amount': amount});
      if (_isLoss(type)) {
        final value = qty.abs() * ((info?['price'] as int?) ?? 0);
        lossValue += value;
        lossLines.add({'label': '${info?['name'] ?? productId} · $type', 'quantity': qty, 'amount': value});
      }
    }

    final periodEntries = entries.map((row) {
      final json = jsonDecode(row['json'] as String) as Map<String, dynamic>;
      return json;
    }).where((row) => _inPeriod(row['created_at'], start)).toList();
    final expenses = periodEntries
        .where((row) => row['entry_type'] == 'expense')
        .fold<int>(0, (sum, row) => sum + ((row['amount'] as num?)?.toInt() ?? 0));
    final debtsRaised = periodEntries
        .where((row) => row['entry_type'] == 'expense' && row['settlement'] == 'payable')
        .fold<int>(0, (sum, row) => sum + ((row['amount'] as num?)?.toInt() ?? 0));
    final debtsPaid = periodEntries
        .where((row) => row['entry_type'] == 'payable_payment')
        .fold<int>(0, (sum, row) => sum + ((row['amount'] as num?)?.toInt() ?? 0));
    final margin = revenue - cogs;

    return {
      'period': period,
      'sales': {
        'total': revenue,
        'count': inPeriod.length,
        'by_product': _ranked(byProduct),
        'by_category': _ranked(byCategory),
        'by_cashier': _ranked(byCashier),
        'by_store': _ranked(byStore),
      },
      'stock': {
        'valuation': valuation,
        'current': current.take(40).toList(),
        'low': low.take(40).toList(),
        'movements': moveLines.take(40).toList(),
        'losses': lossLines.take(40).toList(),
        'losses_value': lossValue,
        'expiration': expiration.take(40).toList(),
      },
      'finance': {
        'revenue': revenue,
        'expenses': expenses,
        'margin': margin,
        'profit': margin - expenses,
        'credit': credit,
        'debts': debtsRaised - debtsPaid,
      },
    };
  }

  String _cashier(Map<String, dynamic> payload) {
    final config = TerminalConfigRepository.instance.config;
    final named = payload['cashier_name']?.toString().trim() ?? '';
    if (named.isNotEmpty) return named;
    final id = payload['user_id']?.toString() ?? '';
    if (id.isNotEmpty && id == config.cashierId && config.cashierName.isNotEmpty) return config.cashierName;
    return id.isEmpty ? 'Caissier' : id;
  }

  String _store(String storeId) {
    final config = TerminalConfigRepository.instance.config;
    if (storeId.isEmpty) return 'Magasin';
    if (storeId == config.storeId) return 'Ce magasin';
    return storeId;
  }

  bool _isLoss(String type) {
    final value = type.toUpperCase();
    return value == 'LOSS' || value == 'DAMAGE' || value == 'EXPIRED' || value == 'ADJUSTMENT_OUT';
  }

  DateTime _start(String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      'week' => today.subtract(Duration(days: today.weekday - 1)),
      'month' => DateTime(now.year, now.month, 1),
      'year' => DateTime(now.year, 1, 1),
      _ => today,
    };
  }

  bool _inPeriod(Object? value, DateTime start) {
    final at = DateTime.tryParse(value?.toString() ?? '');
    return at != null && !at.isBefore(start);
  }

  void _add(Map<String, _Bucket> map, String key, String label, int qty, int amount) {
    final bucket = map.putIfAbsent(key, () => _Bucket(label));
    bucket.quantity += qty;
    bucket.amount += amount;
  }

  List<Map<String, dynamic>> _ranked(Map<String, _Bucket> map) {
    final rows = map.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
    return rows.take(20).map((row) => {'label': row.label, 'quantity': row.quantity, 'amount': row.amount}).toList();
  }
}

class _Bucket {
  _Bucket(this.label);

  final String label;
  int quantity = 0;
  int amount = 0;
}
