import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../data/local/local_database.dart';
import '../../../sync/offline_store.dart';

class ServiceDeskStore {
  ServiceDeskStore._();

  static final ServiceDeskStore instance = ServiceDeskStore._();

  Future<Database> get _db => LocalDatabase.instance.database;

  Future<Map<String, dynamic>> snapshot() async {
    await _seed();
    final db = await _db;
    final rows = await db.query(
      'hospitality_docs',
      where: "kind IN ('service_offering', 'service_job', 'service_employee')",
      orderBy: 'updated_at DESC',
    );
    return {
      'docs': rows.map((row) {
        final json = jsonDecode(row['json'] as String) as Map<String, dynamic>;
        return {...json, 'id': row['id'], 'kind': row['kind'], 'status': row['status']};
      }).toList(),
    };
  }

  Future<Map<String, dynamic>> apply(Map<String, dynamic> action) async {
    await _seed();
    switch (action['action']) {
      case 'add_employee':
        await _addEmployee(action);
      case 'book':
        await _book(action);
      case 'assign':
        await _assign(action);
      case 'complete':
        await _complete(action);
      case 'pay':
        await _pay(action);
      default:
        throw Exception('Action inconnue');
    }
    return snapshot();
  }

  Future<void> _seed() async {
    final db = await _db;
    final existing = await db.query('hospitality_docs', where: "kind = 'service_offering'", limit: 1);
    if (existing.isNotEmpty) {
      await _ensureEmployees();
      return;
    }
    const defaults = [
      ['svc-salon', 'Coupe', 'salon', 1500000],
      ['svc-garage', 'Vidange', 'garage', 3500000],
      ['svc-repair', 'Réparation', 'repair', 5000000],
      ['svc-maint', 'Maintenance', 'maintenance', 2500000],
    ];
    for (final row in defaults) {
      await _save('service_offering', row[0] as String, {
        'name': row[1],
        'category': row[2],
        'price': row[3],
      });
    }
    await _ensureEmployees();
  }

  Future<void> _ensureEmployees() async {
    final db = await _db;
    final existing = await db.query('hospitality_docs', where: "kind = 'service_employee'", limit: 1);
    if (existing.isNotEmpty) return;
    await _save('service_employee', 'emp-${defaultEmployeeName().toLowerCase()}', {
      'name': defaultEmployeeName(),
    });
  }

  Future<void> _addEmployee(Map<String, dynamic> action) async {
    final name = action['name']?.toString().trim() ?? '';
    if (name.isEmpty) throw Exception('Nom d’employé requis');
    final id = action['id']?.toString().trim().isNotEmpty == true
        ? action['id'].toString()
        : const Uuid().v4();
    await _save('service_employee', id, {'name': name});
  }

  Future<void> _book(Map<String, dynamic> action) async {
    final serviceId = action['service_id']?.toString() ?? '';
    if (serviceId.isEmpty) throw Exception('Service requis');
    final offering = await _doc(serviceId);
    await _save('service_job', const Uuid().v4(), {
      'service_id': offering['id'],
      'service_name': offering['name'],
      'category': offering['category'],
      'price': offering['price'],
      'customer_name': action['customer_name'],
      'scheduled_at': action['scheduled_at'] ?? DateTime.now().toIso8601String(),
      'status': 'booked',
    }, status: 'booked');
  }

  Future<void> _assign(Map<String, dynamic> action) async {
    final job = await _doc(action['job_id'].toString());
    if (job['status'] != 'booked' && job['status'] != 'assigned') {
      throw Exception('Assignez seulement un rendez-vous ouvert');
    }
    final employee = action['employee_name']?.toString().trim() ?? '';
    if (employee.isEmpty) throw Exception('Employé requis');
    job['employee_id'] = action['employee_id'];
    job['employee_name'] = employee;
    job['status'] = 'assigned';
    await _save('service_job', job['id'].toString(), job, status: 'assigned');
  }

  Future<void> _complete(Map<String, dynamic> action) async {
    final job = await _doc(action['job_id'].toString());
    if (job['status'] != 'assigned') throw Exception('Assignez un employé avant de terminer');
    job['status'] = 'completed';
    job['completion_notes'] = action['notes'];
    job['completed_at'] = DateTime.now().toIso8601String();
    await _save('service_job', job['id'].toString(), job, status: 'completed');
  }

  Future<void> _pay(Map<String, dynamic> action) async {
    final job = await _doc(action['job_id'].toString());
    if (job['status'] == 'paid') return;
    if (job['status'] != 'completed') throw Exception('Terminez le service avant le paiement');
    final price = (job['price'] as num?)?.toInt() ?? 0;
    final sale = await OfflineStore.instance.commitSale(
      items: [
        {
          'name': job['service_name'],
          'quantity': 1,
          'unit_price': price,
        },
      ],
      payments: [
        {'method': 'cash', 'amount': price},
      ],
      notes: 'Service ${job['service_name']} · ${job['category']} · ${job['customer_name']}',
      total: price,
      paidAmount: price,
      outstandingAmount: 0,
      method: 'cash',
    );
    job['status'] = 'paid';
    job['sale_id'] = sale.saleId;
    job['reference'] = sale.reference;
    await _save('service_job', job['id'].toString(), job, status: 'paid');
  }

  Future<Map<String, dynamic>> _doc(String id) async {
    final db = await _db;
    final rows = await db.query('hospitality_docs', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw Exception('Service introuvable');
    final json = jsonDecode(rows.first['json'] as String) as Map<String, dynamic>;
    json['id'] = rows.first['id'];
    return json;
  }

  Future<void> _save(String kind, String id, Map<String, dynamic> json, {String? status}) async {
    final db = await _db;
    json['id'] = id;
    await db.insert(
      'hospitality_docs',
      {
        'id': id,
        'kind': kind,
        'parent_id': null,
        'status': status,
        'json': jsonEncode(json),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

String defaultEmployeeName() {
  final name = TerminalConfigRepository.instance.config.cashierName.trim();
  return name.isEmpty ? 'Employé' : name;
}
