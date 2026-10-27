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
import '../features/backup/data/backup_service.dart';
import '../features/pos/data/pos_api_service.dart';
import '../features/pos/domain/pos_models.dart';
import 'cloud/cloud_sync_engine.dart';
import 'cloud/cloud_sync_entity.dart';
import 'local_master_server.dart';
import 'local_realtime.dart';
import 'master_config_store.dart';
import 'offline_store.dart';
import 'shift_sync.dart';
import 'sync_models.dart';
import 'sync_numbers.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

String _syncFailure(Object error) {
  final text = error.toString();
  if (error is TimeoutException || text.startsWith('TimeoutException')) {
    return 'Le serveur n’a pas répondu à temps. Les données locales sont conservées.';
  }
  return text.replaceFirst('Exception: ', '');
}

class _BatchResult {
  const _BatchResult({this.sent = 0, this.acknowledged = 0, this.kept = 0, this.stopped = false});

  final int sent;
  final int acknowledged;
  final int kept;
  final bool stopped;
}

enum ClosePeriodStep { upload, verify, backup, clean }

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
    await OfflineStore.instance.reconcilePendingSaleStock();
    await OfflineStore.instance.releaseStuck();
    await _bindRealtime();
    await refreshCounts();
    await runCycle();
    _arm();
  }

  Future<void> _bindRealtime() async {
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    final config = TerminalConfigRepository.instance.config;
    if (config.isMaster) {
      LocalRealtimeHub.instance.start();
      _realtimeSub = LocalRealtimeHub.instance.events.listen(_onRealtimeEvent);
      return;
    }
    await LocalRealtimeClient.instance.stop();
    if (config.isSlave) {
      await LocalRealtimeClient.instance.startIfSlave();
      _realtimeSub = LocalRealtimeClient.instance.events.listen(_onRealtimeEvent);
    }
  }

  /// Call after Master ↔ Slave ↔ Standalone role changes so probes and realtime match.
  Future<void> applyRoleChange() async {
    if (!_started) {
      start();
      return;
    }
    await _bindRealtime();
    await _probe();
    connectivity = _connectivityForIdle();
    notifyListeners();
    if (!_running) unawaited(runCycle());
  }

  Future<void> _onRealtimeEvent(RealtimeEvent event) async {
    switch (event.type) {
      case RealtimeEventType.stockUpdated:
        final selfId = TerminalConfigRepository.instance.config.deviceId;
        if (selfId.isNotEmpty && event.originDeviceId == selfId) {
          // Already applied locally before the hub broadcast.
          return;
        }
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

  /// Upload, verify nothing is left unsent, then back up. Synced shifts and
  /// orders stay on this device. Nothing is deleted unless every operation
  /// is synced, and even then only the upload queue is cleared.
  Future<SyncReport> closePeriod({void Function(ClosePeriodStep step)? onStep}) async {
    onStep?.call(ClosePeriodStep.upload);
    await OfflineStore.instance.reconcileAckedSales();
    await OfflineStore.instance.requeueUnsentSales();
    final upload = await sendStock();
    if (!upload.ok && upload.sent == 0 && activeTarget == null) return upload;

    onStep?.call(ClosePeriodStep.verify);
    await OfflineStore.instance.reconcileAckedSales();
    await refreshCounts();
    final blocked = [
      ...await OfflineStore.instance.blockingOperationLabels(),
      ...await OfflineStore.instance.unpushedHoldLabels(),
    ];
    if (blocked.isNotEmpty) {
      final preview = blocked.take(6).join('\n');
      lastReport = SyncReport(
        ok: false,
        message: '${trf('Période non clôturée : {0} opération(s) pas encore synchronisée(s).', [blocked.length])}\n$preview',
        sent: upload.sent,
      );
      notifyListeners();
      return lastReport;
    }

    onStep?.call(ClosePeriodStep.backup);
    await BackupService.instance.create(upload: false);
    onStep?.call(ClosePeriodStep.clean);
    final purged = await OfflineStore.instance.purgeSyncedMovements();
    await OfflineStore.instance.log('info', 'Period closed · $purged');
    await refreshCounts(forceNotify: true);
    lastReport = SyncReport(
      message: tr('Période clôturée. Les shifts et les commandes restent sur cet appareil.'),
      sent: upload.sent,
    );
    notifyListeners();
    return lastReport;
  }

  Future<SyncReport> downloadStock() async {
    if (_running) {
      return lastReport = SyncReport(ok: false, message: tr('Synchronisation déjà en cours'));
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
      await OfflineStore.instance.log('info', 'Download · catalogue + stock (cloud + pending locaux)');
      final catalog = await _refreshCatalogCounts();
      final refs = await _pullReferenceCounts();
      if (activeTarget == _internalBase) {
        try {
          await _pullMasterStock();
        } catch (_) {}
      } else if (CloudSyncEngine.instance.isAllowed) {
        try {
          await CloudSyncEngine.instance.syncModule(CloudSyncModule.stock);
        } catch (_) {}
      }
      lastSyncAt = DateTime.now();
      lastError = null;
      connectivity = _connectivityForIdle();
      return lastReport = SyncReport(
        message: tr('Téléchargement terminé'),
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
      lastError = _syncFailure(error);
      connectivity = ConnectivityState.syncError;
      return lastReport = SyncReport(ok: false, message: lastError!);
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<SyncReport> syncStock() async {
    if (_running) {
      return lastReport = SyncReport(ok: false, message: tr('Synchronisation déjà en cours'));
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
      // Ordre: upload → ACK (dans _drainQueue) → download → recalcul local (pending).
      final sent = await _drainQueue();
      await _pushLocalHolds();
      final catalog = await _refreshCatalogCounts();
      final refs = await _pullReferenceCounts();
      if (activeTarget == _internalBase) {
        try {
          await _pullMasterStock();
        } catch (_) {}
      } else if (CloudSyncEngine.instance.isAllowed) {
        try {
          await CloudSyncEngine.instance.syncModule(CloudSyncModule.stock);
        } catch (_) {}
      }
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
      lastError = _syncFailure(error);
      connectivity = ConnectivityState.syncError;
      return lastReport = SyncReport(ok: false, message: lastError!);
    } finally {
      _running = false;
      await refreshCounts();
    }
  }

  Future<SyncReport> sendStock() async {
    if (_running) {
      return lastReport = SyncReport(ok: false, message: tr('Synchronisation déjà en cours'));
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
      lastError = _syncFailure(error);
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
        final productsPulled = cloud.pulled[CloudSyncEntity.products] ?? 0;
        if (cloud.totalPulled > 0 || productsPulled > 0) catalogRevision++;
        if (pushOutbound) {
          final unpaidLeft = await _pushLocalHolds();
          if (unpaidLeft > 0) {
            final note = trf('{0} commande(s) impayée(s) non synchronisée(s).', [unpaidLeft]);
            lastError = cloud.ok ? note : '${cloud.message}\n$note';
            connectivity = ConnectivityState.syncError;
            lastReport = SyncReport(ok: false, message: lastError!, sent: cloud.totalPushed);
            notifyListeners();
            return;
          }
        }
        if (showBusy || !cloud.ok || cloud.totalPushed > 0 || cloud.totalPulled > 0) {
          notifyListeners();
        }
        return;
      }

      try {
        await _heartbeat();
      } catch (_) {}
      // Ordre: upload → ACK → download → recalcul local (pending dans applyAuthoritativeStock).
      if (pushOutbound) {
        await OfflineStore.instance.log('info', 'Sync · upload file + ACK');
        sent = await _drainQueue();
        await _pushLocalHolds();
      }
      try {
        await OfflineStore.instance.log('info', 'Sync · download références / stock');
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
        if (activeTarget == _internalBase) {
          try {
            final stockTouched = await _pullMasterStock();
            catalogChanged = catalogChanged || stockTouched;
          } catch (_) {}
          try {
            await pullMasterConfig();
          } catch (_) {}
        }
      } catch (error) {
        lastError = _syncFailure(error);
        await OfflineStore.instance.log('error', lastError!);
      }
      lastSyncAt = DateTime.now();
      lastError = null;
      if (catalogChanged) catalogRevision++;
      connectivity = _connectivityForIdle();
      lastReport = SyncReport(
        message: tr('Synchronisation terminée'),
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
      lastError = _syncFailure(error);
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
          .timeout(const Duration(seconds: 15));
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
    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 30));
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

  /// Uploads parked tickets. Returns how many unpaid orders are still local.
  Future<int> _pushLocalHolds() async {
    final target = activeTarget;
    if (target == null) return 0;
    final holds = await OfflineStore.instance.loadLocalHolds();
    if (holds.isEmpty) return 0;
    final storeId = TerminalConfigRepository.instance.config.storeId;
    if (storeId.isEmpty) return 0;

    final updated = <Map<String, dynamic>>[];
    var failed = 0;
    for (final hold in holds) {
      final items = _holdItems(hold);
      final tableId = hold['table_id']?.toString().trim() ?? '';
      if (items.isEmpty && tableId.isEmpty) {
        updated.add(hold);
        continue;
      }
      final localId = hold['id']?.toString().trim() ?? '';
      var serverId = hold['server_id']?.toString().trim() ?? '';
      final payload = await _holdPayload(hold, items);
      try {
        var response = await _sendHold(target, storeId, serverId, payload);
        if (response.statusCode == 404 && serverId.isNotEmpty) {
          serverId = '';
          response = await _sendHold(target, storeId, serverId, payload);
        }
        if (response.statusCode == 422) {
          if (_holdAlreadySettled(_holdError(response))) {
            updated.add({
              ...hold,
              if (serverId.isNotEmpty) 'server_id': serverId,
              'uploaded_at': DateTime.now().toIso8601String(),
            }..remove('sync_error'));
            continue;
          }
          final relaxed = Map<String, dynamic>.from(payload)..remove('table_id')..remove('customer_id');
          response = await _sendHold(target, storeId, serverId, relaxed);
          if (_holdAlreadySettled(_holdError(response))) {
            updated.add({
              ...hold,
              if (serverId.isNotEmpty) 'server_id': serverId,
              'uploaded_at': DateTime.now().toIso8601String(),
            }..remove('sync_error'));
            continue;
          }
        }
        if (response.statusCode == 200 || response.statusCode == 201) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final data = body['data'] as Map<String, dynamic>? ?? body;
          final id = data['id']?.toString();
          updated.add({
            ...hold,
            if (serverId.isEmpty && id != null && id.isNotEmpty) 'server_id': id,
            if (localId.isNotEmpty) 'idempotency_key': localId,
            'uploaded_at': DateTime.now().toIso8601String(),
          }..remove('sync_error'));
        } else {
          failed++;
          final error = _holdError(response);
          await OfflineStore.instance.log('error', 'Commande impayée : $error');
          final failedHold = <String, dynamic>{
            ...hold,
            'sync_error': error,
          };
          if (serverId.isNotEmpty) failedHold['server_id'] = serverId;
          failedHold.remove('uploaded_at');
          updated.add(failedHold);
        }
      } catch (error) {
        failed++;
        updated.add({
          ...hold,
          'sync_error': _syncFailure(error),
        }..remove('uploaded_at'));
      }
    }
    await OfflineStore.instance.saveLocalHolds(updated);
    return failed;
  }

  Future<http.Response> _sendHold(
    String target,
    String storeId,
    String serverId,
    Map<String, dynamic> payload,
  ) {
    final creating = serverId.isEmpty;
    final uri = creating
        ? Uri.parse('$target/stores/$storeId/sales/holds')
        : Uri.parse('$target/sales/$serverId');
    final body = jsonEncode(payload);
    final request = creating
        ? _client.post(uri, headers: _headers, body: body)
        : _client.put(uri, headers: _headers, body: body);
    return request.timeout(const Duration(seconds: 20));
  }

  Future<Map<String, dynamic>> _holdPayload(Map<String, dynamic> hold, List<Map<String, dynamic>> items) async {
    final notes = (hold['notes'] ?? hold['note'])?.toString().trim() ?? '';
    final tableId = hold['table_id']?.toString().trim() ?? '';
    final customerId = await _holdCustomerId(hold['customer_id']);
    final localId = hold['id']?.toString().trim() ?? '';
    final discountAmount = syncAsInt(hold['discount_amount']);
    final discountPercent = double.tryParse('${hold['discount_percent'] ?? ''}') ?? 0;
    return {
      'items': items,
      if (localId.isNotEmpty) 'idempotency_key': localId,
      if (customerId != null) 'customer_id': customerId,
      if (notes.isNotEmpty) 'notes': notes,
      if (tableId.isNotEmpty) 'table_id': tableId,
      if (discountAmount > 0) 'global_discount': {'type': 'fixed', 'value': discountAmount},
      if (discountAmount <= 0 && discountPercent > 0)
        'global_discount': {'type': 'percent', 'value': discountPercent},
    };
  }

  List<Map<String, dynamic>> _holdItems(Map<String, dynamic> hold) {
    final raw = hold['items'];
    if (raw is! List) return const [];
    final items = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final item = Map<String, dynamic>.from(entry);
      final productId = item['product_id']?.toString().trim() ?? '';
      final quantity = syncAsInt(item['quantity']);
      if (productId.isEmpty || quantity < 1) continue;
      final discount = syncAsInt(item['line_discount_fixed']);
      items.add({
        'product_id': productId,
        'quantity': quantity,
        if (item['unit_price'] != null) 'unit_price': syncAsInt(item['unit_price']),
        if ((item['product_variant_id']?.toString().trim().isNotEmpty ?? false))
          'product_variant_id': item['product_variant_id'],
        if ((item['sale_unit_id']?.toString().trim().isNotEmpty ?? false))
          'sale_unit_id': item['sale_unit_id'],
        if (discount > 0) 'line_discount': {'type': 'fixed', 'value': discount},
      });
    }
    return items;
  }

  Future<String?> _holdCustomerId(dynamic raw) async {
    final id = raw?.toString().trim() ?? '';
    if (id.isEmpty) return null;
    final customer = await OfflineStore.instance.findCustomer(id);
    if (customer == null) return id;
    if (customer.pending || customer.serverId == null || customer.serverId!.isEmpty) return null;
    return customer.serverId;
  }

  bool _holdAlreadySettled(String error) {
    final text = error.toLowerCase();
    return text.contains('en attente') ||
        text.contains('peuvent être modifiées') ||
        text.contains('déjà payée') ||
        text.contains('already paid');
  }

  String _holdError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        final errors = body['errors'];
        if (errors is Map) {
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) return value.first.toString();
            if (value != null && value.toString().trim().isNotEmpty) return value.toString();
          }
        }
        final message = body['message']?.toString().trim() ?? '';
        if (message.isNotEmpty &&
            message != 'The given data was invalid.' &&
            !message.startsWith('errors.')) {
          return message;
        }
      }
    } catch (_) {}
    return 'HTTP ${response.statusCode}';
  }

  Future<void> _pushShifts() async {
    final target = activeTarget;
    if (target == null || target != _cloudBase) return;
    try {
      await ShiftSync.instance.push(
        postPush: (body) => _authorized(
          () => _client
              .post(Uri.parse('$target/sync/push'), headers: _headers, body: body)
              .timeout(const Duration(seconds: 30)),
        ),
        postAck: (body) => _authorized(
          () => _client
              .post(Uri.parse('$target/sync/ack'), headers: _headers, body: body)
              .timeout(const Duration(seconds: 20)),
        ),
      );
    } catch (error) {
      await OfflineStore.instance.log('error', 'Shifts : ${_syncFailure(error)}');
    }
  }

  Future<int> _drainQueue() async {
    await _pushShifts();
    try {
      return await _drainSales();
    } finally {
      await _pushShifts();
    }
  }

  Future<int> _drainSales() async {
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
    if (response.statusCode != 200) return;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;
    final warehouse = data['sale_warehouse_id']?.toString().trim() ?? '';
    if (warehouse.isNotEmpty) {
      await OfflineStore.instance.setCheckpoint('sale_warehouse_id', warehouse);
    }
    if (target != _internalBase) return;
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
    final PosCatalog catalog;
    try {
      catalog = await PosApiService().fetchCatalog();
    } on TimeoutException {
      return _pullCatalog(replaceAll: true);
    }
    await OfflineStore.instance.cacheCatalog(catalog);
    await OfflineStore.instance.setCheckpoint('catalog_synced_at', DateTime.now().toIso8601String());
    catalogRevision++;
    notifyListeners();
    return (products: catalog.products.length, categories: catalog.categories.length);
  }

  Future<void> refreshCatalogNow() async {
    await _refreshCatalogCounts();
  }

  /// Local stock / catalog rows changed — POS reloads from the SQLite cache.
  ///
  /// Set [bumpRevision] to false after a local sale when stock was already
  /// applied to the product grid; bumping would reload the catalog and can
  /// briefly restore the pre-sale quantity.
  void markCatalogChanged({
    List<Map<String, dynamic>> stock = const [],
    bool bumpRevision = true,
  }) {
    if (bumpRevision) {
      catalogRevision++;
      notifyListeners();
    }
    final config = TerminalConfigRepository.instance.config;
    if (!config.isMaster) return;
    LocalRealtimeHub.instance.publish(RealtimeEvent(
      type: RealtimeEventType.stockUpdated,
      originDeviceId: config.deviceId,
      payload: {
        'stock': stock.isEmpty ? null : stock,
      }..removeWhere((_, value) => value == null),
    ));
  }
}
