import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/config/terminal_config.dart';
import '../core/config/terminal_config_repository.dart';
import '../core/network/operating_mode.dart';
import '../core/network/operation_router.dart';
import '../features/auth/data/pin_auth_service.dart';
import '../features/pos/data/pos_api_service.dart';
import '../features/pos/domain/pos_models.dart';
import 'cloud/cloud_sync_engine.dart';
import 'local_master_server.dart';
import 'local_realtime.dart';
import 'master_config_store.dart';
import 'offline_store.dart';
import 'sync_models.dart';
import 'sync_numbers.dart';

class _BatchResult {
  const _BatchResult({this.sent = 0, this.acknowledged = 0, this.kept = 0, this.stopped = false});

  final int sent;
  final int acknowledged;
  final int kept;
  final bool stopped;
}

class SyncEngine extends ChangeNotifier {
  SyncEngine._();

  static final SyncEngine instance = SyncEngine._();

  final _client = http.Client();
  Timer? _timer;
  StreamSubscription? _realtimeSub;
  bool _running = false;
  bool _started = false;

  ConnectivityState connectivity = ConnectivityState.offline;
  String? lastError;
  DateTime? lastSyncAt;
  /// Bumped only when local catalog rows actually change (POS should reload local cache).
  int catalogRevision = 0;
  String? activeTarget;
  /// Master LAN reachable (probe réel, pas seulement config).
  bool masterReachable = false;
  /// ITARA ERP Cloud reachable.
  bool cloudReachable = false;
  int pending = 0;
  int failed = 0;
  int synced = 0;
  int conflicts = 0;
  int lastSent = 0;
  int lastAcknowledged = 0;
  int lastKept = 0;
  SyncReport lastReport = const SyncReport();

  OperatingMode get operatingMode {
    final role = TerminalConfigRepository.instance.config.posRole;
    return OperatingModeResolver.resolve(
      role: role,
      masterReachable: masterReachable,
      cloudReachable: cloudReachable,
    );
  }

  OperationRouter get router {
    final role = TerminalConfigRepository.instance.config.posRole;
    return OperationRouter(mode: operatingMode, role: role);
  }

  SyncSnapshot get snapshot => SyncSnapshot(
        connectivity: connectivity,
        pending: pending,
        failed: failed,
        synced: synced,
        conflicts: conflicts,
        lastSyncAt: lastSyncAt,
        lastError: lastError,
        target: activeTarget,
        mode: operatingMode,
        masterReachable: masterReachable,
        cloudReachable: cloudReachable,
      );

  void start() {
    if (_started) return;
    _started = true;
    unawaited(_boot());
  }

  Future<void> _boot() async {
    await OfflineStore.instance.releaseStuck();
    await _bindRealtime();
    await refreshCounts();
    await runCycle();
    _arm();
  }

  Future<void> _bindRealtime() async {
    await _realtimeSub?.cancel();
    final config = TerminalConfigRepository.instance.config;
    if (config.isMaster) {
      LocalRealtimeHub.instance.start();
      _realtimeSub = LocalRealtimeHub.instance.events.listen(_onRealtimeEvent);
      return;
    }
    if (config.isSlave) {
      await LocalRealtimeClient.instance.startIfSlave();
      _realtimeSub = LocalRealtimeClient.instance.events.listen(_onRealtimeEvent);
    }
  }

  Future<void> _onRealtimeEvent(RealtimeEvent event) async {
    switch (event.type) {
      case RealtimeEventType.stockUpdated:
        final stock = event.payload['stock'];
        if (stock is List && stock.isNotEmpty) {
          await OfflineStore.instance.applyAuthoritativeStock(stock);
          catalogRevision++;
          notifyListeners();
        } else {
          await _pullMasterStock();
        }
      case RealtimeEventType.configUpdated:
        await pullMasterConfig();
      case RealtimeEventType.deviceCommand:
        await _onDeviceCommand(event);
      case RealtimeEventType.newSale:
      case RealtimeEventType.saleUpdated:
      case RealtimeEventType.paymentReceived:
      case RealtimeEventType.orderCreated:
      case RealtimeEventType.orderUpdated:
      case RealtimeEventType.kitchenOrderCreated:
      case RealtimeEventType.kitchenOrderReady:
      case RealtimeEventType.tableUpdated:
      case RealtimeEventType.notificationCreated:
      case RealtimeEventType.deviceConnected:
      case RealtimeEventType.deviceDisconnected:
        notifyListeners();
        if (!_running && TerminalConfigRepository.instance.config.isSlave) {
          unawaited(runCycle());
        }
      default:
        break;
    }
  }

