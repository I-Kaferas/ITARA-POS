import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/config/terminal_config_repository.dart';
import '../features/hospitality/data/hospitality_store.dart';
import '../features/accounting/data/ledger_store.dart';
import '../features/customers/data/customer_account_store.dart';
import '../features/expenses/data/expense_desk_store.dart';
import '../features/notifications/data/notification_watch.dart';
import '../features/reports/data/reports_store.dart';
import '../features/production/data/production_store.dart';
import '../features/services/data/service_desk_store.dart';
import 'device_registry.dart';
import 'local_realtime.dart';
import 'master_config_store.dart';
import 'offline_store.dart';
import 'pairing_service.dart';
import 'print_spooler.dart';
import 'sync_numbers.dart';

class LocalMasterServer extends ChangeNotifier {
  LocalMasterServer._();

  static final LocalMasterServer instance = LocalMasterServer._();

  static const port = 8001;

  HttpServer? _server;
  Timer? _addressRefresh;
  Timer? _pruneTimer;
  String? lanAddress;
  String? lastError;
  bool listening = false;
  final clients = <String, LocalMasterClient>{};

  String? get advertiseUrl {
    final host = lanAddress;
    if (host == null || host.isEmpty || !listening) return null;
    return 'http://$host:$port/api/v1';
  }

  static String? clientBaseUrl() {
    final config = TerminalConfigRepository.instance.config;
    if (config.isMaster) return null;
    final explicit = config.internalApiBaseUrl.trim();
    if (explicit.isNotEmpty) return explicit.replaceAll(RegExp(r'/$'), '');
    final host = config.masterHost.trim();
    if (host.isEmpty) return null;
    return baseUrlForHost(host);
  }

  static String baseUrlForHost(String host) {
    var value = host.trim();
    if (value.isEmpty) return '';
    if (!value.contains('://')) value = 'http://$value';
    final uri = Uri.parse(value);
    final resolvedPort = uri.hasPort ? uri.port : port;
    var path = uri.path;
    if (path.isEmpty || path == '/') path = '/api/v1';
    path = path.replaceAll(RegExp(r'/$'), '');
    return '${uri.scheme}://${uri.host}:$resolvedPort$path';
  }

