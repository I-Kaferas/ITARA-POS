import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/config/terminal_config.dart';
import '../../core/config/terminal_config_repository.dart';
import '../../core/network/operating_mode.dart';
import '../../core/network/operation_router.dart';
import '../../data/local/local_database.dart';
import '../../features/auth/data/pin_auth_service.dart';
import '../../features/pos/domain/pos_models.dart';
import '../master_config_store.dart';
import '../offline_store.dart';
import '../outbox/sync_outbox.dart';
import '../sync_numbers.dart';
import 'cloud_sync_entity.dart';
import 'cloud_sync_report.dart';

/// Master → ITARA ERP Cloud sync (mobile.md §35).
///
/// Slave terminals must never call this — they sync via the Master only.
class CloudSyncEngine extends ChangeNotifier {
  CloudSyncEngine({http.Client? client}) : _client = client ?? http.Client();

  static final CloudSyncEngine instance = CloudSyncEngine();

  final http.Client _client;

  bool _running = false;
  bool cloudReachable = false;
  DateTime? lastSyncAt;
  String? lastError;
  CloudSyncReport lastReport = const CloudSyncReport();

  bool get isRunning => _running;

  bool get isAllowed {
    final config = TerminalConfigRepository.instance.config;
    return config.posRole == PosRole.master ||
        config.posRole == PosRole.standalone;
  }

  String get _cloudBase {
    final value = TerminalConfigRepository.instance.config.apiBaseUrl.trim();
    return value.replaceAll(RegExp(r'/$'), '');
  }

  Map<String, String> get _headers {
    final config = TerminalConfigRepository.instance.config;
    var token = config.authToken.trim();
    if (token.toLowerCase().startsWith('bearer ')) {
      token = token.substring(7).trim();
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (config.tenantId.isNotEmpty) 'X-Tenant-ID': config.tenantId,
      if (config.storeId.isNotEmpty) 'X-Store-ID': config.storeId,
      if (config.deviceId.isNotEmpty) 'X-Device-ID': config.deviceId,
      if (config.deviceName.isNotEmpty) 'X-Device-Name': config.deviceName,
    };
  }

