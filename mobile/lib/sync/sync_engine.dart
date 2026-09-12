import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config/terminal_config_repository.dart';
import '../features/auth/data/pin_auth_service.dart';
import '../features/pos/data/pos_api_service.dart';
import '../features/pos/domain/pos_models.dart';
import 'offline_store.dart';
import 'sync_models.dart';

class SyncEngine extends ChangeNotifier {
  SyncEngine._();

  static final SyncEngine instance = SyncEngine._();

  final _client = http.Client();
  Timer? _timer;
  bool _running = false;

  ConnectivityState connectivity = ConnectivityState.offline;
  String? lastError;
  DateTime? lastSyncAt;
  String? activeTarget;
  int pending = 0;
  int failed = 0;
  int synced = 0;
  int conflicts = 0;

  SyncSnapshot get snapshot => SyncSnapshot(
        connectivity: connectivity,
        pending: pending,
        failed: failed,
        synced: synced,
        conflicts: conflicts,
        lastSyncAt: lastSyncAt,
        lastError: lastError,
        target: activeTarget,
      );

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 20), (_) => runCycle());
    unawaited(OfflineStore.instance.releaseStuck());
    unawaited(refreshCounts());
    unawaited(runCycle());
  }

  void disposeEngine() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refreshCounts() async {
    final counts = await OfflineStore.instance.counts();
    pending = counts['pending'] ?? 0;
    failed = counts['failed'] ?? 0;
    synced = counts['synced'] ?? 0;
    conflicts = counts['conflicts'] ?? 0;
    notifyListeners();
  }

  Future<void> syncNow() => runCycle(forcePull: true, pushOutbound: true);

  Future<String> downloadStock() async {
    if (_running) return 'Synchronisation déjà en cours';
    _running = true;
    connectivity = ConnectivityState.syncing;
    notifyListeners();
    try {
      await _probe();
      if (activeTarget == null) {
        lastError = 'Serveur indisponible';
        connectivity = ConnectivityState.offline;
        return lastError!;
      }
      await refreshCatalogNow();
      await _pullReferenceData();
      lastSyncAt = DateTime.now();
      lastError = null;
      connectivity = ConnectivityState.online;
      return 'Stock, clients et paiements téléchargés';
    } catch (error) {
      lastError = error.toString();
      connectivity = ConnectivityState.syncError;
      return lastError!;
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<String> syncStock() async {
    if (_running) return 'Synchronisation déjà en cours';
    _running = true;
    connectivity = ConnectivityState.syncing;
    notifyListeners();
    try {
      await _probe();
      if (activeTarget == null) {
        lastError = 'Serveur indisponible';
        connectivity = ConnectivityState.offline;
        return lastError!;
      }
      await _pushPending();
      await refreshCatalogNow();
      await _pullReferenceData();
      lastSyncAt = DateTime.now();
      lastError = null;
      connectivity = ConnectivityState.online;
      await refreshCounts();
      return pending == 0 ? 'Stock envoyé et téléchargé' : 'Stock téléchargé · $pending en attente';
    } catch (error) {
      lastError = error.toString();
      connectivity = ConnectivityState.syncError;
      return lastError!;
    } finally {
      _running = false;
      await refreshCounts();
    }
  }

  Future<String> sendStock() async {
    if (_running) return 'Synchronisation déjà en cours';
    _running = true;
    connectivity = ConnectivityState.syncing;
    notifyListeners();
    try {
      await _probe();
      if (activeTarget == null) {
        lastError = 'Serveur indisponible. Vérifiez l’URL API et la connexion.';
        connectivity = ConnectivityState.offline;
        return lastError!;
      }
      await _prepareAuth();
      await OfflineStore.instance.releaseStuck();
      await OfflineStore.instance.retryAllFailed();

      var sent = 0;
      for (var pass = 0; pass < 4; pass++) {
        final pushed = await _pushPending();
        sent += pushed;
        if (pushed == 0) break;
      }

      await _pushLocalHolds();
      await refreshCounts();
      final error = await OfflineStore.instance.latestQueueError();
      if (error != null && pending > 0) {
        lastError = error;
        connectivity = ConnectivityState.syncError;
        return error;
      }

      lastSyncAt = DateTime.now();
      lastError = null;
      connectivity = ConnectivityState.online;
      if (pending == 0) {
        return sent == 0 ? 'Rien à envoyer' : 'Ventes et stock envoyés';
      }
      return 'Envoi partiel · $pending en attente';
    } catch (error) {
      lastError = error.toString().replaceFirst('Exception: ', '');
      connectivity = ConnectivityState.syncError;
      return lastError!;
    } finally {
      _running = false;
      await refreshCounts();
    }
  }

  Future<void> runCycle({bool forcePull = false, bool pushOutbound = false}) async {
    if (_running) return;
    _running = true;
    connectivity = ConnectivityState.syncing;
    notifyListeners();

    try {
      await _probe();
      if (activeTarget == null) {
        connectivity = ConnectivityState.offline;
        lastError = null;
        return;
      }

      try {
        await _heartbeat();
      } catch (_) {}
      if (forcePull || await _shouldPull()) {
        await _pullCatalog();
      }
      if (forcePull || await _shouldPullReference()) {
        await _pullReferenceData();
      }
      if (pushOutbound) {
        await _pushPending();
        await _pushLocalHolds();
      }
      lastSyncAt = DateTime.now();
      lastError = null;
      connectivity = activeTarget == _internalBase
          ? ConnectivityState.localAvailable
          : ConnectivityState.online;
    } catch (error) {
      lastError = error.toString();
      connectivity = ConnectivityState.syncError;
      await OfflineStore.instance.log('error', lastError!);
    } finally {
      _running = false;
      await refreshCounts();
    }
  }

  String? get _internalBase {
    final value = TerminalConfigRepository.instance.config.internalApiBaseUrl.trim();
    return value.isEmpty ? null : value.replaceAll(RegExp(r'/$'), '');
  }

  String get _cloudBase {
    final value = TerminalConfigRepository.instance.config.apiBaseUrl.trim();
    return value.replaceAll(RegExp(r'/$'), '');
  }

  Future<void> _probe() async {
    final internal = _internalBase;
    if (internal != null && await _healthy(internal)) {
      activeTarget = internal;
      return;
    }
    if (await _healthy(_cloudBase)) {
      activeTarget = _cloudBase;
      return;
    }
    activeTarget = null;
  }

  Future<bool> _healthy(String base) async {
    try {
      final root = base.replaceFirst(RegExp(r'/api/v1$'), '');
      final response = await _client
          .get(Uri.parse('$root/api/v1/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    }
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
    };
  }

  Future<void> _prepareAuth() async {
    await PinAuthService.refreshIfNeeded();
  }

  Future<http.Response> _authorized(
    Future<http.Response> Function() send,
  ) async {
    await _prepareAuth();
    var response = await send();
    if (response.statusCode != 401) return response;

    final refreshed = await PinAuthService.refreshIfNeeded(force: true);
    if (!refreshed) return response;
    response = await send();
    return response;
  }

  String _authFailureMessage(http.Response response) {
    if (response.statusCode == 401) {
      return 'Session expirée. Déconnectez-vous puis reconnectez-vous avec le PIN.';
    }
    return 'Envoi refusé par le serveur (HTTP ${response.statusCode})';
  }

  Future<bool> _shouldPullReference() async {
    final last = await OfflineStore.instance.checkpoint('customers_synced_at');
    if (last == null) return true;
    final parsed = DateTime.tryParse(last);
    if (parsed == null) return true;
    return DateTime.now().difference(parsed) > const Duration(minutes: 5);
  }

  Future<bool> _shouldPull() async {
    final last = await OfflineStore.instance.checkpoint('catalog_synced_at');
    if (last == null) return true;
    final parsed = DateTime.tryParse(last);
    if (parsed == null) return true;
    return DateTime.now().difference(parsed) > const Duration(minutes: 5);
  }

  Future<void> _pullCatalog() async {
    final target = activeTarget;
    final storeId = TerminalConfigRepository.instance.config.storeId;
    if (target == null || storeId.isEmpty) return;

    final since = await OfflineStore.instance.checkpoint('last_server_sequence') ?? '0';
    final uri = Uri.parse('$target/sync/pull').replace(queryParameters: {'since': since});
    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Pull catalog failed: HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;
    final catalog = PosCatalog.fromJson(data);
    if (catalog.products.isNotEmpty || catalog.categories.isNotEmpty) {
      await OfflineStore.instance.cacheCatalog(catalog);
    }
    final sequence = data['server_sequence']?.toString();
    if (sequence != null) {
      await OfflineStore.instance.setCheckpoint('last_server_sequence', sequence);
    }
  }

  Future<void> _pullReferenceData() async {
    final target = activeTarget;
    if (target == null) return;
    await _pullCustomers(target);
    await _pullPaymentMethods(target);
  }

  Future<void> _pullCustomers(String target) async {
    final customers = <PosCustomer>[];
    var page = 1;
    var lastPage = 1;
    do {
      final uri = Uri.parse('$target/customers').replace(queryParameters: {
        'active_only': '1',
        'per_page': '100',
        'page': '$page',
      });
      final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('Pull customers failed: HTTP ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = body['data'];
      final Map<String, dynamic> pageBody;
      final List<dynamic> data;
      if (raw is List) {
        pageBody = body;
        data = raw;
        lastPage = page;
      } else {
        pageBody = raw is Map<String, dynamic> ? raw : body;
        data = pageBody['data'] as List<dynamic>? ?? pageBody['items'] as List<dynamic>? ?? [];
        lastPage = (pageBody['last_page'] as num?)?.toInt() ?? page;
      }
      customers.addAll(
        data.whereType<Map>().map((item) => PosCustomer.fromJson(Map<String, dynamic>.from(item))),
      );
      lastPage = (pageBody['last_page'] as num?)?.toInt() ?? page;
      page++;
    } while (page <= lastPage && page <= 20);

    await OfflineStore.instance.cacheCustomers(customers);
  }

  Future<void> _pullPaymentMethods(String target) async {
    final storeId = TerminalConfigRepository.instance.config.storeId;
    final uri = Uri.parse('$target/payments/methods').replace(queryParameters: {
      if (storeId.isNotEmpty) 'store_id': storeId,
      'pos_only': '1',
    });
    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Pull payment methods failed: HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    final methods = data
        .whereType<Map>()
        .map((item) => PosPaymentMethod.fromJson(Map<String, dynamic>.from(item)))
        .where((method) => method.value.isNotEmpty)
        .toList();
    if (methods.isNotEmpty) {
      await OfflineStore.instance.cachePaymentMethods(methods);
    }
  }

  Future<void> _pushLocalHolds() async {
    final target = activeTarget;
    if (target == null) return;
    final holds = await OfflineStore.instance.loadLocalHolds();
    if (holds.isEmpty) return;
    final storeId = TerminalConfigRepository.instance.config.storeId;
    if (storeId.isEmpty) return;

    final updated = <Map<String, dynamic>>[];
    for (final hold in holds) {
      final items = hold['items'];
      if (items is! List || items.isEmpty) {
        updated.add(hold);
        continue;
      }
      final serverId = hold['server_id']?.toString();
      final uri = serverId == null || serverId.isEmpty
          ? Uri.parse('$target/stores/$storeId/sales/holds')
          : Uri.parse('$target/sales/$serverId');
      final payload = {
        'items': items,
        if (hold['customer_id'] != null) 'customer_id': hold['customer_id'],
        if ((hold['notes']?.toString() ?? '').isNotEmpty) 'notes': hold['notes'],
      };
      try {
        final response = await (serverId == null || serverId.isEmpty
                ? _client.post(uri, headers: _headers, body: jsonEncode(payload))
                : _client.put(uri, headers: _headers, body: jsonEncode(payload)))
            .timeout(const Duration(seconds: 20));
        if (response.statusCode == 200 || response.statusCode == 201) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final data = body['data'] as Map<String, dynamic>? ?? body;
          final id = data['id']?.toString();
          updated.add({
            ...hold,
            if (id != null && serverId == null) 'server_id': id,
          });
        } else {
          updated.add(hold);
        }
      } catch (_) {
        updated.add(hold);
      }
    }
    await OfflineStore.instance.saveLocalHolds(updated);
  }

  Future<int> _pushPending() async {
    final target = activeTarget;
    if (target == null) return 0;
    final rows = await OfflineStore.instance.pendingQueue();
    if (rows.isEmpty) return 0;

    final operations = <Map<String, dynamic>>[];
    final accepted = <Map<String, dynamic>>[];
    for (final row in rows) {
      final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      if (row['entity_type'] == 'sale') {
        final prepared = await OfflineStore.instance.prepareSalePayload(payload);
        if (prepared == null) continue;
        await OfflineStore.instance.markProcessing(row['id'] as String);
        accepted.add(row);
        operations.add({
          'id': row['id'],
          'entity_type': row['entity_type'],
          'entity_id': row['entity_id'],
          'operation': row['operation'],
          'payload': prepared,
        });
        continue;
      }
      await OfflineStore.instance.markProcessing(row['id'] as String);
      accepted.add(row);
      operations.add({
        'id': row['id'],
        'entity_type': row['entity_type'],
        'entity_id': row['entity_id'],
        'operation': row['operation'],
        'payload': payload,
      });
    }
    if (operations.isEmpty) return 0;

    for (final operation in operations) {
      final payload = operation['payload'];
      if (payload is Map<String, dynamic>) {
        final deviceId = payload['device_id']?.toString() ?? '';
        if (deviceId.isEmpty) payload.remove('device_id');
        final customerId = payload['customer_id']?.toString() ?? '';
        if (customerId.isEmpty) payload.remove('customer_id');
      }
    }

    final payload = jsonEncode({'operations': operations});
    var response = await _authorized(
      () => _client
          .post(Uri.parse('$target/sync/push'), headers: _headers, body: payload)
          .timeout(const Duration(seconds: 40)),
    );
    final cloud = _cloudBase;
    if (response.statusCode == 401 && cloud.isNotEmpty && cloud != target) {
      activeTarget = cloud;
      response = await _authorized(
        () => _client
            .post(Uri.parse('$cloud/sync/push'), headers: _headers, body: payload)
            .timeout(const Duration(seconds: 40)),
      );
    }

    if (response.statusCode != 200) {
      final message = _authFailureMessage(response);
      if (response.statusCode == 401) {
        final repo = TerminalConfigRepository.instance;
        await repo.save(repo.config.copyWith(isSignedIn: false));
      }
      for (final row in accepted) {
        final attempts = ((row['attempts'] as int?) ?? 0) + 1;
        await OfflineStore.instance.markFailed(
          row['id'] as String,
          message,
          attempts: attempts,
        );
      }
      throw Exception(message);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;
    final results = data['results'] as List<dynamic>? ?? [];
    for (final result in results) {
      final item = result as Map<String, dynamic>;
      final queueId = item['id']?.toString() ?? '';
      if (queueId.isEmpty) continue;
      final entityId = item['entity_id'] as String? ?? '';
      final status = item['status'] as String? ?? 'failed';
      if (status == 'synced') {
        await OfflineStore.instance.markSynced(
          queueId,
          entityId,
          serverId: item['server_id'] as String?,
          serverReference: item['reference'] as String?,
        );
      } else {
        final attempts = ((item['attempts'] as int?) ?? 1);
        await OfflineStore.instance.markFailed(
          queueId,
          item['error'] as String? ?? 'Sync rejected',
          attempts: attempts,
        );
      }
    }
    return operations.length;
  }

  Future<void> _heartbeat() async {
    final target = activeTarget;
    if (target == null) return;
    final config = TerminalConfigRepository.instance.config;
    await _client
        .post(
          Uri.parse('$target/sync/heartbeat'),
          headers: _headers,
          body: jsonEncode({
            'device_id': config.deviceId,
            'identifier': config.deviceIdentifier,
            'name': config.deviceName,
            'app_version': '0.1.0',
            'pending': pending,
          }),
        )
        .timeout(const Duration(seconds: 8));
  }

  Future<PosCatalog?> cachedCatalog() {
    return OfflineStore.instance.loadCatalog(TerminalConfigRepository.instance.config.storeId);
  }

  Future<void> refreshCatalogNow() async {
    final api = PosApiService();
    final catalog = await api.fetchCatalog();
    await OfflineStore.instance.cacheCatalog(catalog);
    notifyListeners();
  }
}
