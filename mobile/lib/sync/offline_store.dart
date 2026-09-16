import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../core/config/terminal_config_repository.dart';
import '../data/local/local_database.dart';
import '../features/pos/domain/pos_models.dart';
import 'sync_models.dart';
import 'sync_numbers.dart';

class StockConflict implements Exception {
  StockConflict(this.message);

  final String message;

  @override
  String toString() => message;
}

class OfflineStore {
  OfflineStore._();

  static final OfflineStore instance = OfflineStore._();

  Future<void> _stockChain = Future<void>.value();

  Future<Database> get _db => LocalDatabase.instance.database;

  Future<void> cacheCatalog(PosCatalog catalog) async {
    final db = await _db;
    final products = <String, PosProduct>{};
    for (final product in catalog.products) {
      if (product.productId.isEmpty) continue;
      products[product.productId] = product;
    }
    final categories = <String, PosCategory>{};
    for (final category in catalog.categories) {
      if (category.id.isEmpty) continue;
      categories[category.id] = category;
    }

    final existingStock = <String, Map<String, dynamic>>{};
    final existingRows = await db.query('products', where: 'store_id = ?', whereArgs: [catalog.storeId]);
    for (final row in existingRows) {
      final decoded = jsonDecode(row['json'] as String);
      if (decoded is Map<String, dynamic>) {
        existingStock[row['product_id'] as String] = decoded;
      }
    }

    final localOnly = existingRows.where((row) {
      final productId = row['product_id'] as String? ?? '';
      final json = existingStock[productId];
      return json?['local_production'] == true && !products.containsKey(productId);
    }).toList();

    await db.transaction((txn) async {
      await txn.delete('products', where: 'store_id = ?', whereArgs: [catalog.storeId]);
      await txn.delete('categories', where: 'store_id = ?', whereArgs: [catalog.storeId]);
      for (final product in products.values) {
        final json = _productToJson(product);
        final previous = existingStock[product.productId];
        final previousVersion = _asInt(previous?['stock_version']);
        if (previous != null && previousVersion > product.stockVersion) {
          json['quantity_on_hand'] = previous['quantity_on_hand'];
          json['stock_version'] = previousVersion;
          if (previous['stock_display'] != null) json['stock_display'] = previous['stock_display'];
        }
        if (previous?['local_production'] == true) json['local_production'] = true;
        await txn.insert(
          'products',
          {
            'product_id': product.productId,
            'store_id': catalog.storeId,
            'sku': product.sku,
            'name': product.name,
            'price': product.price,
            'category_id': product.categoryId,
            'json': jsonEncode(json),
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final row in localOnly) {
        await txn.insert('products', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final category in categories.values) {
        await txn.insert(
          'categories',
          {
            'id': category.id,
            'store_id': catalog.storeId,
            'name': category.name,
            'parent_id': category.parentId,
            'json': jsonEncode({
              'id': category.id,
              'name': category.name,
              'parent_id': category.parentId,
              'sort_order': category.sortOrder,
            }),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await setCheckpoint('catalog_synced_at', DateTime.now().toIso8601String());
  }

  Future<PosCatalog?> loadCatalog(String storeId) async {
    if (storeId.isEmpty) return null;
    final db = await _db;
    final products = await db.query('products', where: 'store_id = ?', whereArgs: [storeId]);
    if (products.isEmpty) return null;
    final categories = await db.query('categories', where: 'store_id = ?', whereArgs: [storeId]);
    return PosCatalog(
      storeId: storeId,
      products: products
          .map((row) => PosProduct.fromJson(jsonDecode(row['json'] as String) as Map<String, dynamic>))
          .toList(),
      categories: categories
          .map((row) => PosCategory.fromJson(jsonDecode(row['json'] as String) as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> cacheCustomers(List<PosCustomer> customers, {bool replaceSynced = true}) async {
    if (customers.isEmpty && !replaceSynced) return;
    final db = await _db;
    await db.transaction((txn) async {
      if (replaceSynced) {
        await txn.delete('customers', where: "sync_status = 'synced'");
      }
      for (final customer in customers) {
        if (customer.id.isEmpty) continue;
        final existing = await txn.query('customers', where: 'id = ? OR server_id = ?', whereArgs: [customer.id, customer.id], limit: 1);
        if (existing.isNotEmpty) {
          if (existing.first['sync_status'] == 'pending') continue;
          if (existing.first['id'] != customer.id) continue;
        }
        await txn.insert(
          'customers',
          {
            'id': customer.id,
            'server_id': customer.serverId ?? customer.id,
            'name': customer.name,
            'code': customer.code,
            'email': customer.email,
            'phone': customer.phone,
            'json': jsonEncode(customer.toJson()),
            'sync_status': 'synced',
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await setCheckpoint('customers_synced_at', DateTime.now().toIso8601String());
  }

  Future<List<PosCustomer>> searchCustomers(String query, {int limit = 30}) async {
    final db = await _db;
    final term = query.trim();
    final rows = term.isEmpty
        ? await db.query('customers', orderBy: 'created_at DESC', limit: limit)
        : await db.query(
            'customers',
            where: 'name LIKE ? OR IFNULL(code, \'\') LIKE ? OR IFNULL(email, \'\') LIKE ? OR IFNULL(phone, \'\') LIKE ?',
            whereArgs: ['%$term%', '%$term%', '%$term%', '%$term%'],
            orderBy: 'name ASC',
            limit: limit,
          );
    return rows.map(_customerFromRow).toList();
  }

  Future<PosCustomer?> findCustomer(String id) async {
    final db = await _db;
    final rows = await db.query(
      'customers',
      where: 'id = ? OR server_id = ?',
      whereArgs: [id, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _customerFromRow(rows.first);
  }

  Future<PosCustomer> createLocalCustomer({
    required String name,
    String? phone,
    String? email,
  }) async {
    final db = await _db;
    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    final customer = PosCustomer(
      id: id,
      name: name.trim(),
      phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
      email: email?.trim().isEmpty == true ? null : email?.trim(),
      pending: true,
    );
    final payload = {
      'idempotency_key': id,
      'client_id': id,
      'name': customer.name,
      if (customer.phone != null) 'phone': customer.phone,
      if (customer.email != null) 'email': customer.email,
    };

    await db.transaction((txn) async {
      await txn.insert('customers', {
        'id': id,
        'server_id': null,
        'name': customer.name,
        'code': null,
        'email': customer.email,
        'phone': customer.phone,
        'json': jsonEncode(customer.toJson()),
        'sync_status': SyncQueueStatus.pending.name,
        'created_at': now,
      });
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'entity_type': 'customer',
        'entity_id': id,
        'operation': 'create',
        'payload': jsonEncode(payload),
        'priority': 0,
        'status': SyncQueueStatus.pending.name,
        'attempts': 0,
        'created_at': now,
      });
    });

    return customer;
  }

  Future<void> cachePaymentMethods(List<PosPaymentMethod> methods) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('payment_methods');
      for (final method in methods) {
        if (method.value.isEmpty) continue;
        await txn.insert('payment_methods', {
          'value': method.value,
          'label': method.label,
          'label_fr': method.labelFr,
          'requires_customer': method.requiresCustomer ? 1 : 0,
          'supports_change': method.supportsChange ? 1 : 0,
          'sort_order': method.sortOrder,
          'json': jsonEncode(method.toJson()),
        });
      }
    });
    await setCheckpoint('payment_methods_synced_at', DateTime.now().toIso8601String());
  }

  Future<List<PosPaymentMethod>> loadPaymentMethods() async {
    final db = await _db;
    final rows = await db.query('payment_methods', orderBy: 'sort_order ASC, label ASC');
    if (rows.isEmpty) return PosPaymentMethod.defaults;
    return rows
        .map((row) => PosPaymentMethod.fromJson(jsonDecode(row['json'] as String) as Map<String, dynamic>))
        .where((method) => method.value.isNotEmpty)
        .toList();
  }

  Future<void> cacheReferenceBundle(Map<String, dynamic> data) async {
    final paymentMethods = _mapList(data['payment_methods'])
        .map(PosPaymentMethod.fromJson)
        .where((method) => method.value.isNotEmpty)
        .toList();
    if (paymentMethods.isNotEmpty) {
      await cachePaymentMethods(paymentMethods);
    }

    await _replaceJsonTable(
      'units',
      _mapList(data['units']),
      (item) => {
        'id': item['id']?.toString() ?? '',
        'code': item['code']?.toString(),
        'name': item['name']?.toString(),
        'symbol': item['symbol']?.toString(),
        'is_fractional': (item['is_fractional'] == true || item['is_fractional'] == 1) ? 1 : 0,
        'is_active': (item['is_active'] == false || item['is_active'] == 0) ? 0 : 1,
        'json': jsonEncode(item),
      },
      idKey: 'id',
    );

    await _replaceJsonTable(
      'currencies',
      _mapList(data['currencies']),
      (item) => {
        'id': item['id']?.toString() ?? '',
        'code': item['code']?.toString(),
        'name': item['name']?.toString(),
        'symbol': item['symbol']?.toString(),
        'is_default': (item['is_default'] == true || item['is_default'] == 1) ? 1 : 0,
        'is_active': (item['is_active'] == false || item['is_active'] == 0) ? 0 : 1,
        'json': jsonEncode(item),
      },
      idKey: 'id',
    );

    await _replaceJsonTable(
      'taxes',
      _mapList(data['taxes']),
      (item) => {
        'id': item['id']?.toString() ?? '',
        'code': item['code']?.toString(),
        'name': item['name']?.toString(),
        'rate': syncAsDoubleOrNull(item['rate']),
        'is_inclusive': (item['is_inclusive'] == true || item['is_inclusive'] == 1) ? 1 : 0,
        'is_active': (item['is_active'] == false || item['is_active'] == 0) ? 0 : 1,
        'json': jsonEncode(item),
      },
      idKey: 'id',
    );

    await _replaceJsonTable(
      'permissions',
      _mapList(data['permissions']),
      (item) => {
        'id': item['id']?.toString() ?? item['slug']?.toString() ?? '',
        'slug': item['slug']?.toString() ?? '',
        'name': item['name']?.toString(),
        'group_name': item['group']?.toString() ?? item['group_name']?.toString(),
        'json': jsonEncode(item),
      },
      idKey: 'id',
    );

    await _replaceJsonTable(
      'roles',
      _mapList(data['roles']),
      (item) => {
        'id': item['id']?.toString() ?? item['slug']?.toString() ?? '',
        'slug': item['slug']?.toString() ?? '',
        'name': item['name']?.toString(),
        'is_system': (item['is_system'] == true || item['is_system'] == 1) ? 1 : 0,
        'json': jsonEncode(item),
      },
      idKey: 'id',
    );

    await _replaceJsonTable(
      'users',
      _mapList(data['users']).where((item) => (item['pin_verifier']?.toString() ?? '').isNotEmpty),
      (item) => {
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
        'email': item['email']?.toString(),
        'is_active': (item['is_active'] == false || item['is_active'] == 0) ? 0 : 1,
        'pin_verifier': item['pin_verifier']?.toString() ?? '',
        'json': jsonEncode(item),
      },
      idKey: 'id',
    );

    await setCheckpoint('references_synced_at', DateTime.now().toIso8601String());
  }

  Future<Map<String, dynamic>> referenceDocument() async {
    return {
      'payment_methods': await paymentMethodDocuments(),
      'units': await _documentsFrom('units'),
      'currencies': await _documentsFrom('currencies'),
      'taxes': await _documentsFrom('taxes'),
      'permissions': await _documentsFrom('permissions'),
      'roles': await _documentsFrom('roles'),
      'users': await _documentsFrom('users'),
    };
  }

  Future<Map<String, dynamic>?> findOfflineUserByPin(String pin) async {
    final db = await _db;
    final rows = await db.query('users', where: 'is_active = 1');
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      final verifier = row['pin_verifier']?.toString() ?? '';
      if (id.isEmpty || verifier.isEmpty) continue;
      final candidate = sha256.convert(utf8.encode('itara-pos|$id|$pin')).toString();
      if (candidate == verifier) {
        final decoded = jsonDecode(row['json'] as String);
        if (decoded is Map<String, dynamic>) return decoded;
        return {
          'id': id,
          'name': row['name'],
          'email': row['email'],
          'pin_verifier': verifier,
        };
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _documentsFrom(String table) async {
    final db = await _db;
    final rows = await db.query(table);
    return rows
        .map((row) {
          final decoded = jsonDecode(row['json'] as String);
          return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _replaceJsonTable(
    String table,
    Iterable<Map<String, dynamic>> items,
    Map<String, Object?> Function(Map<String, dynamic> item) toRow, {
    required String idKey,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(table);
      for (final item in items) {
        final row = toRow(item);
        final id = row[idKey]?.toString() ?? '';
        if (id.isEmpty) continue;
        await txn.insert(table, row);
      }
    });
  }

  List<Map<String, dynamic>> _mapList(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> applyCustomerServerId(String localId, String serverId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'customers',
        {
          'server_id': serverId,
          'sync_status': SyncQueueStatus.synced.name,
        },
        where: 'id = ?',
        whereArgs: [localId],
      );

      final sales = await txn.query('sales', where: "sync_status != 'synced'");
      for (final sale in sales) {
        final payload = jsonDecode(sale['payload_json'] as String) as Map<String, dynamic>;
        if (!_payloadUsesCustomer(payload, localId)) continue;
        payload['customer_id'] = serverId;
        payload['customer_client_id'] = localId;
        await txn.update(
          'sales',
          {'payload_json': jsonEncode(payload)},
          where: 'id = ?',
          whereArgs: [sale['id']],
        );
      }

      final queued = await txn.query('sync_queue', where: "entity_type = 'sale' AND status != 'synced'");
      for (final row in queued) {
        final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
        if (!_payloadUsesCustomer(payload, localId)) continue;
        payload['customer_id'] = serverId;
        payload['customer_client_id'] = localId;
        await txn.update(
          'sync_queue',
          {'payload': jsonEncode(payload)},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    });
  }

  PosCustomer _customerFromRow(Map<String, dynamic> row) {
    final json = jsonDecode(row['json'] as String) as Map<String, dynamic>;
    final pending = row['sync_status'] == SyncQueueStatus.pending.name;
    return PosCustomer.fromJson({
      ...json,
      'id': row['id'],
      'server_id': row['server_id'],
      'name': row['name'] ?? json['name'],
      'pending': pending,
      'sync_status': row['sync_status'],
    });
  }

  bool _payloadUsesCustomer(Map<String, dynamic> payload, String localId) {
    return payload['customer_id'] == localId || payload['customer_client_id'] == localId;
  }

  Future<Map<String, dynamic>?> prepareSalePayload(Map<String, dynamic> payload) async {
    final clientId = payload['customer_client_id']?.toString();
    final customerId = payload['customer_id']?.toString();
    final lookup = (clientId != null && clientId.isNotEmpty) ? clientId : customerId;
    if (lookup == null || lookup.isEmpty) return payload;

    final customer = await findCustomer(lookup);
    if (customer == null) return payload;
    if (customer.pending || customer.serverId == null || customer.serverId!.isEmpty) {
      return null;
    }
    return {
      ...payload,
      'customer_id': customer.serverId,
      'customer_client_id': customer.id,
    };
  }

  Future<PosSaleResult> commitSale({
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> payments,
    String? customerId,
    String? warehouseId,
    String? notes,
    String? dueDate,
    Map<String, dynamic>? installments,
    String? saleId,
    required int total,
    required int paidAmount,
    required int outstandingAmount,
    required String method,
  }) async {
    final config = TerminalConfigRepository.instance.config;
    if (config.storeId.isEmpty) {
      throw Exception('STORE_ID is required for POS catalog');
    }

    final db = await _db;
    final id = const Uuid().v4();
    final reference = await _nextReference(db, config.deviceIdentifier);
    final now = DateTime.now().toIso8601String();
    final linkedCustomer = customerId == null ? null : await findCustomer(customerId);
    final remoteCustomerId = linkedCustomer?.saleCustomerId ?? customerId;
    final payload = {
      'idempotency_key': id,
      'client_reference': reference,
      'device_id': config.deviceId.isNotEmpty ? config.deviceId : config.deviceIdentifier,
      if (config.cashRegisterId.isNotEmpty) 'cash_register_id': config.cashRegisterId,
      if (config.cashSessionId.isNotEmpty) 'cash_session_id': config.cashSessionId,
      if (config.cashierId.isNotEmpty) 'user_id': config.cashierId,
      if (config.cashierName.isNotEmpty) 'cashier_name': config.cashierName,
      'store_id': config.storeId,
      'items': items,
      'payments': payments,
      if (remoteCustomerId != null) 'customer_id': remoteCustomerId,
      if (customerId != null) 'customer_client_id': customerId,
      if (warehouseId != null) 'warehouse_id': warehouseId,
      if (notes != null) 'notes': notes,
      if (saleId != null && saleId.isNotEmpty) 'sale_id': saleId,
      if (dueDate != null) 'due_date': dueDate,
      if (installments != null) 'installments': installments,
      'sold_at': now,
    };

    await exclusiveStock(() => db.transaction((txn) async {
      await _bindLane(txn, payload);
      final paymentRows = <Map<String, dynamic>>[];
      for (final payment in payments) {
        final amount = _asInt(payment['amount']);
        if (amount <= 0) continue;
        paymentRows.add({
          'id': const Uuid().v4(),
          'sale_id': id,
          'method': payment['method']?.toString().isNotEmpty == true ? payment['method'].toString() : method,
          'amount': amount,
          'currency': payment['currency']?.toString().isNotEmpty == true
              ? payment['currency'].toString()
              : AppConfig.currencyCode,
          'reference': payment['reference']?.toString(),
          'created_at': now,
        });
      }
      if (paymentRows.isEmpty) {
        paymentRows.add({
          'id': const Uuid().v4(),
          'sale_id': id,
          'method': method,
          'amount': paidAmount,
          'currency': AppConfig.currencyCode,
          'reference': null,
          'created_at': now,
        });
      }

      final eventId = const Uuid().v4();
      final sequence = await _nextSyncSequence(txn);
      final eventPayload = {
        'reference': reference,
        'total': total,
        'paid_amount': paidAmount,
        'outstanding_amount': outstandingAmount,
        'method': method,
        'payment_ids': paymentRows.map((row) => row['id']).toList(),
        'movement_ids': <String>[],
        'item_count': items.length,
        'device_id': payload['device_id'],
        'cash_register_id': payload['cash_register_id'],
        'cash_session_id': payload['cash_session_id'],
        'user_id': payload['user_id'],
      };
      payload['local_sync_event_id'] = eventId;
      payload['local_sequence'] = sequence;

      await txn.insert('sales', {
        'id': id,
        'reference': reference,
        'store_id': config.storeId,
        'payload_json': jsonEncode(payload),
        'total': total,
        'paid_amount': paidAmount,
        'outstanding_amount': outstandingAmount,
        'method': method,
        'sync_status': SyncQueueStatus.pending.name,
        'device_id': payload['device_id'],
        'cash_register_id': payload['cash_register_id'],
        'cash_session_id': payload['cash_session_id'],
        'user_id': payload['user_id'],
        'created_at': now,
      });

      for (final row in paymentRows) {
        await txn.insert('payments', row);
      }

      final movementIds = <String>[];
      for (final item in items) {
        final productId = item['product_id']?.toString() ?? '';
        final quantity = _asInt(item['quantity']);
        if (productId.isEmpty || quantity <= 0) continue;
        final movementId = const Uuid().v4();
        movementIds.add(movementId);
        await txn.insert('stock_movements', {
          'id': movementId,
          'sale_id': id,
          'product_id': productId,
          'quantity': -quantity,
          'type': 'SALE',
          'created_at': now,
        });
        await _applyStockDelta(txn, productId, quantity, authoritative: config.isMaster || !config.isSlave);
      }
      eventPayload['movement_ids'] = movementIds;

      await txn.insert('sync_events', {
        'id': eventId,
        'store_id': config.storeId,
        'device_id': config.deviceId.isEmpty ? null : config.deviceId,
        'sequence': sequence,
        'event_type': 'sale.completed',
        'entity_type': 'sale',
        'entity_id': id,
        'payload': jsonEncode(eventPayload),
        'occurred_at': now,
        'sync_status': SyncQueueStatus.pending.name,
      });

      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'entity_type': 'sale',
        'entity_id': id,
        'operation': 'create',
        'payload': jsonEncode(payload),
        'priority': 1,
        'status': SyncQueueStatus.pending.name,
        'attempts': 0,
        'created_at': now,
      });
    }));

    final registerId = payload['cash_register_id']?.toString() ?? '';
    final sessionId = payload['cash_session_id']?.toString() ?? '';
    if (registerId.isNotEmpty &&
        (config.cashRegisterId != registerId || config.cashSessionId != sessionId)) {
      await TerminalConfigRepository.instance.save(config.copyWith(
        cashRegisterId: registerId,
        cashSessionId: sessionId,
      ));
    }

    return PosSaleResult(
      saleId: id,
      reference: reference,
      total: total,
      paidAmount: paidAmount,
      outstandingAmount: outstandingAmount,
      paymentStatus: outstandingAmount > 0 ? 'partial' : 'paid',
      dueDate: dueDate,
      storedLocally: true,
      pendingSync: true,
    );
  }

  Future<Map<String, dynamic>> acceptRemoteOperation(Map<String, dynamic> operation) async {
    final entityType = operation['entity_type']?.toString() ?? '';
    final entityId = operation['entity_id']?.toString() ?? '';
    final op = operation['operation']?.toString() ?? '';
    final rawPayload = operation['payload'];
    final payload = rawPayload is Map ? Map<String, dynamic>.from(rawPayload) : <String, dynamic>{};
    if (entityId.isEmpty) {
      return {
        'id': operation['id'],
        'entity_id': entityId,
        'status': 'failed',
        'error': 'entity_id manquant',
      };
    }
    if (entityType == 'customer' && op == 'create') {
      return _acceptRemoteCustomer(operation['id']?.toString() ?? '', entityId, payload);
    }
    if (entityType == 'sale' && op == 'create') {
      return _acceptRemoteSale(operation['id']?.toString() ?? '', entityId, payload);
    }
    return {
      'id': operation['id'],
      'entity_id': entityId,
      'status': 'conflict',
      'error': 'Unsupported sync operation.',
    };
  }

  Future<bool> remoteOperationStored({
    required String entityType,
    required String entityId,
    String? serverId,
  }) async {
    if (entityType == 'customer') {
      if (await findCustomer(entityId) != null) return true;
      if (serverId != null && serverId.isNotEmpty && await findCustomer(serverId) != null) return true;
      return false;
    }
    final db = await _db;
    final rows = await db.query('sales', where: 'id = ?', whereArgs: [entityId], limit: 1);
    if (rows.isNotEmpty) return true;
    if (serverId == null || serverId.isEmpty) return false;
    final byServer = await db.query(
      'sales',
      where: 'id = ? OR server_id = ?',
      whereArgs: [serverId, serverId],
      limit: 1,
    );
    return byServer.isNotEmpty;
  }

  Future<Map<String, dynamic>> catalogDocument(String storeId) async {
    final catalog = await loadCatalog(storeId);
    final db = await _db;
    final seqRows = await db.rawQuery('SELECT MAX(sequence) AS seq FROM sync_events');
    return {
      'store_id': storeId,
      'server_sequence': syncAsInt(seqRows.first['seq']),
      'products': catalog?.products.map(_productToJson).toList() ?? [],
      'categories': catalog?.categories
              .map((category) => {
                    'id': category.id,
                    'name': category.name,
                    'parent_id': category.parentId,
                    'sort_order': category.sortOrder,
                  })
              .toList() ??
          [],
    };
  }

  Future<List<Map<String, dynamic>>> customerDocuments({int limit = 100}) async {
    final customers = await searchCustomers('', limit: limit);
    return customers.map((customer) => customer.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> paymentMethodDocuments() async {
    final methods = await loadPaymentMethods();
    return methods.map((method) => method.toJson()).toList();
  }

  Future<String> acceptRemoteHold(Map<String, dynamic> hold) async {
    final holds = await loadLocalHolds();
    final existingId = hold['id']?.toString();
    final id = existingId != null && existingId.isNotEmpty ? existingId : const Uuid().v4();
    final next = holds.where((item) => item['id']?.toString() != id).toList()
      ..add({
        ...hold,
        'id': id,
        'server_id': id,
      });
    await saveLocalHolds(next);
    return id;
  }

  Future<Map<String, dynamic>> _acceptRemoteSale(
    String queueId,
    String entityId,
    Map<String, dynamic> incoming,
  ) async {
    final db = await _db;
    final existing = await db.query('sales', where: 'id = ?', whereArgs: [entityId], limit: 1);
    if (existing.isNotEmpty) {
      return {
        'id': queueId,
        'entity_id': entityId,
        'status': 'synced',
        'server_id': entityId,
        'reference': existing.first['reference'],
      };
    }

    final config = TerminalConfigRepository.instance.config;
    final items = (incoming['items'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final payments = (incoming['payments'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (items.isEmpty) {
      return {
        'id': queueId,
        'entity_id': entityId,
        'status': 'failed',
        'error': 'At least one item is required.',
      };
    }

    final paidAmount = payments.fold<int>(0, (sum, payment) => sum + _asInt(payment['amount']));
    final total = items.fold<int>(0, (sum, item) {
      final price = _asInt(item['unit_price']);
      final qty = _asInt(item['quantity']);
      return sum + price * qty;
    });
    final method = payments.isEmpty ? 'cash' : payments.first['method']?.toString() ?? 'cash';
    final reference = incoming['client_reference']?.toString().isNotEmpty == true
        ? incoming['client_reference'].toString()
        : await _nextReference(db, incoming['device_id']?.toString() ?? config.deviceIdentifier);
    final now = incoming['sold_at']?.toString() ?? DateTime.now().toIso8601String();
    final payload = {
      ...incoming,
      'idempotency_key': incoming['idempotency_key'] ?? entityId,
      'client_reference': reference,
      'store_id': incoming['store_id'] ?? config.storeId,
    };

    final stock = <Map<String, dynamic>>[];
    Map<String, String> lane = {};
    try {
      await exclusiveStock(() => db.transaction((txn) async {
      lane = await _bindLane(txn, payload);
      await txn.insert('sales', {
        'id': entityId,
        'reference': reference,
        'store_id': payload['store_id'],
        'payload_json': jsonEncode(payload),
        'total': total,
        'paid_amount': paidAmount,
        'outstanding_amount': total > paidAmount ? total - paidAmount : 0,
        'method': method,
        'sync_status': SyncQueueStatus.pending.name,
        'device_id': payload['device_id'],
        'cash_register_id': payload['cash_register_id'],
        'cash_session_id': payload['cash_session_id'],
        'user_id': payload['user_id'],
        'created_at': now,
      });
      for (final payment in payments) {
        final amount = _asInt(payment['amount']);
        if (amount <= 0) continue;
        await txn.insert('payments', {
          'id': const Uuid().v4(),
          'sale_id': entityId,
          'method': payment['method']?.toString() ?? method,
          'amount': amount,
          'currency': payment['currency']?.toString() ?? 'BIF',
          'reference': payment['reference']?.toString(),
          'created_at': now,
        });
      }
      for (final item in items) {
        final productId = item['product_id']?.toString();
        final quantity = _asInt(item['quantity']);
        if (productId == null || productId.isEmpty || quantity <= 0) continue;
        await txn.insert('stock_movements', {
          'id': const Uuid().v4(),
          'sale_id': entityId,
          'product_id': productId,
          'quantity': -quantity,
          'type': 'SALE',
          'created_at': now,
        });
        stock.add(await _applyStockDelta(txn, productId, quantity, authoritative: true));
      }
      final eventId = const Uuid().v4();
      await txn.insert('sync_events', {
        'id': eventId,
        'store_id': payload['store_id']?.toString(),
        'device_id': payload['device_id']?.toString(),
        'sequence': await _nextSyncSequence(txn),
        'event_type': 'sale.completed',
        'entity_type': 'sale',
        'entity_id': entityId,
        'payload': jsonEncode({
          'reference': reference,
          'total': total,
          'paid_amount': paidAmount,
          'source': 'satellite',
          'device_id': payload['device_id'],
          'cash_register_id': payload['cash_register_id'],
          'cash_session_id': payload['cash_session_id'],
          'user_id': payload['user_id'],
          'stock': stock.where((line) => line.isNotEmpty).toList(),
        }),
        'occurred_at': now,
        'sync_status': SyncQueueStatus.pending.name,
      });
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'entity_type': 'sale',
        'entity_id': entityId,
        'operation': 'create',
        'payload': jsonEncode(payload),
        'priority': 1,
        'status': SyncQueueStatus.pending.name,
        'attempts': 0,
        'created_at': now,
      });
    }));
    } on StockConflict catch (error) {
      return {
        'id': queueId,
        'entity_id': entityId,
        'status': 'failed',
        'error': error.message,
      };
    }

    return {
      'id': queueId,
      'entity_id': entityId,
      'status': 'synced',
      'server_id': entityId,
      'reference': reference,
      'stock': stock.where((line) => line.isNotEmpty).toList(),
      ...lane,
    };
  }

  Future<Map<String, dynamic>> _acceptRemoteCustomer(
    String queueId,
    String entityId,
    Map<String, dynamic> incoming,
  ) async {
    final existing = await findCustomer(entityId);
    if (existing != null) {
      return {
        'id': queueId,
        'entity_id': entityId,
        'status': 'synced',
        'server_id': existing.serverId ?? entityId,
      };
    }
    final name = incoming['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      return {
        'id': queueId,
        'entity_id': entityId,
        'status': 'failed',
        'error': 'Customer name is required.',
      };
    }
    final now = DateTime.now().toIso8601String();
    final customer = PosCustomer(
      id: entityId,
      name: name,
      phone: incoming['phone']?.toString(),
      email: incoming['email']?.toString(),
      pending: true,
    );
    final payload = {
      ...incoming,
      'idempotency_key': incoming['idempotency_key'] ?? entityId,
      'client_id': entityId,
      'name': name,
    };
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('customers', {
        'id': entityId,
        'server_id': null,
        'name': name,
        'code': null,
        'email': customer.email,
        'phone': customer.phone,
        'json': jsonEncode(customer.toJson()),
        'sync_status': SyncQueueStatus.pending.name,
        'created_at': now,
      });
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'entity_type': 'customer',
        'entity_id': entityId,
        'operation': 'create',
        'payload': jsonEncode(payload),
        'priority': 0,
        'status': SyncQueueStatus.pending.name,
        'attempts': 0,
        'created_at': now,
      });
    });
    return {
      'id': queueId,
      'entity_id': entityId,
      'status': 'synced',
      'server_id': entityId,
    };
  }

  Future<void> releaseStuck() async {
    final db = await _db;
    await db.update(
      'sync_queue',
      {'status': SyncQueueStatus.pending.name},
      where: 'status = ?',
      whereArgs: [SyncQueueStatus.processing.name],
    );
  }

  Future<List<Map<String, dynamic>>> pendingQueue({int limit = 50}) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    return db.query(
      'sync_queue',
      where: "status IN ('pending', 'retrying', 'failed') AND (next_retry_at IS NULL OR next_retry_at <= ?)",
      whereArgs: [now],
      orderBy: 'priority ASC, created_at ASC',
      limit: limit,
    );
  }

  Future<void> markProcessing(String id) async {
    final db = await _db;
    await db.update(
      'sync_queue',
      {
        'status': SyncQueueStatus.processing.name,
        'last_attempt_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSynced(String queueId, String entityId, {String? serverId, String? serverReference}) async {
    final db = await _db;
    await db.transaction((txn) async {
      final queueRows = await txn.query('sync_queue', where: 'id = ?', whereArgs: [queueId], limit: 1);
      final entityType = queueRows.isEmpty ? 'sale' : queueRows.first['entity_type'] as String? ?? 'sale';
      await txn.update(
        'sync_queue',
        {
          'status': SyncQueueStatus.synced.name,
          'error_message': null,
        },
        where: 'id = ?',
        whereArgs: [idArg(queueId)],
      );
      if (entityType == 'customer') {
        await txn.update(
          'customers',
          {
            'sync_status': SyncQueueStatus.synced.name,
            if (serverId != null) 'server_id': serverId,
          },
          where: 'id = ?',
          whereArgs: [entityId],
        );
      } else {
        await txn.update(
          'sales',
          {
            'sync_status': SyncQueueStatus.synced.name,
            if (serverId != null) 'server_id': serverId,
          },
          where: 'id = ?',
          whereArgs: [entityId],
        );
        await txn.update(
          'sync_events',
          {'sync_status': SyncQueueStatus.synced.name},
          where: "entity_type = 'sale' AND entity_id = ?",
          whereArgs: [entityId],
        );
      }
    });
    if (serverId != null) {
      final queueRows = await db.query('sync_queue', where: 'id = ?', whereArgs: [queueId], limit: 1);
      final entityType = queueRows.isEmpty ? '' : queueRows.first['entity_type'] as String? ?? '';
      if (entityType == 'customer') {
        await applyCustomerServerId(entityId, serverId);
      }
    }
    await setCheckpoint('last_sync_at', DateTime.now().toIso8601String());
    await log('info', 'Synced $entityId${serverReference == null ? '' : ' as $serverReference'}');
  }

  String idArg(String id) => id;

  Future<void> markFailed(String queueId, String error, {required int attempts}) async {
    final db = await _db;
    final delay = Duration(seconds: _backoffSeconds(attempts));
    await db.update(
      'sync_queue',
      {
        'status': SyncQueueStatus.retrying.name,
        'attempts': attempts,
        'error_message': error,
        'last_attempt_at': DateTime.now().toIso8601String(),
        'next_retry_at': DateTime.now().add(delay).toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [queueId],
    );
    await log('error', error);
  }

  Future<void> retryNow(String queueId) async {
    final db = await _db;
    await db.update(
      'sync_queue',
      {
        'status': SyncQueueStatus.pending.name,
        'next_retry_at': null,
        'error_message': null,
      },
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  Future<String?> latestQueueError() async {
    final db = await _db;
    final rows = await db.query(
      'sync_queue',
      columns: ['error_message'],
      where: "status IN ('failed', 'retrying', 'conflict') AND error_message IS NOT NULL",
      orderBy: 'last_attempt_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['error_message'] as String?;
  }

  Future<void> retryAllFailed() async {
    final db = await _db;
    await db.update(
      'sync_queue',
      {
        'status': SyncQueueStatus.pending.name,
        'next_retry_at': null,
      },
      where: "status IN ('failed', 'retrying', 'conflict')",
    );
  }

  Future<Map<String, int>> counts() async {
    final db = await _db;
    Future<int> count(String status) async {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM sync_queue WHERE status = ?',
        [status],
      );
      return syncAsInt(rows.first['c']);
    }

    return {
      'pending': await count('pending') + await count('processing') + await count('retrying'),
      'failed': await count('failed'),
      'synced': await count('synced'),
      'conflicts': await count('conflict'),
    };
  }

  Future<List<Map<String, dynamic>>> listLocalSales({int limit = 80}) async {
    final db = await _db;
    return db.query('sales', orderBy: 'created_at DESC', limit: limit);
  }

  Future<List<Map<String, dynamic>>> queueDetails({int limit = 50}) async {
    final db = await _db;
    return db.query('sync_queue', orderBy: 'created_at DESC', limit: limit);
  }

  static const localHoldsKey = 'local_holds_v1';
  final ValueNotifier<int> holdsRevision = ValueNotifier(0);

  Future<void> saveLocalHolds(List<Map<String, dynamic>> holds) async {
    await setCheckpoint(localHoldsKey, jsonEncode(holds));
    holdsRevision.value++;
  }

  Future<List<Map<String, dynamic>>> loadLocalHolds() async {
    final raw = await checkpoint(localHoldsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, int>> localLedgerCounts() async {
    final db = await _db;
    Future<int> count(String table) async {
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
      return syncAsInt(rows.first['c']);
    }

    return {
      'sales': await count('sales'),
      'payments': await count('payments'),
      'stock_movements': await count('stock_movements'),
      'sync_events': await count('sync_events'),
    };
  }

  Future<Map<String, dynamic>?> latestSaleChain() async {
    final db = await _db;
    final sales = await db.query('sales', orderBy: 'created_at DESC', limit: 1);
    if (sales.isEmpty) return null;
    final sale = sales.first;
    final id = sale['id'] as String;
    Future<int> count(String sql) async {
      final rows = await db.rawQuery(sql, [id]);
      return syncAsInt(rows.first['c']);
    }

    return {
      'reference': sale['reference'],
      'sync_status': sale['sync_status'],
      'payments': await count('SELECT COUNT(*) AS c FROM payments WHERE sale_id = ?'),
      'movements': await count('SELECT COUNT(*) AS c FROM stock_movements WHERE sale_id = ?'),
      'events': await count(
        "SELECT COUNT(*) AS c FROM sync_events WHERE entity_type = 'sale' AND entity_id = ?",
      ),
    };
  }

  Future<void> setCheckpoint(String key, String value) async {
    final db = await _db;
    await db.insert(
      'checkpoints',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> checkpoint(String key) async {
    final db = await _db;
    final rows = await db.query('checkpoints', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> log(String level, String message) async {
    final db = await _db;
    await db.insert('sync_logs', {
      'level': level,
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  int _asInt(dynamic value) => syncAsInt(value);

  int? _asIntOrNull(dynamic value) => syncAsIntOrNull(value);

  Future<int> _nextSyncSequence(Transaction txn) async {
    final rows = await txn.rawQuery('SELECT MAX(sequence) AS seq FROM sync_events');
    return syncAsInt(rows.first['seq']) + 1;
  }

  Future<String> _nextReference(Database db, String deviceIdentifier) async {
    final day = DateTime.now();
    final stamp = '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
    final suffix = deviceIdentifier.replaceAll('-', '');
    final pos = suffix.isEmpty ? 'POS' : suffix.substring(0, suffix.length.clamp(0, 4)).toUpperCase();
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM sales');
    final seq = syncAsInt(rows.first['c']) + 1;
    return 'SALE-$pos-$stamp-${seq.toString().padLeft(6, '0')}';
  }

  Future<T> exclusiveStock<T>(Future<T> Function() action) {
    final previous = _stockChain;
    final gate = Completer<void>();
    _stockChain = gate.future;
    return previous.catchError((Object _) {}).then((_) => action()).whenComplete(gate.complete);
  }

  Future<List<Map<String, dynamic>>> applyProduction({
    required String productionId,
    required String finishedProductId,
    required int finishedQuantity,
    required List<Map<String, dynamic>> ingredients,
  }) async {
    if (finishedQuantity <= 0) throw Exception('Quantité de production invalide');
    if (ingredients.isEmpty) throw Exception('La recette n’a pas de matières premières');
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final stock = <Map<String, dynamic>>[];
    await exclusiveStock(() => db.transaction((txn) async {
      for (final line in ingredients) {
        final productId = line['product_id']?.toString() ?? '';
        final quantity = _asInt(line['quantity']);
        if (productId.isEmpty || quantity <= 0) continue;
        await txn.insert('stock_movements', {
          'id': const Uuid().v4(),
          'sale_id': productionId,
          'product_id': productId,
          'quantity': -quantity,
          'type': 'PRODUCTION_OUT',
          'created_at': now,
        });
        stock.add(await _adjustTrackedStock(txn, productId, -quantity));
      }
      await txn.insert('stock_movements', {
        'id': const Uuid().v4(),
        'sale_id': productionId,
        'product_id': finishedProductId,
        'quantity': finishedQuantity,
        'type': 'PRODUCTION_IN',
        'created_at': now,
      });
      stock.add(await _adjustTrackedStock(txn, finishedProductId, finishedQuantity));
      await txn.insert('sync_events', {
        'id': const Uuid().v4(),
        'store_id': TerminalConfigRepository.instance.config.storeId,
        'device_id': TerminalConfigRepository.instance.config.deviceId.isEmpty
            ? null
            : TerminalConfigRepository.instance.config.deviceId,
        'sequence': await _nextSyncSequence(txn),
        'event_type': 'production.completed',
        'entity_type': 'production',
        'entity_id': productionId,
        'payload': jsonEncode({
          'finished_product_id': finishedProductId,
          'finished_quantity': finishedQuantity,
          'ingredients': ingredients,
        }),
        'occurred_at': now,
        'sync_status': SyncQueueStatus.pending.name,
      });
    }));
    return stock.where((line) => line.isNotEmpty).toList();
  }

  Future<Map<String, dynamic>> _adjustTrackedStock(Transaction txn, String productId, int delta) async {
    final rows = await txn.query('products', where: 'product_id = ?', whereArgs: [productId], limit: 1);
    if (rows.isEmpty) throw StockConflict('Produit introuvable pour la production');
    final json = jsonDecode(rows.first['json'] as String) as Map<String, dynamic>;
    final current = _asInt(json['quantity_on_hand']);
    final next = current + delta;
    if (next < 0) {
      final name = json['name']?.toString() ?? 'Article';
      throw StockConflict('Stock insuffisant pour $name');
    }
    final version = _asInt(json['stock_version']) + 1;
    json['quantity_on_hand'] = next;
    json['stock_version'] = version;
    await txn.update(
      'products',
      {'json': jsonEncode(json)},
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    return {
      'product_id': productId,
      'quantity_on_hand': next,
      'stock_version': version,
    };
  }

  Future<void> applyAuthoritativeStock(List<dynamic> lines) async {
    if (lines.isEmpty) return;
    await exclusiveStock(() async {
      final db = await _db;
      await db.transaction((txn) async {
        for (final line in lines.whereType<Map>()) {
          final productId = line['product_id']?.toString() ?? '';
          final version = _asIntOrNull(line['stock_version']);
          final quantity = _asIntOrNull(line['quantity_on_hand']);
          if (productId.isEmpty || version == null || quantity == null) continue;
          final rows = await txn.query('products', where: 'product_id = ?', whereArgs: [productId], limit: 1);
          if (rows.isEmpty) continue;
          final json = jsonDecode(rows.first['json'] as String) as Map<String, dynamic>;
          final currentVersion = _asInt(json['stock_version']);
          if (version < currentVersion) continue;
          json['quantity_on_hand'] = quantity;
          json['stock_version'] = version;
          await txn.update(
            'products',
            {'json': jsonEncode(json)},
            where: 'product_id = ?',
            whereArgs: [productId],
          );
        }
      });
    });
  }

  Future<List<Map<String, dynamic>>> stockSnapshot() async {
    final db = await _db;
    final rows = await db.query('products');
    final lines = <Map<String, dynamic>>[];
    for (final row in rows) {
      final decoded = jsonDecode(row['json'] as String);
      if (decoded is! Map) continue;
      final quantity = _asIntOrNull(decoded['quantity_on_hand']);
      if (quantity == null) continue;
      lines.add({
        'product_id': row['product_id'],
        'quantity_on_hand': quantity,
        'stock_version': _asInt(decoded['stock_version']),
      });
    }
    return lines;
  }

  Future<Map<String, String>> _bindLane(Transaction txn, Map<String, dynamic> payload) async {
    final config = TerminalConfigRepository.instance.config;
    var deviceId = payload['device_id']?.toString() ?? '';
    if (deviceId.isEmpty) deviceId = config.deviceId;
    if (deviceId.isEmpty) deviceId = config.deviceIdentifier;
    if (deviceId.isEmpty) deviceId = 'lane-${const Uuid().v4()}';
    var registerId = payload['cash_register_id']?.toString() ?? '';
    var sessionId = payload['cash_session_id']?.toString() ?? '';
    var userId = payload['user_id']?.toString() ?? '';
    final rows = await txn.query('lane_sessions', where: 'device_id = ?', whereArgs: [deviceId], limit: 1);
    if (rows.isNotEmpty) {
      if (registerId.isEmpty) registerId = rows.first['cash_register_id']?.toString() ?? '';
      if (sessionId.isEmpty) sessionId = rows.first['cash_session_id']?.toString() ?? '';
      if (userId.isEmpty) userId = rows.first['user_id']?.toString() ?? '';
    }
    // Prefer the configured cloud register. Never invent placeholder ids like
    // "reg-<device>" — the API rejects unknown CashRegister keys.
    if (registerId.isEmpty || registerId.startsWith('reg-')) {
      registerId = config.cashRegisterId;
    }
    if (sessionId.isEmpty || sessionId.startsWith('ses-')) {
      sessionId = config.cashSessionId;
    }
    await txn.insert(
      'lane_sessions',
      {
        'device_id': deviceId,
        'cash_register_id': registerId.isEmpty ? null : registerId,
        'cash_session_id': sessionId.isEmpty ? null : sessionId,
        'user_id': userId.isEmpty ? null : userId,
        'opened_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    payload['device_id'] = deviceId;
    if (registerId.isNotEmpty) {
      payload['cash_register_id'] = registerId;
    } else {
      payload.remove('cash_register_id');
    }
    if (sessionId.isNotEmpty) {
      payload['cash_session_id'] = sessionId;
    } else {
      payload.remove('cash_session_id');
    }
    if (userId.isNotEmpty) payload['user_id'] = userId;
    return {
      'device_id': deviceId,
      if (registerId.isNotEmpty) 'cash_register_id': registerId,
      if (sessionId.isNotEmpty) 'cash_session_id': sessionId,
      if (userId.isNotEmpty) 'user_id': userId,
    };
  }

  Future<Map<String, dynamic>> _applyStockDelta(
    Transaction txn,
    String productId,
    int quantity, {
    required bool authoritative,
  }) async {
    final rows = await txn.query('products', where: 'product_id = ?', whereArgs: [productId], limit: 1);
    if (rows.isEmpty) return {};
    final json = jsonDecode(rows.first['json'] as String) as Map<String, dynamic>;
    final current = _asIntOrNull(json['quantity_on_hand']);
    if (current == null) return {};
    if (authoritative && current < quantity) {
      final name = json['name']?.toString() ?? 'Article';
      throw StockConflict('Stock insuffisant pour $name');
    }
    final next = current - quantity;
    final version = _asInt(json['stock_version']) + (authoritative ? 1 : 0);
    json['quantity_on_hand'] = next;
    json['stock_version'] = version;
    await txn.update(
      'products',
      {'json': jsonEncode(json)},
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    return {
      'product_id': productId,
      'quantity_on_hand': next,
      'stock_version': version,
    };
  }

  Map<String, dynamic> _productToJson(PosProduct product) {
    return {
      'store_product_id': product.storeProductId,
      'product_id': product.productId,
      'sku': product.sku,
      'name': product.name,
      'price': product.price,
      'category_id': product.categoryId,
      'barcode': product.barcode,
      'tax_rate': product.taxRate,
      'tax_inclusive': product.taxInclusive,
      'primary_image_cdn_url': product.primaryImageUrl,
      'is_available': product.isAvailable,
      if (product.quantityOnHand != null) 'quantity_on_hand': product.quantityOnHand,
      if (product.stockVersion > 0) 'stock_version': product.stockVersion,
      if (product.stockDisplay != null) 'stock_display': product.stockDisplay,
      if (product.bundleItems.isNotEmpty)
        'bundle_items': product.bundleItems.map((item) => item.toJson()).toList(),
      if (product.categoryName != null) 'category_name': product.categoryName,
      if (product.lowStockThreshold != null) 'low_stock_threshold': product.lowStockThreshold,
      if (product.costPrice > 0) 'cost_price': product.costPrice,
      if (product.trackExpiration) 'track_expiration': true,
      if (product.expiresAt != null) 'expires_at': product.expiresAt,
      'unit': product.unit,
      'product_type': product.productType,
      'variants': product.variants.map((variant) => variant.toJson()).toList(),
    };
  }

  int _backoffSeconds(int attempts) {
    final seconds = 2 << (attempts.clamp(1, 8) - 1);
    return seconds.clamp(2, 300);
  }
}