  /// Full Master → Cloud cycle: harvest → push → pull.
  Future<CloudSyncReport> syncNow({bool pull = true, bool push = true}) async {
    if (_running) {
      return lastReport = const CloudSyncReport(
        ok: false,
        message: 'Synchronisation cloud déjà en cours',
      );
    }
    if (!isAllowed) {
      return lastReport = const CloudSyncReport(
        ok: false,
        message: 'Seul le Master (ou autonome) synchronise vers le Cloud',
      );
    }

    _running = true;
    notifyListeners();

    final pushed = <CloudSyncEntity, int>{};
    final pulled = <CloudSyncEntity, int>{};
    var failed = 0;

    try {
      cloudReachable = await probe();
      if (!cloudReachable) {
        lastError = 'ITARA ERP Cloud indisponible';
        return lastReport = CloudSyncReport(
          ok: false,
          message: lastError!,
          cloudReachable: false,
        );
      }

      final mode = OperatingModeResolver.resolve(
        role: TerminalConfigRepository.instance.config.posRole,
        masterReachable: true,
        cloudReachable: true,
      );
      final router = OperationRouter(
        mode: mode,
        role: TerminalConfigRepository.instance.config.posRole,
      );
      if (!router.allowsDirectCloud) {
        lastError = 'Mode réseau n’autorise pas le Cloud';
        return lastReport = CloudSyncReport(
          ok: false,
          message: lastError!,
          cloudReachable: true,
        );
      }

      await PinAuthService.refreshIfNeeded();
      await harvestOutbound();

      if (push) {
        final pushResult = await _drainOutbound();
        pushed.addAll(pushResult.counts);
        failed += pushResult.failed;
      }

      if (pull) {
        final pullResult = await _pullInbound();
        pulled.addAll(pullResult);
      }

      await _heartbeat();

      lastSyncAt = DateTime.now();
      lastError = failed > 0 ? '$failed opération(s) en échec' : null;
      final message = failed > 0
          ? 'Cloud sync partiel · $failed échec(s)'
          : 'Master → Cloud synchronisé';
      return lastReport = CloudSyncReport(
        ok: failed == 0,
        message: message,
        pushed: Map.unmodifiable(pushed),
        pulled: Map.unmodifiable(pulled),
        failed: failed,
        cloudReachable: true,
      );
    } catch (error) {
      lastError = error.toString().replaceFirst('Exception: ', '');
      return lastReport = CloudSyncReport(
        ok: false,
        message: lastError!,
        pushed: pushed,
        pulled: pulled,
        failed: failed + 1,
        cloudReachable: cloudReachable,
      );
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<bool> probe() async {
    final base = _cloudBase;
    if (base.isEmpty) {
      cloudReachable = false;
      return false;
    }
    try {
      final root = base.replaceFirst(RegExp(r'/api/v1$'), '');
      final response = await _client
          .get(Uri.parse('$root/api/v1/health'))
          .timeout(const Duration(seconds: 3));
      cloudReachable = response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      cloudReachable = false;
    }
    return cloudReachable;
  }

  /// Enqueue local expenses / orders / audit logs / stock movements not yet in outbox.
  Future<int> harvestOutbound() async {
    var added = 0;
    added += await _harvestExpenses();
    added += await _harvestOrders();
    added += await _harvestAuditLogs();
    added += await _harvestStockMovements();
    added += await _harvestPayments();
    return added;
  }

  Future<int> _harvestExpenses() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query('expenses', orderBy: 'created_at ASC', limit: 100);
    var added = 0;
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      if (await _alreadyQueuedOrSynced('expense', id)) continue;
      Map<String, dynamic> json = {};
      try {
        final decoded = jsonDecode(row['json']?.toString() ?? '{}');
        if (decoded is Map) json = Map<String, dynamic>.from(decoded);
      } catch (_) {}
      await SyncOutbox.instance.enqueue(
        entity: CloudSyncEntity.expenses.wire,
        entityId: id,
        operation: 'create',
        payload: {
          'idempotency_key': id,
          'description': row['description'] ?? json['description'] ?? '',
          'amount': row['amount'] ?? json['amount'] ?? 0,
          'category': row['category'] ?? json['category'] ?? 'other',
          'cash_session_id': row['cash_session_id'] ?? json['cash_session_id'],
          'user_id': row['user_id'] ?? json['user_id'],
          'branch': row['branch'] ?? json['branch'],
          'notes': json['notes'],
          'currency_code': json['currency_code'] ??
              TerminalConfigRepository.instance.config.currencyCode,
          'occurred_on': (row['created_at']?.toString() ?? '').split('T').first,
          'store_id': TerminalConfigRepository.instance.config.storeId,
        },
      );
      added++;
    }
    return added;
  }