  Future<void> startIfMaster() async {
    final config = TerminalConfigRepository.instance.config;
    if (!config.isMaster) {
      await stop();
      return;
    }
    if (listening && _server != null) return;
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
      _server = server;
      lanAddress = await _lanAddress();
      listening = true;
      lastError = null;
      _addressRefresh?.cancel();
      _addressRefresh = Timer.periodic(const Duration(seconds: 15), (_) => _refreshLanAddress());
      _pruneTimer?.cancel();
      _pruneTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
        await DeviceRegistry.instance.pruneOffline();
        notifyListeners();
      });
      PairingService.instance.startMasterSession();
      LocalRealtimeHub.instance.start();
      PrintSpooler.instance.startWorker();
      unawaited(MasterConfigStore.instance.publishFromLocalTerminal());
      notifyListeners();
      server.listen(_handle, onError: (Object error) {
        lastError = error.toString();
        notifyListeners();
      });
    } catch (error) {
      listening = false;
      lastError = 'API locale indisponible sur le port $port';
      notifyListeners();
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    listening = false;
    lanAddress = null;
    clients.clear();
    _addressRefresh?.cancel();
    _addressRefresh = null;
    _pruneTimer?.cancel();
    _pruneTimer = null;
    PairingService.instance.stopMasterSession();
    LocalRealtimeHub.instance.stop();
    PrintSpooler.instance.stopWorker();
    if (server != null) {
      await server.close(force: true);
    }
    notifyListeners();
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (request.method == 'OPTIONS') {
        await _json(request, 204, {});
        return;
      }
      final path = request.uri.path.replaceAll(RegExp(r'/+$'), '');
      if (path == '/api/v1/realtime') {
        await LocalRealtimeHub.instance.accept(request);
        return;
      }
      if (path == '/api/v1/health' || path == '/api/v1/discovery') {
        final config = TerminalConfigRepository.instance.config;
        await _json(request, 200, {
          'status': 'ok',
          'service': 'itara-local-master',
          'type': 'ITARA_MASTER_RESPONSE',
          'role': 'master',
          'master_id': config.deviceId.isNotEmpty ? config.deviceId : config.deviceIdentifier,
          'name': config.deviceName,
          'ip': lanAddress,
          'port': port,
          'tenant_id': config.tenantId,
          'branch_id': config.storeId,
          'store_id': config.storeId,
          'version': AppConfig.appVersion,
          'print_server': true,
        });
        return;
      }
      if (path == '/api/v1/pair' && request.method == 'POST') {
        if (!_sameShop(request)) {
          await _json(request, 403, {'message': 'Forbidden store access.'});
          return;
        }
        await _handlePair(request);
        return;
      }
      if (!_sameShop(request)) {
        await _json(request, 403, {'message': 'Forbidden store access.'});
        return;
      }
      if (!await _authorizedDevice(request)) {
        await _json(request, 401, {
          'message': 'Appairage requis.',
          'pairing_required': true,
        });
        return;
      }
      if (path == '/api/v1/auth/pin-login' || path == '/api/v1/auth/refresh') {
        await _json(request, 503, {'message': 'Utilisez le PIN hors ligne. Le cloud est injoignable.'});
        return;
      }
      if (path == '/api/v1/devices' && request.method == 'GET') {
        final devices = await DeviceRegistry.instance.list();
        await _json(request, 200, {
          'data': devices.map((d) => d.toJson()).toList(),
        });
        return;
      }
      final revokeMatch = RegExp(r'^/api/v1/devices/([^/]+)/revoke$').firstMatch(path);
      if (revokeMatch != null && request.method == 'POST') {
        await DeviceRegistry.instance.revoke(revokeMatch.group(1)!);
        clients.remove(revokeMatch.group(1)!);
        notifyListeners();
        await _json(request, 200, {'data': {'revoked': true}});
        return;
      }
      final removeMatch = RegExp(r'^/api/v1/devices/([^/]+)/remove$').firstMatch(path);
      if (removeMatch != null && request.method == 'POST') {
        final id = removeMatch.group(1)!;
        await DeviceRegistry.instance.remove(id);
        clients.remove(id);
        LocalRealtimeHub.instance.publish(RealtimeEvent(
          type: RealtimeEventType.deviceDisconnected,
          originDeviceId: id,
          payload: {'device_id': id, 'reason': 'removed'},
        ));
        notifyListeners();
        await _json(request, 200, {'data': {'removed': true}});
        return;
      }
      final renameMatch = RegExp(r'^/api/v1/devices/([^/]+)/rename$').firstMatch(path);
      if (renameMatch != null && request.method == 'POST') {
        final id = renameMatch.group(1)!;
        final body = await _readJson(request);
        final name = body['name']?.toString().trim() ?? '';
        if (name.isEmpty) {
          await _json(request, 422, {'message': 'name is required.'});
          return;
        }
        await DeviceRegistry.instance.rename(id, name);
        notifyListeners();
        final device = await DeviceRegistry.instance.find(id);
        await _json(request, 200, {'data': device?.toJson() ?? {'renamed': true, 'name': name}});
        return;
      }
      final disableMatch = RegExp(r'^/api/v1/devices/([^/]+)/disable$').firstMatch(path);
      if (disableMatch != null && request.method == 'POST') {
        final id = disableMatch.group(1)!;
        await DeviceRegistry.instance.disable(id);
        clients.remove(id);
        LocalRealtimeHub.instance.publishToDevice(
          id,
          RealtimeEvent(
            type: RealtimeEventType.deviceCommand,
            payload: {'action': 'disable', 'device_id': id},
          ),
        );
        notifyListeners();
        await _json(request, 200, {'data': {'disabled': true}});
        return;
      }
      final enableMatch = RegExp(r'^/api/v1/devices/([^/]+)/enable$').firstMatch(path);
      if (enableMatch != null && request.method == 'POST') {
        final id = enableMatch.group(1)!;
        await DeviceRegistry.instance.enable(id);
        notifyListeners();
        await _json(request, 200, {'data': {'enabled': true}});
        return;
      }
      final syncMatch = RegExp(r'^/api/v1/devices/([^/]+)/sync$').firstMatch(path);
      if (syncMatch != null && request.method == 'POST') {
        final id = syncMatch.group(1)!;
        await DeviceRegistry.instance.touch(
          deviceId: id,
          status: LanDeviceStatus.syncing,
        );
        final sent = LocalRealtimeHub.instance.publishToDevice(
          id,
          RealtimeEvent(
            type: RealtimeEventType.deviceCommand,
            payload: {'action': 'sync', 'device_id': id},
          ),
        );
        notifyListeners();
        await _json(request, 200, {'data': {'sync_requested': true, 'delivered': sent > 0}});
        return;
      }
      final reconnectMatch = RegExp(r'^/api/v1/devices/([^/]+)/reconnect$').firstMatch(path);
      if (reconnectMatch != null && request.method == 'POST') {
        final id = reconnectMatch.group(1)!;
        final sent = LocalRealtimeHub.instance.publishToDevice(
          id,
          RealtimeEvent(
            type: RealtimeEventType.deviceCommand,
            payload: {'action': 'reconnect', 'device_id': id},
          ),
        );
        await _json(request, 200, {'data': {'reconnect_requested': true, 'delivered': sent > 0}});
        return;
      }
      final configMatch = RegExp(r'^/api/v1/devices/([^/]+)/send-configuration$').firstMatch(path);
      if (configMatch != null && request.method == 'POST') {
        final id = configMatch.group(1)!;
        final doc = await MasterConfigStore.instance.publishFromLocalTerminal();
        LocalRealtimeHub.instance.publish(RealtimeEvent(
          type: RealtimeEventType.configUpdated,
          payload: {'version': doc['version'], 'device_id': id},
        ));
        final sent = LocalRealtimeHub.instance.publishToDevice(
          id,
          RealtimeEvent(
            type: RealtimeEventType.deviceCommand,
            payload: {
              'action': 'send_configuration',
              'device_id': id,
              'version': doc['version'],
            },
          ),
        );
        await _json(request, 200, {
          'data': {
            'configuration_sent': true,
            'delivered': sent > 0,
            'version': doc['version'],
          },
        });
        return;
      }
      final approveMatch = RegExp(r'^/api/v1/devices/([^/]+)/approve$').firstMatch(path);
      if (approveMatch != null && request.method == 'POST') {
        await DeviceRegistry.instance.setApproved(approveMatch.group(1)!, approved: true);
        notifyListeners();
        await _json(request, 200, {'data': {'approved': true}});
        return;
      }
      if (path == '/api/v1/sync/heartbeat' && request.method == 'POST') {
        final body = await _readJson(request);
        await _rememberClient(request, body, status: LanDeviceStatus.online);
        await _json(request, 200, {
          'data': {
            'status': 'online',
            'server_time': DateTime.now().toIso8601String(),
            'role': 'master',
            'clients': clients.length,
            'stock': await OfflineStore.instance.stockSnapshot(),
          },
        });
        return;
      }
      if (path == '/api/v1/sync/pull' && request.method == 'GET') {
        final storeId = _storeId(request);
        await _json(request, 200, {'data': await OfflineStore.instance.catalogDocument(storeId)});
        return;
      }
      if (path == '/api/v1/sync/references' && request.method == 'GET') {
        await _json(request, 200, {'data': await OfflineStore.instance.referenceDocument()});
        return;
      }
      if (path == '/api/v1/sync/stock' && request.method == 'GET') {
        await _json(request, 200, {
          'data': {
            'stock': await OfflineStore.instance.stockSnapshot(),
          },
        });
        return;
      }
      if (path == '/api/v1/sync/status' && request.method == 'GET') {
        final doc = await OfflineStore.instance.catalogDocument(_storeId(request));
        await _json(request, 200, {
          'data': {
            'store_id': doc['store_id'],
            'server_sequence': doc['server_sequence'],
            'server_time': DateTime.now().toIso8601String(),
          },
        });
        return;
      }
      if (path == '/api/v1/sync/push' && request.method == 'POST') {
        final body = await _readJson(request);
        final operations = body['operations'];
        if (operations is! List) {
          await _json(request, 422, {'message': 'operations is required.'});
          return;
        }
        await _rememberClient(request, body, status: LanDeviceStatus.syncing);
        final headerDevice = request.headers.value('x-device-id')?.trim() ?? '';
        final results = <Map<String, dynamic>>[];
        var stockTouched = false;
        var saleCreated = false;
        var saleUpdated = false;
        var paymentTouched = false;
        for (final operation in operations) {
          if (operation is! Map) continue;
          final item = Map<String, dynamic>.from(operation);
          final payload = item['payload'];
          if (payload is Map) {
            final stamped = Map<String, dynamic>.from(payload);
            if ((stamped['device_id']?.toString() ?? '').isEmpty && headerDevice.isNotEmpty) {
              stamped['device_id'] = headerDevice;
            }
            item['payload'] = stamped;
          }
          final entityType = item['entity_type']?.toString() ?? '';
          final op = item['operation']?.toString() ?? '';
          results.add(await OfflineStore.instance.acceptRemoteOperation(item));
          if (entityType == 'sale' && op == 'create') {
            saleCreated = true;
            final payments = (item['payload'] is Map)
                ? (item['payload'] as Map)['payments']
                : null;
            if (payments is List && payments.isNotEmpty) paymentTouched = true;
          } else if (entityType == 'sale') {
            saleUpdated = true;
          }
          if (entityType == 'payment') paymentTouched = true;
          if (entityType == 'sale' || entityType == 'stock') stockTouched = true;
        }
        if (saleCreated) {
          LocalRealtimeHub.instance.publish(RealtimeEvent(
            type: RealtimeEventType.newSale,
            originDeviceId: headerDevice,
            payload: {'results': results.length},
          ));
        }
        if (saleUpdated) {
          LocalRealtimeHub.instance.publish(RealtimeEvent(
            type: RealtimeEventType.saleUpdated,
            originDeviceId: headerDevice,
            payload: {'results': results.length},
          ));
        }
        if (paymentTouched) {
          LocalRealtimeHub.instance.publish(RealtimeEvent(
            type: RealtimeEventType.paymentReceived,
            originDeviceId: headerDevice,
            payload: {'results': results.length},
          ));
        }
        if (stockTouched) {
          LocalRealtimeHub.instance.publish(RealtimeEvent(
            type: RealtimeEventType.stockUpdated,
            originDeviceId: headerDevice,
            payload: {'stock': await OfflineStore.instance.stockSnapshot()},
          ));
        }
        await _json(request, 200, {'data': {'results': results}});
        return;
      }
      if (path == '/api/v1/config' && request.method == 'GET') {
        await _json(request, 200, {
          'data': await MasterConfigStore.instance.document(),
        });
        return;
      }
      if (path == '/api/v1/config' && request.method == 'PUT') {
        final body = await _readJson(request);
        final saved = await MasterConfigStore.instance.save(body);
        LocalRealtimeHub.instance.publish(RealtimeEvent(
          type: RealtimeEventType.configUpdated,
          payload: {'version': saved['version']},
        ));
        await _json(request, 200, {'data': saved});
        return;
      }
      if (path == '/api/v1/print/printers' && request.method == 'GET') {
        final printers = await PrintSpooler.instance.listPrinters();
        await _json(request, 200, {
          'data': printers.map((p) => p.toJson()).toList(),
        });
        return;
      }
      if (path == '/api/v1/print/printers' && request.method == 'POST') {
        final body = await _readJson(request);
        final printer = await PrintSpooler.instance.upsertPrinter(
          MasterPrinter.fromJson(body),
        );
        await MasterConfigStore.instance.save({
          'printers': (await PrintSpooler.instance.listPrinters())
              .map((p) => p.toJson())
              .toList(),
        });
        LocalRealtimeHub.instance.publish(RealtimeEvent(
          type: RealtimeEventType.configUpdated,
          payload: {'printers': true},
        ));
        await _json(request, 200, {'data': printer.toJson()});
        return;
      }
      if (path == '/api/v1/print/discover' && request.method == 'POST') {
        final found = await PrintSpooler.instance.discoverNetworkPrinters();
        await _json(request, 200, {'data': found});
        return;
      }
      if (path == '/api/v1/print/jobs' && request.method == 'GET') {
        final jobs = await PrintSpooler.instance.listJobs();
        await _json(request, 200, {
          'data': jobs.map((j) => j.toJson()).toList(),
        });
        return;
      }
      if (path == '/api/v1/print/jobs' && request.method == 'POST') {
        final body = await _readJson(request);
        final payload = body['payload'];
        if (payload is! Map) {
          await _json(request, 422, {'message': 'payload is required.'});
          return;
        }
        final stamped = Map<String, dynamic>.from(payload);
        final sourceDevice = request.headers.value('x-device-id')?.trim() ??
            body['source_device_id']?.toString().trim() ??
            '';
        if (sourceDevice.isNotEmpty) {
          stamped['_source_device_id'] = sourceDevice;
        }
        final job = await PrintSpooler.instance.enqueue(
          group: body['group']?.toString() ?? 'cashier',
          documentType: body['document_type']?.toString() ?? 'receipt',
          payload: stamped,
          printerId: body['printer_id']?.toString(),
          categoryId: body['category_id']?.toString() ?? '',
          productId: body['product_id']?.toString() ?? '',
        );
        await _rememberClient(request, {
          'device_id': sourceDevice,
          'name': request.headers.value('x-device-name') ?? '',
        });
        await _json(request, 201, {'data': job.toJson()});
        return;
      }
      if (path == '/api/v1/sync/ack' && request.method == 'POST') {
        final body = await _readJson(request);
        final operations = body['operations'];
        final acknowledged = <String>[];
        final missing = <String>[];
        if (operations is List) {
          for (final operation in operations) {
            if (operation is! Map) continue;
            final item = Map<String, dynamic>.from(operation);
            final id = item['id']?.toString() ?? '';
            final stored = await OfflineStore.instance.remoteOperationStored(
              entityType: item['entity_type']?.toString() ?? 'sale',
              entityId: item['entity_id']?.toString() ?? '',
              serverId: item['server_id']?.toString(),
            );
            if (id.isEmpty) continue;
            if (stored) {
              acknowledged.add(id);
            } else {
              missing.add(id);
            }
          }
        }
        await _json(request, 200, {
          'data': {
            'acknowledged': missing.isEmpty,
            'acknowledged_ids': acknowledged,
            'missing_ids': missing,
          },
        });
        return;
      }
      if (path == '/api/v1/expenses/actions' && request.method == 'POST') {
        final body = await _readJson(request);
        final data = body['action']?.toString() == 'record'
            ? await ExpenseDeskStore.instance.record(body)
            : await ExpenseDeskStore.instance.snapshot();
        await _json(request, 200, {'data': data});
        return;
      }
      if (path == '/api/v1/customer-accounts/actions' && request.method == 'POST') {
        final body = await _readJson(request);
        final customerId = body['customer_id']?.toString() ?? '';
        final action = body['action']?.toString() ?? '';
        final data = switch (action) {
          'pay' => await CustomerAccountStore.instance.pay(customerId, syncAsInt(body['amount'])),
          'redeem' => await CustomerAccountStore.instance.redeem(customerId, syncAsInt(body['points'])),
          'post_sale' => await CustomerAccountStore.instance.postSale(
              customerId: customerId,
              saleId: body['sale_id']?.toString() ?? '',
              total: syncAsInt(body['total']),
              outstanding: syncAsInt(body['outstanding']),
              payments: (body['payments'] as List<dynamic>? ?? []).whereType<Map>().map(Map<String, dynamic>.from).toList(),
              reference: body['reference']?.toString(),
            ),
          _ => await CustomerAccountStore.instance.account(customerId),
        };
        if (action == 'pay' || action == 'post_sale') {
          LocalRealtimeHub.instance.publish(RealtimeEvent(
            type: RealtimeEventType.paymentReceived,
            payload: {'action': action, 'customer_id': customerId},
          ));
        }
        await _json(request, 200, {'data': data});
        return;
      }
      if (path == '/api/v1/notifications/actions' && request.method == 'POST') {
        final data = await NotificationWatch.instance.snapshot();
        LocalRealtimeHub.instance.publish(RealtimeEvent(
          type: RealtimeEventType.notificationCreated,
          payload: {'snapshot': true},
        ));
        await _json(request, 200, {'data': data});
        return;
      }
      if (path == '/api/v1/reports/actions' && request.method == 'POST') {
        final body = await _readJson(request);
        final period = body['period']?.toString() ?? 'day';
        await _json(request, 200, {'data': await ReportsStore.instance.build(period)});
        return;
      }
      if (path == '/api/v1/accounting/actions' && request.method == 'POST') {
        final body = await _readJson(request);
        final data = switch (body['action']?.toString() ?? '') {
          'expense' => await LedgerStore.instance.expense(body),
          'pay_payable' => await LedgerStore.instance.payPayable(body),
          _ => await LedgerStore.instance.snapshot(),
        };
        await _json(request, 200, {'data': data});
        return;
      }
      if (path == '/api/v1/production/actions' && request.method == 'POST') {
        final body = await _readJson(request);
        final action = body['action']?.toString() ?? '';
        final data = action == 'produce'
            ? await ProductionStore.instance.produce(body)
            : await ProductionStore.instance.snapshot();
        await _json(request, 200, {'data': data});
        return;
      }
      if (path == '/api/v1/services/actions' && request.method == 'POST') {
        final body = await _readJson(request);
        final action = body['action']?.toString() ?? '';
        final data = action == 'snapshot'
            ? await ServiceDeskStore.instance.snapshot()
            : await ServiceDeskStore.instance.apply(body);
        await _json(request, 200, {'data': data});
        return;
      }
      if (path == '/api/v1/kitchen' && request.method == 'GET') {
        final snap = await HospitalityStore.instance.snapshot();
        final tickets = (snap['docs'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .where((doc) => doc['kind']?.toString() == 'ticket')
            .toList();
        await _json(request, 200, {'data': {'tickets': tickets}});
        return;
      }
      if ((path == '/api/v1/kitchen' || path == '/api/v1/kitchen/actions') &&
          request.method == 'POST') {
        final body = await _readJson(request);
        final action = body['action']?.toString() ?? 'set_ticket_status';
        final data = await HospitalityStore.instance.apply({
          ...body,
          'action': action,
        });
        final ticketStatus = body['status']?.toString().toLowerCase();
        final eventType = ticketStatus == 'ready'
            ? RealtimeEventType.kitchenOrderReady
            : (action == 'send_course'
                ? RealtimeEventType.kitchenOrderCreated
                : RealtimeEventType.orderUpdated);
        LocalRealtimeHub.instance.publish(RealtimeEvent(
          type: eventType,
          payload: {'action': action, 'data': data},
        ));
        await _json(request, 200, {'data': data});
        return;
      }
      if (path == '/api/v1/hospitality/actions' && request.method == 'POST') {
        final body = await _readJson(request);
        final action = body['action']?.toString() ?? '';
        final data = action == 'snapshot'
            ? await HospitalityStore.instance.snapshot()
            : await HospitalityStore.instance.apply(body);
        final ticketStatus = body['status']?.toString().toLowerCase();
        final eventType = switch (action) {
          'send_course' => RealtimeEventType.kitchenOrderCreated,
          'set_ticket_status' when ticketStatus == 'ready' =>
            RealtimeEventType.kitchenOrderReady,
          'set_ticket_status' => RealtimeEventType.orderUpdated,
          'open_order' => RealtimeEventType.orderCreated,
          'transfer_table' || 'merge_orders' || 'set_status' =>
            RealtimeEventType.tableUpdated,
          'add_line' || 'split_lines' => RealtimeEventType.orderUpdated,
          'pay_check' => RealtimeEventType.paymentReceived,
          '' || 'snapshot' => null,
          _ => RealtimeEventType.orderUpdated,
        };
        if (eventType != null) {
          LocalRealtimeHub.instance.publish(RealtimeEvent(
            type: eventType,
            payload: {'action': action, 'status': ticketStatus, 'data': data},
          ));
          if (action == 'pay_check') {
            LocalRealtimeHub.instance.publish(RealtimeEvent(
              type: RealtimeEventType.orderUpdated,
              payload: {'action': action, 'data': data},
            ));
          }
        }
        await _json(request, 200, {'data': data});
        return;
      }
      if (path == '/api/v1/customers' && request.method == 'GET') {
        await _json(request, 200, {'data': await OfflineStore.instance.customerDocuments()});
        return;
      }
      if (path == '/api/v1/payments/methods' && request.method == 'GET') {
        await _json(request, 200, {'data': await OfflineStore.instance.paymentMethodDocuments()});
        return;
      }
      final catalog = RegExp(r'^/api/v1/stores/([^/]+)/pos/catalog$').firstMatch(path);
      if (catalog != null && request.method == 'GET') {
        await _json(request, 200, {'data': await OfflineStore.instance.catalogDocument(catalog.group(1)!)});
        return;
      }
      final holds = RegExp(r'^/api/v1/stores/([^/]+)/sales/holds$').firstMatch(path);
      if (holds != null && request.method == 'POST') {
        final body = await _readJson(request);
        final id = await OfflineStore.instance.acceptRemoteHold(body);
        await _json(request, 201, {'data': {'id': id}});
        return;
      }
      await _json(request, 404, {'message': 'Not found.'});
    } catch (error) {
      if (!request.response.headers.persistentConnection) return;
      try {
        await _json(request, 500, {
          'message': error.toString().replaceFirst('Exception: ', ''),
        });
      } catch (_) {}
    }
  }

  bool _sameShop(HttpRequest request) {
    final config = TerminalConfigRepository.instance.config;
    final store = request.headers.value('x-store-id')?.trim() ?? '';
    final tenant = request.headers.value('x-tenant-id')?.trim() ?? '';
    if (store.isNotEmpty && config.storeId.isNotEmpty && store != config.storeId) return false;
    if (tenant.isNotEmpty && config.tenantId.isNotEmpty && tenant != config.tenantId) return false;
    return true;
  }

  String _storeId(HttpRequest request) {
    final header = request.headers.value('x-store-id')?.trim() ?? '';
    if (header.isNotEmpty) return header;
    final query = request.uri.queryParameters['store_id']?.trim() ?? '';
    if (query.isNotEmpty) return query;
    return TerminalConfigRepository.instance.config.storeId;
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  Future<void> _json(HttpRequest request, int status, Map<String, dynamic> body) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type, X-Tenant-ID, X-Store-ID, X-Device-ID, X-Device-Name, X-Pair-Token',
    );
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS');
    if (status != 204) {
      request.response.write(jsonEncode(body));
    }
    await request.response.close();
  }

  Future<void> _handlePair(HttpRequest request) async {
    final body = await _readJson(request);
    final code = body['code']?.toString().trim() ?? '';
    final deviceId = body['device_id']?.toString().trim().isNotEmpty == true
        ? body['device_id'].toString().trim()
        : request.headers.value('x-device-id')?.trim() ?? '';
    final remote = request.connectionInfo?.remoteAddress.address ?? '';
    try {
      // AUTHENTICATION → AUTHORIZATION (attend ACCEPT/REJECT Master).
      final decision = await PairingService.instance.submitPairRequest(
        code: code,
        deviceId: deviceId,
        deviceName: body['name']?.toString() ??
            request.headers.value('x-device-name') ??
            '',
        deviceType: body['device_type']?.toString() ?? 'pos',
        os: body['os']?.toString() ?? '',
        ip: remote,
        role: body['role']?.toString() ?? 'slave',
        version: body['version']?.toString() ?? '',
      );

      if (!decision.accepted ||
          decision.pairToken == null ||
          decision.deviceId == null) {
        await _json(request, 403, {
          'message': decision.reason ?? 'Appairage refusé par le Master.',
          'phase': 'authorization',
        });
        return;
      }

      final device = await DeviceRegistry.instance.find(decision.deviceId!);
      final config = TerminalConfigRepository.instance.config;
      clients[decision.deviceId!] = LocalMasterClient(
        id: decision.deviceId!,
        name: device?.name ?? decision.deviceId!,
        pending: 0,
        seenAt: DateTime.now(),
        status: LanDeviceStatus.online,
      );
      notifyListeners();
      final sharedConfig = await MasterConfigStore.instance.document();
      LocalRealtimeHub.instance.publish(RealtimeEvent(
        type: RealtimeEventType.deviceConnected,
        originDeviceId: decision.deviceId!,
        payload: device?.toJson() ?? {'id': decision.deviceId},
      ));
      await _json(request, 200, {
        'data': {
          'pair_token': decision.pairToken,
          'device_id': decision.deviceId,
          'master_id':
              config.deviceId.isNotEmpty ? config.deviceId : config.deviceIdentifier,
          'master_host': lanAddress,
          'master_port': port,
          'config': sharedConfig,
          'phase': 'registered',
        },
      });
    } catch (error) {
      await _json(request, 422, {
        'message': error.toString().replaceFirst('Exception: ', ''),
      });
    }
  }

  /// Allow access when pair token matches an approved device, or when no
  /// paired devices exist yet (bootstrap / first slave).
  Future<bool> _authorizedDevice(HttpRequest request) async {
    final token = request.headers.value('x-pair-token')?.trim() ?? '';
    if (token.isNotEmpty) {
      final device = await DeviceRegistry.instance.findByToken(token);
      if (device == null) return false;
      if (device.status == LanDeviceStatus.blocked) return false;
      return true;
    }

    final devices = await DeviceRegistry.instance.list(includePending: false);
    // Soft bootstrap: until at least one device is paired, allow shop-scoped access.
    if (devices.isEmpty) return true;

    final deviceId = request.headers.value('x-device-id')?.trim() ?? '';
    if (deviceId.isEmpty) return false;
    final known = await DeviceRegistry.instance.find(deviceId);
    if (known == null || !known.approved) return false;
    // Legacy approved device without sending token yet — allow but prefer token.
    return known.pairTokenHash.isEmpty;
  }

  Future<void> _rememberClient(
    HttpRequest request,
    Map<String, dynamic> body, {
    LanDeviceStatus status = LanDeviceStatus.online,
  }) async {
    final id = body['device_id']?.toString().trim().isNotEmpty == true
        ? body['device_id'].toString().trim()
        : request.headers.value('x-device-id')?.trim() ?? '';
    if (id.isEmpty) return;
    final name = body['name']?.toString().trim() ?? '';
    final pending = syncAsIntOrNull(body['pending']) ?? clients[id]?.pending ?? 0;
    final remote = request.connectionInfo?.remoteAddress.address ?? '';
    clients[id] = LocalMasterClient(
      id: id,
      name: name.isEmpty ? id : name,
      pending: pending,
      seenAt: DateTime.now(),
      status: status,
    );
    final existing = await DeviceRegistry.instance.find(id);
    if (existing != null) {
      final branch = body['branch_id']?.toString().trim().isNotEmpty == true
          ? body['branch_id'].toString().trim()
          : body['store_id']?.toString().trim();
      await DeviceRegistry.instance.touch(
        deviceId: id,
        name: name,
        deviceType: body['device_type']?.toString() ?? body['type']?.toString(),
        os: body['os']?.toString(),
        ip: remote,
        tenantId: body['tenant_id']?.toString(),
        branchId: branch,
        storeId: body['store_id']?.toString(),
        userId: body['user_id']?.toString(),
        userName: body['user_name']?.toString() ??
            body['cashier_name']?.toString(),
        role: body['role']?.toString(),
        version: body['app_version']?.toString() ?? body['version']?.toString(),
        status: pending > 0 ? LanDeviceStatus.syncing : status,
        pending: pending,
      );
    }
    notifyListeners();
  }

  Future<void> _refreshLanAddress() async {
    if (!listening) return;
    final next = await _lanAddress();
    if (next == lanAddress) return;
    lanAddress = next;
    notifyListeners();
  }

  Future<String?> _lanAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    String? best;
    var bestScore = -1;
    for (final interface in interfaces) {
      if (_virtualInterface(interface.name)) continue;
      for (final address in interface.addresses) {
        if (address.isLoopback) continue;
        final score = _addressScore(interface.name, address.address);
        if (score > bestScore) {
          bestScore = score;
          best = address.address;
        }
      }
    }
    return best;
  }

  bool _virtualInterface(String name) {
    final value = name.toLowerCase();
    const markers = [
      'virtual',
      'vethernet',
      'vmware',
      'vbox',
      'hyper-v',
      'wsl',
      'docker',
      'bluetooth',
      'tunnel',
      'loopback',
      'npcap',
    ];
    return markers.any(value.contains);
  }

  int _addressScore(String name, String ip) {
    final value = name.toLowerCase();
    var score = 1;
    if (value.contains('wi-fi') || value.contains('wifi') || value.contains('wlan') || value.contains('ethernet')) {
      score += 6;
    }
    if (ip.startsWith('192.168.') || ip.startsWith('10.') || _private172(ip)) score += 4;
    return score;
  }

  bool _private172(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4 || parts[0] != '172') return false;
    final second = int.tryParse(parts[1]) ?? 0;
    return second >= 16 && second <= 31;
  }
}

class LocalMasterClient {
  const LocalMasterClient({
    required this.id,
    required this.name,
    required this.pending,
    required this.seenAt,
    this.status = LanDeviceStatus.online,
  });

  final String id;
  final String name;
  final int pending;
  final DateTime seenAt;
  final LanDeviceStatus status;
}