  Future<void> pullMasterConfig() async {
    final target = activeTarget ?? _internalBase;
    if (target == null || target != _internalBase) return;
    try {
      final response = await _client
          .get(Uri.parse('$target/config'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : body;
      await MasterConfigStore.instance.applyToTerminal(data);
    } catch (_) {}
  }

  /// Master §45 commands pushed to this slave over realtime.
  Future<void> _onDeviceCommand(RealtimeEvent event) async {
    final config = TerminalConfigRepository.instance.config;
    if (!config.isSlave) return;
    final targetId = event.payload['device_id']?.toString() ?? '';
    if (targetId.isNotEmpty &&
        config.deviceId.isNotEmpty &&
        targetId != config.deviceId) {
      return;
    }
    final action = event.payload['action']?.toString() ?? '';
    switch (action) {
      case 'sync':
        if (!_running) unawaited(runCycle());
      case 'reconnect':
        await LocalRealtimeClient.instance.stop();
        await LocalRealtimeClient.instance.startIfSlave();
      case 'send_configuration':
        await pullMasterConfig();
      case 'disable':
        // Master revoked LAN access; drop the realtime socket.
        await LocalRealtimeClient.instance.stop();
      default:
        break;
    }
  }

  void disposeEngine() {
    _started = false;
    _timer?.cancel();
    _timer = null;
    unawaited(_realtimeSub?.cancel());
    _realtimeSub = null;
  }

  void _arm() {
    if (!_started) return;
    _timer?.cancel();
    final Duration wait;
    if (pending > 0 && connectivity == ConnectivityState.offline) {
      wait = const Duration(seconds: 8);
    } else if (pending > 0) {
      wait = const Duration(seconds: 20);
    } else {
      wait = const Duration(seconds: 45);
    }
    _timer = Timer(wait, () async {
      if (!_started) return;
      await runCycle();
      _arm();
    });
  }

  Future<void> refreshCounts({bool forceNotify = false}) async {
    final counts = await OfflineStore.instance.counts();
    final nextPending = counts['pending'] ?? 0;
    final nextFailed = counts['failed'] ?? 0;
    final nextSynced = counts['synced'] ?? 0;
    final nextConflicts = counts['conflicts'] ?? 0;
    final changed = forceNotify ||
        nextPending != pending ||
        nextFailed != failed ||
        nextSynced != synced ||
        nextConflicts != conflicts;
    pending = nextPending;
    failed = nextFailed;
    synced = nextSynced;
    conflicts = nextConflicts;
    if (changed) notifyListeners();
  }

  Future<SyncReport> syncNow() async {
    await runCycle(forcePull: true, pushOutbound: true);
    return lastReport;
  }

  Future<SyncReport> downloadStock() async {
    if (_running) {
      return lastReport = const SyncReport(ok: false, message: 'Synchronisation déjà en cours');
    }
    _running = true;
    connectivity = ConnectivityState.syncing;
    notifyListeners();
    try {
      await _probe();
      if (activeTarget == null) {
        lastError = operatingMode == OperatingMode.isolatedOffline
            ? 'Mode C — Master indisponible. File offline active.'
            : 'Serveur indisponible';
        connectivity = _connectivityForIdle();
        return lastReport = SyncReport(ok: false, message: lastError!);
      }
      final catalog = await _refreshCatalogCounts();
      final refs = await _pullReferenceCounts();
      lastSyncAt = DateTime.now();
      lastError = null;
      connectivity = _connectivityForIdle();
      return lastReport = SyncReport(
        message: 'Téléchargement terminé',
        products: catalog.products,
        categories: catalog.categories,
        customers: refs.customers,
        paymentMethods: refs.paymentMethods,
        units: refs.units,
        users: refs.users,
        roles: refs.roles,
        permissions: refs.permissions,
        currencies: refs.currencies,
        taxes: refs.taxes,
      );
    } catch (error) {
      lastError = error.toString().replaceFirst('Exception: ', '');
      connectivity = ConnectivityState.syncError;
      return lastReport = SyncReport(ok: false, message: lastError!);
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<SyncReport> syncStock() async {
    if (_running) {
      return lastReport = const SyncReport(ok: false, message: 'Synchronisation déjà en cours');
    }
    _running = true;
    connectivity = ConnectivityState.syncing;
    notifyListeners();
    try {
      await _probe();
      if (activeTarget == null) {
        lastError = operatingMode == OperatingMode.isolatedOffline
            ? 'Mode C — Master indisponible. File offline active.'
            : 'Serveur indisponible';
        connectivity = _connectivityForIdle();
        return lastReport = SyncReport(ok: false, message: lastError!);
      }
      final sent = await _drainQueue();
      final catalog = await _refreshCatalogCounts();
      final refs = await _pullReferenceCounts();
      lastSyncAt = DateTime.now();
      lastError = null;
      connectivity = _connectivityForIdle();
      await refreshCounts();
      return lastReport = SyncReport(
        message: pending == 0 ? 'Stock envoyé et téléchargé' : 'Stock téléchargé · $pending en attente',
        products: catalog.products,
        categories: catalog.categories,
        customers: refs.customers,
        paymentMethods: refs.paymentMethods,
        units: refs.units,
        users: refs.users,
        roles: refs.roles,
        permissions: refs.permissions,
        currencies: refs.currencies,
        taxes: refs.taxes,
        sent: sent,
      );
    } catch (error) {
      lastError = error.toString().replaceFirst('Exception: ', '');
      connectivity = ConnectivityState.syncError;
      return lastReport = SyncReport(ok: false, message: lastError!);
    } finally {
      _running = false;
      await refreshCounts();
    }
  }

  Future<SyncReport> sendStock() async {
    if (_running) {
      return lastReport = const SyncReport(ok: false, message: 'Synchronisation déjà en cours');
    }
    _running = true;
    connectivity = ConnectivityState.syncing;
    notifyListeners();
    try {
      await _probe();
      if (activeTarget == null) {
        lastError = operatingMode == OperatingMode.isolatedOffline
            ? 'Mode C — opérations en file locale. Sync au retour du Master.'
            : 'Serveur indisponible. Vérifiez l’URL API et la connexion.';
        connectivity = _connectivityForIdle();
        return lastReport = SyncReport(ok: false, message: lastError!);
      }
      await _prepareAuth();
      await OfflineStore.instance.releaseStuck();
      await OfflineStore.instance.retryAllFailed();

      final sent = await _drainQueue();

      await _pushLocalHolds();
      await refreshCounts();
      final error = await OfflineStore.instance.latestQueueError();
      if (error != null && pending > 0) {
        lastError = error;
        connectivity = ConnectivityState.syncError;
        return lastReport = SyncReport(ok: false, message: error, sent: sent);
      }

      lastSyncAt = DateTime.now();
      lastError = null;
      connectivity = _connectivityForIdle();
      final message = pending == 0
          ? (sent == 0 ? 'Rien à envoyer' : 'Ventes et stock envoyés')
          : 'Envoi partiel · $pending en attente';
      return lastReport = SyncReport(ok: pending == 0 || sent > 0, message: message, sent: sent);
    } catch (error) {
      lastError = error.toString().replaceFirst('Exception: ', '');
      connectivity = ConnectivityState.syncError;
      return lastReport = SyncReport(ok: false, message: lastError!);
    } finally {
      _running = false;
      await refreshCounts();
    }
  }

  Future<void> runCycle({bool forcePull = false, bool pushOutbound = true}) async {
    if (_running) return;
    _running = true;
    final showBusy = forcePull || pending > 0;
    if (showBusy) {
      connectivity = ConnectivityState.syncing;
      notifyListeners();
    }

    var products = 0;
    var categories = 0;
    var customers = 0;
    var paymentMethods = 0;
    var units = 0;
    var users = 0;
    var roles = 0;
    var permissions = 0;
    var currencies = 0;
    var taxes = 0;
    var sent = 0;
    var catalogChanged = false;

    try {
      final hadTarget = activeTarget != null;
      await _probe();
      if (!hadTarget && activeTarget != null) {
        // Mode C → Master/Cloud revenu : rejouer la file.
        await OfflineStore.instance.retryAllFailed();
      }
      if (activeTarget == null) {
        final next = _connectivityForIdle();
        if (connectivity != next) {
          connectivity = next;
          notifyListeners();
        }
        lastError = null;
        return;
      }

      // Master / Standalone → ITARA ERP Cloud (mobile.md §35).
      if (router.allowsDirectCloud && activeTarget == _cloudBase) {
        final cloud = await CloudSyncEngine.instance.syncNow(
          pull: forcePull || await _shouldPull() || await _shouldPullReference(),
          push: pushOutbound,
        );
        lastSyncAt = CloudSyncEngine.instance.lastSyncAt ?? DateTime.now();
        lastError = cloud.ok ? null : cloud.message;
        connectivity = cloud.ok ? _connectivityForIdle() : ConnectivityState.syncError;
        lastReport = cloud.toSyncReport();
        if (cloud.totalPulled > 0) catalogRevision++;
        if (showBusy || !cloud.ok || cloud.totalPushed > 0 || cloud.totalPulled > 0) {
          notifyListeners();
        }
        return;
      }

      try {
        await _heartbeat();
      } catch (_) {}
      try {
        if (forcePull || await _shouldPull()) {
          final catalog = await _pullCatalog(replaceAll: forcePull);
          products = catalog.products;
          categories = catalog.categories;
          catalogChanged = products > 0 || categories > 0;
        }
        if (forcePull || await _shouldPullReference()) {
          final refs = await _pullReferenceCounts();
          customers = refs.customers;
          paymentMethods = refs.paymentMethods;
          units = refs.units;
          users = refs.users;
          roles = refs.roles;
          permissions = refs.permissions;
          currencies = refs.currencies;
          taxes = refs.taxes;
        }
      } catch (error) {
        lastError = error.toString();
        await OfflineStore.instance.log('error', lastError!);
      }
      if (pushOutbound) {
        sent = await _drainQueue();
        await _pushLocalHolds();
        if (activeTarget == _internalBase) {
          try {
            final stockTouched = await _pullMasterStock();
            catalogChanged = catalogChanged || stockTouched;
          } catch (_) {}
          try {
            await pullMasterConfig();
          } catch (_) {}
        }
      }
      lastSyncAt = DateTime.now();
      lastError = null;
      if (catalogChanged) catalogRevision++;
      connectivity = _connectivityForIdle();
      lastReport = SyncReport(
        message: 'Synchronisation terminée',
        products: products,
        categories: categories,
        customers: customers,
        paymentMethods: paymentMethods,
        units: units,
        users: users,
        roles: roles,
        permissions: permissions,
        currencies: currencies,
        taxes: taxes,
        sent: sent,
      );
      if (showBusy || catalogChanged || sent > 0) notifyListeners();
    } catch (error) {
      lastError = error.toString();
      connectivity = ConnectivityState.syncError;
      lastReport = SyncReport(ok: false, message: lastError!);
      await OfflineStore.instance.log('error', lastError!);
      notifyListeners();
    } finally {
      _running = false;
      await refreshCounts(forceNotify: showBusy || catalogChanged || sent > 0);
    }
  }

  String? get _internalBase => LocalMasterServer.clientBaseUrl();

  String get _cloudBase {
    final value = TerminalConfigRepository.instance.config.apiBaseUrl.trim();
    return value.replaceAll(RegExp(r'/$'), '');
  }

  /// Probe Master + Cloud, puis choisit la cible selon Mode A/B/C.
  ///
  /// - Slave : Master uniquement (jamais Cloud direct).
  /// - Master / Standalone : Cloud quand disponible ; sinon file locale.
  Future<void> _probe() async {
    final config = TerminalConfigRepository.instance.config;
    final role = config.posRole;
    final internal = _internalBase;
    final cloud = _cloudBase;

    if (role == PosRole.master) {
      masterReachable = LocalMasterServer.instance.listening;
    } else if (internal != null && internal.isNotEmpty) {
      masterReachable = await _healthy(internal);
    } else {
      masterReachable = false;
    }

    cloudReachable = cloud.isNotEmpty && await _healthy(cloud);

    final path = OperationRouter(
      mode: OperatingModeResolver.resolve(
        role: role,
        masterReachable: masterReachable,
        cloudReachable: cloudReachable,
      ),
      role: role,
    );

    switch (path.outboundTarget) {
      case SyncTargetKind.master:
        activeTarget = masterReachable ? internal : null;
      case SyncTargetKind.cloud:
        activeTarget = cloudReachable ? cloud : null;
      case SyncTargetKind.localQueue:
        activeTarget = null;
    }
  }

  ConnectivityState _connectivityForIdle() {
    return switch (operatingMode) {
      OperatingMode.fullOnline => ConnectivityState.online,
      OperatingMode.localOffline => ConnectivityState.localAvailable,
      OperatingMode.isolatedOffline => ConnectivityState.offline,
    };
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
      if (config.masterPairToken.isNotEmpty) 'X-Pair-Token': config.masterPairToken,
      if (config.deviceName.isNotEmpty) 'X-Device-Name': config.deviceName,
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
    return DateTime.now().difference(parsed) > const Duration(minutes: 15);
  }

  Future<bool> _shouldPull() async {
    final last = await OfflineStore.instance.checkpoint('catalog_synced_at');
    if (last == null) return true;
    final parsed = DateTime.tryParse(last);
    if (parsed == null) return true;
    return DateTime.now().difference(parsed) > const Duration(minutes: 15);
  }

  Future<({int products, int categories})> _pullCatalog({bool replaceAll = false}) async {
    final target = activeTarget;
    final storeId = TerminalConfigRepository.instance.config.storeId;
    if (target == null || storeId.isEmpty) return (products: 0, categories: 0);

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
      if (replaceAll) {
        await OfflineStore.instance.cacheCatalog(catalog);
      } else {
        await OfflineStore.instance.mergeCatalog(catalog);
      }
    }
    final sequence = data['server_sequence']?.toString();
    if (sequence != null) {
      await OfflineStore.instance.setCheckpoint('last_server_sequence', sequence);
    }
    await OfflineStore.instance.setCheckpoint('catalog_synced_at', DateTime.now().toIso8601String());
    return (products: catalog.products.length, categories: catalog.categories.length);
  }

  Future<({
    int customers,
    int paymentMethods,
    int units,
    int users,
    int roles,
    int permissions,
    int currencies,
    int taxes,
  })> _pullReferenceCounts() async {
    final target = activeTarget;
    if (target == null) {
      return (
        customers: 0,
        paymentMethods: 0,
        units: 0,
        users: 0,
        roles: 0,
        permissions: 0,
        currencies: 0,
        taxes: 0,
      );
    }
    final customers = await _pullCustomers(target);
    final refs = await _pullSyncReferences(target);
    await OfflineStore.instance.setCheckpoint('customers_synced_at', DateTime.now().toIso8601String());
    return (
      customers: customers,
      paymentMethods: refs.paymentMethods,
      units: refs.units,
      users: refs.users,
      roles: refs.roles,
      permissions: refs.permissions,
      currencies: refs.currencies,
      taxes: refs.taxes,
    );
  }

  Future<({
    int paymentMethods,
    int units,
    int users,
    int roles,
    int permissions,
    int currencies,
    int taxes,
  })> _pullSyncReferences(String target) async {
    final uri = Uri.parse('$target/sync/references');
    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 30));
    if (response.statusCode == 404) {
      final paymentMethods = await _pullPaymentMethods(target);
      return (
        paymentMethods: paymentMethods,
        units: 0,
        users: 0,
        roles: 0,
        permissions: 0,
        currencies: 0,
        taxes: 0,
      );
    }
    if (response.statusCode != 200) {
      throw Exception('Pull references failed: HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;
    await OfflineStore.instance.cacheReferenceBundle(data);
    return (
      paymentMethods: (data['payment_methods'] as List?)?.length ?? 0,
      units: (data['units'] as List?)?.length ?? 0,
      users: (data['users'] as List?)?.length ?? 0,
      roles: (data['roles'] as List?)?.length ?? 0,
      permissions: (data['permissions'] as List?)?.length ?? 0,
      currencies: (data['currencies'] as List?)?.length ?? 0,
      taxes: (data['taxes'] as List?)?.length ?? 0,
    );
  }

  Future<int> _pullCustomers(String target) async {
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
        lastPage = syncAsInt(pageBody['last_page'], page);
      }
      customers.addAll(
        data.whereType<Map>().map((item) => PosCustomer.fromJson(Map<String, dynamic>.from(item))),
      );
      lastPage = syncAsInt(pageBody['last_page'], page);
      page++;
    } while (page <= lastPage && page <= 20);

    await OfflineStore.instance.cacheCustomers(customers);
    return customers.length;
  }

  Future<int> _pullPaymentMethods(String target) async {
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
    return methods.length;
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

  Future<int> _drainQueue() async {
    await OfflineStore.instance.releaseStuck();
    var sent = 0;
    var acknowledged = 0;
    var kept = 0;
    for (var pass = 0; pass < 40; pass++) {
      if (activeTarget == null) break;
      final batch = await _pushPending();
      sent += batch.sent;
      acknowledged += batch.acknowledged;
      kept += batch.kept;
      if (batch.sent == 0 || batch.stopped) break;
    }
    lastSent = sent;
    lastAcknowledged = acknowledged;
    lastKept = kept;
    return sent;
  }

  Future<_BatchResult> _pushPending() async {
    final target = activeTarget;
    if (target == null) return const _BatchResult();
    final rows = await OfflineStore.instance.pendingQueue(limit: 400);
    if (rows.isEmpty) return const _BatchResult();

    final operations = <Map<String, dynamic>>[];
    final accepted = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (accepted.length >= 50) break;
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
    if (operations.isEmpty) return const _BatchResult();

    for (final operation in operations) {
      final payload = operation['payload'];
      if (payload is Map<String, dynamic>) {
        final config = TerminalConfigRepository.instance.config;
        var deviceId = payload['device_id']?.toString() ?? '';
        if (deviceId.isEmpty) {
          deviceId = config.deviceId.isNotEmpty ? config.deviceId : config.deviceIdentifier;
          if (deviceId.isNotEmpty) payload['device_id'] = deviceId;
        }
        if ((payload['user_id']?.toString() ?? '').isEmpty && config.cashierId.isNotEmpty) {
          payload['user_id'] = config.cashierId;
        }
        if ((payload['cash_register_id']?.toString() ?? '').isEmpty && config.cashRegisterId.isNotEmpty) {
          payload['cash_register_id'] = config.cashRegisterId;
        }
        final registerId = payload['cash_register_id']?.toString() ?? '';
        if (registerId.startsWith('reg-')) {
          if (config.cashRegisterId.isNotEmpty) {
            payload['cash_register_id'] = config.cashRegisterId;
          } else {
            payload.remove('cash_register_id');
          }
        }
        if ((payload['cash_session_id']?.toString() ?? '').isEmpty && config.cashSessionId.isNotEmpty) {
          payload['cash_session_id'] = config.cashSessionId;
        }
        final sessionId = payload['cash_session_id']?.toString() ?? '';
        if (sessionId.startsWith('ses-')) {
          if (config.cashSessionId.isNotEmpty) {
            payload['cash_session_id'] = config.cashSessionId;
          } else {
            payload.remove('cash_session_id');
          }
        }
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
    // Slave : jamais de fallback Cloud direct (Mode A/B via Master uniquement).
    final cloud = _cloudBase;
    if (response.statusCode == 401 &&
        router.allowsDirectCloud &&
        cloud.isNotEmpty &&
        cloud != target) {
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
        final attempts = syncAsInt(row['attempts']) + 1;
        await OfflineStore.instance.markFailed(
          row['id'] as String,
          message,
          attempts: attempts,
        );
      }
      if (response.statusCode == 401) throw Exception(message);
      return _BatchResult(sent: accepted.length, kept: accepted.length, stopped: true);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;
    final results = data['results'] as List<dynamic>? ?? [];
    final acceptedById = {
      for (final row in accepted) row['id'] as String: row,
    };
    final seen = <String>{};
    final readyForAck = <Map<String, dynamic>>[];

    for (final result in results) {
      final item = result as Map<String, dynamic>;
      final queueId = item['id']?.toString() ?? '';
      if (queueId.isEmpty) continue;
      seen.add(queueId);
      final row = acceptedById[queueId];
      final entityId = item['entity_id']?.toString().isNotEmpty == true
          ? item['entity_id'].toString()
          : row?['entity_id']?.toString() ?? '';
      final status = item['status'] as String? ?? 'failed';
      if (status == 'synced' && entityId.isNotEmpty) {
        readyForAck.add({
          'id': queueId,
          'entity_id': entityId,
          'entity_type': row?['entity_type']?.toString() ?? 'sale',
          'server_id': item['server_id']?.toString(),
          'reference': item['reference']?.toString(),
          'attempts': syncAsInt(row?['attempts']),
          'stock': item['stock'],
          'cash_register_id': item['cash_register_id']?.toString(),
          'cash_session_id': item['cash_session_id']?.toString(),
        });
        continue;
      }
      await OfflineStore.instance.markFailed(
        queueId,
        item['error'] as String? ?? 'Sync rejected, événement conservé',
        attempts: syncAsInt(row?['attempts']) + 1,
      );
    }

    for (final row in accepted) {
      final queueId = row['id'] as String;
      if (seen.contains(queueId)) continue;
      await OfflineStore.instance.markFailed(
        queueId,
        'Réponse serveur incomplète, événement conservé',
        attempts: syncAsInt(row['attempts']) + 1,
      );
    }

    if (readyForAck.isEmpty) {
      return _BatchResult(sent: operations.length, kept: operations.length);
    }

    final ackTarget = activeTarget;
    if (ackTarget == null) {
      for (final item in readyForAck) {
        await OfflineStore.instance.markFailed(
          item['id'] as String,
          'ACK manquant, événement conservé',
          attempts: syncAsInt(item['attempts']) + 1,
        );
      }
      return _BatchResult(sent: operations.length, kept: operations.length, stopped: true);
    }

    Set<String> acknowledged;
    try {
      acknowledged = await _acknowledge(ackTarget, readyForAck);
    } catch (_) {
      for (final item in readyForAck) {
        await OfflineStore.instance.markFailed(
          item['id'] as String,
          'ACK manquant, événement conservé',
          attempts: syncAsInt(item['attempts']) + 1,
        );
      }
      return _BatchResult(sent: operations.length, kept: operations.length);
    }

    var acked = 0;
    for (final item in readyForAck) {
      final queueId = item['id'] as String;
      if (!acknowledged.contains(queueId)) {
        await OfflineStore.instance.markFailed(
          queueId,
          'ACK refusé, événement conservé',
          attempts: syncAsInt(item['attempts']) + 1,
        );
        continue;
      }
      acked++;
      final serverId = item['server_id'] as String?;
      await OfflineStore.instance.markSynced(
        queueId,
        item['entity_id'] as String,
        serverId: serverId == null || serverId.isEmpty ? null : serverId,
        serverReference: item['reference'] as String?,
      );
      final stock = item['stock'];
      if (stock is List && stock.isNotEmpty) {
        await OfflineStore.instance.applyAuthoritativeStock(stock);
      }
      await _rememberLane(
        registerId: item['cash_register_id']?.toString(),
        sessionId: item['cash_session_id']?.toString(),
      );
    }
    return _BatchResult(
      sent: operations.length,
      acknowledged: acked,
      kept: operations.length - acked,
    );
  }

  Future<void> _rememberLane({String? registerId, String? sessionId}) async {
    final repo = TerminalConfigRepository.instance;
    final config = repo.config;
    final nextRegister = registerId != null && registerId.isNotEmpty ? registerId : config.cashRegisterId;
    final nextSession = sessionId != null && sessionId.isNotEmpty ? sessionId : config.cashSessionId;
    if (nextRegister == config.cashRegisterId && nextSession == config.cashSessionId) return;
    await repo.save(config.copyWith(
      cashRegisterId: nextRegister,
      cashSessionId: nextSession,
    ));
  }

  Future<Set<String>> _acknowledge(String target, List<Map<String, dynamic>> operations) async {
    final response = await _authorized(
      () => _client
          .post(
            Uri.parse('$target/sync/ack'),
            headers: _headers,
            body: jsonEncode({
              'operations': operations
                  .map((item) => {
                        'id': item['id'],
                        'entity_type': item['entity_type'],
                        'entity_id': item['entity_id'],
                        if (item['server_id'] != null && (item['server_id'] as String).isNotEmpty)
                          'server_id': item['server_id'],
                      })
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 20)),
    );
    if (response.statusCode != 200) {
      throw Exception(_authFailureMessage(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;
    final ids = data['acknowledged_ids'] as List<dynamic>? ?? [];
    return ids.map((id) => id.toString()).where((id) => id.isNotEmpty).toSet();
  }

  Future<void> _heartbeat() async {
    final target = activeTarget;
    if (target == null) return;
    final config = TerminalConfigRepository.instance.config;
    final response = await _client
        .post(
          Uri.parse('$target/sync/heartbeat'),
          headers: _headers,
          body: jsonEncode({
            'device_id': config.deviceId.isNotEmpty ? config.deviceId : config.deviceIdentifier,
            'identifier': config.deviceIdentifier,
            'name': config.deviceName,
            'device_type': 'pos',
            'os': defaultTargetPlatform.name,
            'tenant_id': config.tenantId,
            'branch_id': config.storeId,
            'store_id': config.storeId,
            'cash_register_id': config.cashRegisterId,
            'cash_session_id': config.cashSessionId,
            'user_id': config.cashierId,
            'user_name': config.cashierName,
            'role': config.posRole.name,
            'app_version': AppConfig.appVersion,
            'version': AppConfig.appVersion,
            'pending': pending,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200 || target != _internalBase) return;
    await _applyStockBody(response.body);
  }

  Future<bool> _pullMasterStock() async {
    final target = activeTarget;
    if (target == null || target != _internalBase) return false;
    final response = await _client
        .get(Uri.parse('$target/sync/stock'), headers: _headers)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return false;
    return _applyStockBody(response.body);
  }

  Future<bool> _applyStockBody(String raw) async {
    final body = jsonDecode(raw) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;
    final stock = data['stock'];
    if (stock is! List || stock.isEmpty) return false;
    await OfflineStore.instance.applyAuthoritativeStock(stock);
    return true;
  }

  Future<PosCatalog?> cachedCatalog() {
    return OfflineStore.instance.loadCatalog(TerminalConfigRepository.instance.config.storeId);
  }

  Future<({int products, int categories})> _refreshCatalogCounts() async {
    final api = PosApiService();
    final catalog = await api.fetchCatalog();
    await OfflineStore.instance.cacheCatalog(catalog);
    await OfflineStore.instance.setCheckpoint('catalog_synced_at', DateTime.now().toIso8601String());
    catalogRevision++;
    notifyListeners();
    return (products: catalog.products.length, categories: catalog.categories.length);
  }

  Future<void> refreshCatalogNow() async {
    await _refreshCatalogCounts();
  }
}
