import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/local_database.dart';
import '../../../sync/offline_store.dart';

class CustomerAccountStore {
  CustomerAccountStore._();

  static final CustomerAccountStore instance = CustomerAccountStore._();

  static const pointsPerAmount = 100000;
  static const rewardPerPoint = 100;

  Future<Database> get _db => LocalDatabase.instance.database;

  Future<Map<String, dynamic>> account(String customerId) async {
    final customer = await OfflineStore.instance.findCustomer(customerId);
    if (customer == null) throw Exception('Client introuvable');
    final lines = await _lines(customer.id);
    var balance = 0;
    final history = <Map<String, dynamic>>[];
    for (final line in lines) {
      final amount = (line['amount'] as num?)?.toInt() ?? 0;
      balance += amount;
      history.add({...line, 'balance': balance});
    }
    final points = await _points(customer.id);
    return {
      'customer_id': customer.id,
      'customer_name': customer.name,
      'opening_balance': 0,
      'balance': balance,
      'points': points,
      'rule': '1000 dépensés = 1 point',
      'reward': '1 point = 1,00 de récompense',
      'lines': history.reversed.take(40).toList(),
    };
  }

  Future<Map<String, dynamic>> postSale({
    required String customerId,
    required String saleId,
    required int total,
    required int outstanding,
    required List<Map<String, dynamic>> payments,
    String? reference,
  }) async {
    if (await _exists('sale-credit-$saleId') || await _exists('sale-points-$saleId')) {
      return account(customerId);
    }
    final creditPaid = payments
        .where((payment) => payment['method']?.toString() == 'credit')
        .fold<int>(0, (sum, payment) => sum + ((payment['amount'] as num?)?.toInt() ?? 0));
    final charged = creditPaid + (outstanding > 0 ? outstanding : 0);
    if (charged > 0) {
      await _save('sale-credit-$saleId', {
        'customer_id': customerId,
        'type': 'sale',
        'amount': charged,
        'memo': 'Vente à crédit ${reference ?? saleId}',
        'sale_id': saleId,
      });
    }
    final earned = total <= 0 ? 0 : total ~/ pointsPerAmount;
    if (earned > 0) {
      await _addPoints(customerId, earned);
      await _save('sale-points-$saleId', {
        'customer_id': customerId,
        'type': 'points',
        'amount': 0,
        'points': earned,
        'memo': 'Achat · $earned pt',
        'sale_id': saleId,
      });
    }
    return account(customerId);
  }

  Future<Map<String, dynamic>> pay(String customerId, int amount) async {
    if (amount <= 0) throw Exception('Montant invalide');
    final current = await account(customerId);
    final balance = (current['balance'] as num?)?.toInt() ?? 0;
    if (amount > balance) throw Exception('Montant supérieur au solde');
    await _save(const Uuid().v4(), {
      'customer_id': customerId,
      'type': 'payment',
      'amount': -amount,
      'memo': 'Paiement',
    });
    return account(customerId);
  }

  Future<Map<String, dynamic>> redeem(String customerId, int points) async {
    if (points <= 0) throw Exception('Points invalides');
    final available = await _points(customerId);
    if (points > available) throw Exception('Points insuffisants');
    final reward = points * rewardPerPoint;
    await _addPoints(customerId, -points);
    await _save(const Uuid().v4(), {
      'customer_id': customerId,
      'type': 'reward',
      'amount': -reward,
      'points': -points,
      'memo': 'Récompense · $points pt',
    });
    return account(customerId);
  }

  Future<int> _points(String customerId) async {
    final db = await _db;
    final rows = await db.query('hospitality_docs', where: 'id = ?', whereArgs: ['loyalty-$customerId'], limit: 1);
    if (rows.isEmpty) return 0;
    final json = jsonDecode(rows.first['json'] as String) as Map<String, dynamic>;
    return (json['points'] as num?)?.toInt() ?? 0;
  }

  Future<void> _addPoints(String customerId, int delta) async {
    final next = (await _points(customerId)) + delta;
    if (next < 0) throw Exception('Points insuffisants');
    final db = await _db;
    await db.insert(
      'hospitality_docs',
      {
        'id': 'loyalty-$customerId',
        'kind': 'loyalty',
        'parent_id': customerId,
        'status': 'active',
        'json': jsonEncode({'customer_id': customerId, 'points': next}),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> _lines(String customerId) async {
    final db = await _db;
    final rows = await db.query(
      'hospitality_docs',
      where: "kind = 'customer_ledger' AND parent_id = ?",
      whereArgs: [customerId],
      orderBy: 'updated_at ASC',
    );
    return rows.map((row) {
      final json = jsonDecode(row['json'] as String) as Map<String, dynamic>;
      return {...json, 'id': row['id']};
    }).toList();
  }

  Future<bool> _exists(String id) async {
    final db = await _db;
    final rows = await db.query('hospitality_docs', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isNotEmpty;
  }

  Future<void> _save(String id, Map<String, dynamic> json) async {
    final db = await _db;
    json['id'] = id;
    json['created_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'hospitality_docs',
      {
        'id': id,
        'kind': 'customer_ledger',
        'parent_id': json['customer_id'],
        'status': json['type'],
        'json': jsonEncode(json),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