  Future<int> _harvestOrders() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'restaurant_orders',
      where: "status != ?",
      whereArgs: const ['synced'],
      orderBy: 'updated_at ASC',
      limit: 80,
    );
    var added = 0;
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      if (await _alreadyQueuedOrSynced('order', id)) continue;
      Map<String, dynamic> json = {};
      try {
        final decoded = jsonDecode(row['json']?.toString() ?? '{}');
        if (decoded is Map) json = Map<String, dynamic>.from(decoded);
      } catch (_) {}
      await SyncOutbox.instance.enqueue(
        entity: CloudSyncEntity.orders.wire,
        entityId: id,
        operation: 'upsert',
        payload: {
          'idempotency_key': id,
          'table_id': row['table_id'],
          'store_id': row['store_id'] ??
              TerminalConfigRepository.instance.config.storeId,
          'status': row['status'] ?? 'open',
          ...json,
        },
      );
      added++;
    }
    return added;
  }

  Future<int> _harvestAuditLogs() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query('audit_logs', orderBy: 'created_at DESC', limit: 80);
    var added = 0;
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      if (await _alreadyQueuedOrSynced('audit_log', id)) continue;
      Map<String, dynamic> meta = {};
      try {
        final decoded = jsonDecode(row['json']?.toString() ?? '{}');
        if (decoded is Map) meta = Map<String, dynamic>.from(decoded);
      } catch (_) {}
      await SyncOutbox.instance.enqueue(
        entity: CloudSyncEntity.auditLogs.wire,
        entityId: id,
        operation: 'create',
        payload: {
          'idempotency_key': id,
          'action': row['action'] ?? meta['action'] ?? 'unknown',
          'actor_id': row['actor_id'] ?? meta['actor_id'],
          'entity_type': row['entity_type'] ?? meta['entity_type'],
          'entity_id': row['entity_id'] ?? meta['entity_id'],
          'payload': meta,
          'occurred_at': row['created_at'],
        },
      );
      added++;
    }
    return added;
  }

  Future<int> _harvestStockMovements() async {
    final db = await LocalDatabase.instance.database;
    // Non-sale adjustments (type != SALE) are pushed explicitly; sale stock
    // travels with the sale payload to the Cloud.
    final rows = await db.query(
      'stock_movements',
      where: "UPPER(type) != ?",
      whereArgs: const ['SALE'],
      orderBy: 'created_at ASC',
      limit: 120,
    );
    var added = 0;
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      if (await _alreadyQueuedOrSynced('stock', id)) continue;
      await SyncOutbox.instance.enqueue(
        entity: CloudSyncEntity.stocks.wire,
        entityId: id,
        operation: 'create',
        payload: {
          'idempotency_key': id,
          'product_id': row['product_id'],
          'quantity': row['quantity'],
          'type': row['type'] ?? 'ADJUSTMENT',
          'sale_id': row['sale_id'],
          'store_id': TerminalConfigRepository.instance.config.storeId,
          'occurred_at': row['created_at'],
        },
      );
      added++;
    }
    return added;
  }

  Future<int> _harvestPayments() async {
    final db = await LocalDatabase.instance.database;
    // Payments belonging to sales still pending cloud sync (informative outbox).
    final rows = await db.rawQuery('''
      SELECT p.* FROM payments p
      INNER JOIN sales s ON s.id = p.sale_id
      WHERE s.sync_status = 'pending'
      LIMIT 80
    ''');
    var added = 0;
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      if (await _alreadyQueuedOrSynced('payment', id)) continue;
      await SyncOutbox.instance.enqueue(
        entity: CloudSyncEntity.payments.wire,
        entityId: id,
        operation: 'create',
        payload: {
          'idempotency_key': id,
          'sale_id': row['sale_id'],
          'method': row['method'],
          'amount': row['amount'],
          'currency_code': row['currency'] ??
              TerminalConfigRepository.instance.config.currencyCode,
          'reference': row['reference'],
        },
      );
      added++;
    }
    return added;
  }

  Future<bool> _alreadyQueuedOrSynced(String entity, String entityId) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      SyncOutbox.table,
      where: 'entity = ? AND entity_id = ?',
      whereArgs: [entity, entityId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<({Map<CloudSyncEntity, int> counts, int failed})> _drainOutbound() async {
    final counts = <CloudSyncEntity, int>{};
    var failed = 0;
    await OfflineStore.instance.releaseStuck();
    await OfflineStore.instance.retryAllFailed();

    for (var pass = 0; pass < 40; pass++) {
      final batch = await _pushBatch();
      if (batch.sent == 0) break;
      for (final entry in batch.byEntity.entries) {
        counts[entry.key] = (counts[entry.key] ?? 0) + entry.value;
      }
      failed += batch.failed;
      if (batch.stopped) break;
    }
    return (counts: counts, failed: failed);
  }

  Future<
      ({
        int sent,
        int failed,
        bool stopped,
        Map<CloudSyncEntity, int> byEntity,
      })> _pushBatch() async {
    final rows = await OfflineStore.instance.pendingQueue(limit: 50);
    if (rows.isEmpty) {
      return (sent: 0, failed: 0, stopped: false, byEntity: <CloudSyncEntity, int>{});
    }

    final operations = <Map<String, dynamic>>[];
    final accepted = <Map<String, dynamic>>[];
    final byEntity = <CloudSyncEntity, int>{};

    for (final row in rows) {
      if (accepted.length >= 50) break;
      final entityType = row['entity_type']?.toString() ?? row['entity']?.toString() ?? '';
      final entity = CloudSyncEntity.tryParse(entityType);
      // Always allow sale/customer even if alias missing.
      if (entity != null && !entity.canPush && entity != CloudSyncEntity.sales) {
        continue;
      }

      var payload = <String, dynamic>{};
      try {
        final decoded = jsonDecode(row['payload'] as String? ?? '{}');
        if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
      } catch (_) {}

      if (entityType == 'sale') {
        final prepared = await OfflineStore.instance.prepareSalePayload(payload);
        if (prepared == null) continue;
        payload = prepared;
      }

      await OfflineStore.instance.markProcessing(row['id'] as String);
      accepted.add(row);
      operations.add({
        'id': row['id'],
        'entity_type': entity?.wire ?? entityType,
        'entity_id': row['entity_id'],
        'operation': row['operation'],
        'payload': payload,
      });
      final key = entity ?? CloudSyncEntity.tryParse(entityType) ?? CloudSyncEntity.sales;
      byEntity[key] = (byEntity[key] ?? 0) + 1;
    }

    if (operations.isEmpty) {
      return (sent: 0, failed: 0, stopped: false, byEntity: byEntity);
    }

    // Attach configuration snapshot as a dedicated op when harvesting config changes.
    final response = await _authorized(
      () => _client
          .post(
            Uri.parse('$_cloudBase/sync/push'),
            headers: _headers,
            body: jsonEncode({'operations': operations}),
          )
          .timeout(const Duration(seconds: 40)),
    );

    if (response.statusCode != 200) {
      final message = response.statusCode == 401
          ? 'Session expirée. Reconnectez-vous.'
          : 'Cloud push refusé (HTTP ${response.statusCode})';
      for (final row in accepted) {
        await OfflineStore.instance.markFailed(
          row['id'] as String,
          message,
          attempts: syncAsInt(row['attempts']) + 1,
        );
      }
      return (
        sent: accepted.length,
        failed: accepted.length,
        stopped: true,
        byEntity: byEntity,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;
    final results = data['results'] as List<dynamic>? ?? [];
    final acceptedById = {
      for (final row in accepted) row['id'] as String: row,
    };
    final readyForAck = <Map<String, dynamic>>[];
    var failed = 0;

    for (final result in results) {
      if (result is! Map) continue;
      final item = Map<String, dynamic>.from(result);
      final queueId = item['id']?.toString() ?? '';
      if (queueId.isEmpty) continue;
      final row = acceptedById[queueId];
      final status = item['status']?.toString() ?? 'failed';
      if (status == 'synced') {
        readyForAck.add({
          'id': queueId,
          'entity_id': item['entity_id']?.toString() ?? row?['entity_id'],
          'entity_type': row?['entity_type'] ?? row?['entity'] ?? 'sale',
          'server_id': item['server_id']?.toString(),
          'attempts': syncAsInt(row?['attempts']),
        });
      } else {
        failed++;
        await OfflineStore.instance.markFailed(
          queueId,
          item['error']?.toString() ?? 'Cloud a rejeté l’opération',
          attempts: syncAsInt(row?['attempts']) + 1,
        );
      }
    }

    if (readyForAck.isNotEmpty) {
      final ackIds = await _acknowledge(readyForAck);
      for (final item in readyForAck) {
        final queueId = item['id'] as String;
        if (!ackIds.contains(queueId)) {
          failed++;
          await OfflineStore.instance.markFailed(
            queueId,
            'ACK cloud manquant',
            attempts: syncAsInt(item['attempts']) + 1,
          );
          continue;
        }
        await OfflineStore.instance.markSynced(
          queueId,
          item['entity_id'] as String,
          serverId: (item['server_id'] as String?)?.isEmpty == true
              ? null
              : item['server_id'] as String?,
        );
      }
    }

    return (
      sent: operations.length,
      failed: failed,
      stopped: false,
      byEntity: byEntity,
    );
  }

  Future<Set<String>> _acknowledge(List<Map<String, dynamic>> operations) async {
    final response = await _authorized(
      () => _client
          .post(
            Uri.parse('$_cloudBase/sync/ack'),
            headers: _headers,
            body: jsonEncode({
              'operations': operations
                  .map((item) => {
                        'id': item['id'],
                        'entity_type': item['entity_type'],
                        'entity_id': item['entity_id'],
                        if ((item['server_id']?.toString() ?? '').isNotEmpty)
                          'server_id': item['server_id'],
                      })
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 20)),
    );
    if (response.statusCode != 200) return {};
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;
    final ids = data['acknowledged_ids'] as List<dynamic>? ?? [];
    return ids.map((id) => id.toString()).where((id) => id.isNotEmpty).toSet();
  }

  Future<Map<CloudSyncEntity, int>> _pullInbound() async {
    final counts = <CloudSyncEntity, int>{};
    counts[CloudSyncEntity.products] = await _pullCatalog();
    counts[CloudSyncEntity.customers] = await _pullCustomers();
    final refs = await _pullReferences();
    counts[CloudSyncEntity.users] = refs.users;
    counts[CloudSyncEntity.configuration] = await _pullConfiguration();
    counts[CloudSyncEntity.stocks] = await _pullStockSnapshot();
    return counts;
  }

  Future<int> _pullCatalog() async {
    final since =
        await OfflineStore.instance.checkpoint('cloud_last_server_sequence') ??
            '0';
    final uri = Uri.parse('$_cloudBase/sync/pull')
        .replace(queryParameters: {'since': since});
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) return 0;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;
    final catalog = PosCatalog.fromJson(data);
    if (catalog.products.isNotEmpty || catalog.categories.isNotEmpty) {
      await OfflineStore.instance.mergeCatalog(catalog);
    }
    final sequence = data['server_sequence']?.toString();
    if (sequence != null) {
      await OfflineStore.instance
          .setCheckpoint('cloud_last_server_sequence', sequence);
    }
    await OfflineStore.instance.setCheckpoint(
      'cloud_catalog_synced_at',
      DateTime.now().toIso8601String(),
    );
    return catalog.products.length;
  }

  Future<int> _pullCustomers() async {
    final customers = <PosCustomer>[];
    var page = 1;
    var lastPage = 1;
    do {
      final uri = Uri.parse('$_cloudBase/customers').replace(queryParameters: {
        'active_only': '1',
        'per_page': '100',
        'page': '$page',
      });
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) break;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = body['data'];
      final List<dynamic> data;
      if (raw is List) {
        data = raw;
        lastPage = page;
      } else {
        final pageBody = raw is Map<String, dynamic> ? raw : body;
        data = pageBody['data'] as List<dynamic>? ??
            pageBody['items'] as List<dynamic>? ??
            [];
        lastPage = syncAsInt(pageBody['last_page'], page);
      }
      customers.addAll(
        data
            .whereType<Map>()
            .map((item) => PosCustomer.fromJson(Map<String, dynamic>.from(item))),
      );
      page++;
    } while (page <= lastPage && page <= 20);

    if (customers.isNotEmpty) {
      await OfflineStore.instance.cacheCustomers(customers);
    }
    return customers.length;
  }

  Future<({int users, int paymentMethods})> _pullReferences() async {
    final response = await _client
        .get(Uri.parse('$_cloudBase/sync/references'), headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      return (users: 0, paymentMethods: 0);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;
    await OfflineStore.instance.cacheReferenceBundle(data);
    return (
      users: (data['users'] as List?)?.length ?? 0,
      paymentMethods: (data['payment_methods'] as List?)?.length ?? 0,
    );
  }

  Future<int> _pullConfiguration() async {
    try {
      final response = await _client
          .get(Uri.parse('$_cloudBase/sync/status'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return 0;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : body;
      await MasterConfigStore.instance.save({
        'cloud_status': data,
        'cloud_synced_at': DateTime.now().toIso8601String(),
      });
      // Push local Master config snapshot as outbound configuration entity.
      final local = await MasterConfigStore.instance.document();
      if (local.isNotEmpty) {
        final id = 'config-${TerminalConfigRepository.instance.config.deviceId}';
        if (!await _alreadyQueuedOrSynced('configuration', id)) {
          await SyncOutbox.instance.enqueue(
            entity: CloudSyncEntity.configuration.wire,
            entityId: id,
            operation: 'upsert',
            payload: {
              'idempotency_key': id,
              'device_id': TerminalConfigRepository.instance.config.deviceId,
              'config': local,
            },
            id: const Uuid().v4(),
          );
        }
      }
      return 1;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _pullStockSnapshot() async {
    // Stock levels arrive via catalog pull / sale ACK; status endpoint may expose counts.
    return 0;
  }

  Future<void> _heartbeat() async {
    final config = TerminalConfigRepository.instance.config;
    final pending = (await OfflineStore.instance.counts())['pending'] ?? 0;
    await _client
        .post(
          Uri.parse('$_cloudBase/sync/heartbeat'),
          headers: _headers,
          body: jsonEncode({
            'device_id':
                config.deviceId.isNotEmpty ? config.deviceId : config.deviceIdentifier,
            'identifier': config.deviceIdentifier,
            'name': config.deviceName,
            'app_version': AppConfig.appVersion,
            'pending': pending,
            'role': config.posRole.name,
          }),
        )
        .timeout(const Duration(seconds: 8));
  }

  Future<http.Response> _authorized(
    Future<http.Response> Function() send,
  ) async {
    await PinAuthService.refreshIfNeeded();
    var response = await send();
    if (response.statusCode != 401) return response;
    final refreshed = await PinAuthService.refreshIfNeeded(force: true);
    if (!refreshed) return response;
    return send();
  }
}
