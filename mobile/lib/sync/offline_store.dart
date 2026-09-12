import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../core/config/terminal_config_repository.dart';
import '../data/local/local_database.dart';
import '../features/pos/domain/pos_models.dart';
import 'sync_models.dart';

class OfflineStore {
  OfflineStore._();

  static final OfflineStore instance = OfflineStore._();

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

    await db.transaction((txn) async {
      await txn.delete('products', where: 'store_id = ?', whereArgs: [catalog.storeId]);
      await txn.delete('categories', where: 'store_id = ?', whereArgs: [catalog.storeId]);
      for (final product in products.values) {
        await txn.insert(
          'products',
          {
            'product_id': product.productId,
            'store_id': catalog.storeId,
            'sku': product.sku,
            'name': product.name,
            'price': product.price,
            'category_id': product.categoryId,
            'json': jsonEncode(_productToJson(product)),
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
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
      if (config.deviceId.isNotEmpty) 'device_id': config.deviceId,
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

    await db.transaction((txn) async {
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
        'created_at': now,
      });

      for (final item in items) {
        final productId = item['product_id'] as String?;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        if (productId == null || quantity <= 0) continue;
        await txn.insert('stock_movements', {
          'id': const Uuid().v4(),
          'sale_id': id,
          'product_id': productId,
          'quantity': -quantity,
          'type': 'SALE',
          'created_at': now,
        });
        await _decrementLocalStock(txn, productId, quantity);
      }

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
    });

    return PosSaleResult(
      saleId: id,
      reference: reference,
      total: total,
      paidAmount: paidAmount,
      outstandingAmount: outstandingAmount,
      paymentStatus: outstandingAmount > 0 ? 'partial' : 'paid',
      dueDate: dueDate,
    );
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

  Future<List<Map<String, dynamic>>> pendingQueue({int limit = 25}) async {
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
      return (rows.first['c'] as int?) ?? 0;
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

  Future<String> _nextReference(Database db, String deviceIdentifier) async {
    final day = DateTime.now();
    final stamp = '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
    final suffix = deviceIdentifier.replaceAll('-', '');
    final pos = suffix.isEmpty ? 'POS' : suffix.substring(0, suffix.length.clamp(0, 4)).toUpperCase();
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM sales');
    final seq = ((rows.first['c'] as int?) ?? 0) + 1;
    return 'SALE-$pos-$stamp-${seq.toString().padLeft(6, '0')}';
  }

  Future<void> _decrementLocalStock(Transaction txn, String productId, int quantity) async {
    final rows = await txn.query('products', where: 'product_id = ?', whereArgs: [productId], limit: 1);
    if (rows.isEmpty) return;
    final json = jsonDecode(rows.first['json'] as String) as Map<String, dynamic>;
    final current = (json['quantity_on_hand'] as num?)?.toInt();
    if (current == null) return;
    json['quantity_on_hand'] = current - quantity;
    await txn.update(
      'products',
      {'json': jsonEncode(json)},
      where: 'product_id = ?',
      whereArgs: [productId],
    );
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
