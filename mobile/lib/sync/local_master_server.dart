import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/config/terminal_config_repository.dart';
import '../features/hospitality/data/hospitality_store.dart';
import '../features/accounting/data/ledger_store.dart';
import '../features/customers/data/customer_account_store.dart';
import '../features/expenses/data/expense_desk_store.dart';
import '../features/notifications/data/notification_watch.dart';
import '../features/reports/data/reports_store.dart';
import '../features/production/data/production_store.dart';
import '../features/services/data/service_desk_store.dart';
import 'offline_store.dart';

class LocalMasterServer extends ChangeNotifier {
  LocalMasterServer._();

  static final LocalMasterServer instance = LocalMasterServer._();

  static const port = 8001;

  HttpServer? _server;
  Timer? _addressRefresh;
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
      if (path == '/api/v1/health') {
        await _json(request, 200, {
          'status': 'ok',
          'service': 'itara-local-master',
          'role': 'master',
        });
        return;
      }
      if (!_sameShop(request)) {
        await _json(request, 403, {'message': 'Forbidden store access.'});
        return;
      }
      if (path == '/api/v1/auth/pin-login' || path == '/api/v1/auth/refresh') {
        await _json(request, 503, {'message': 'Utilisez le PIN hors ligne. Le cloud est injoignable.'});
        return;
      }
      if (path == '/api/v1/sync/heartbeat' && request.method == 'POST') {
        final body = await _readJson(request);
        _rememberClient(request, body);
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
        _rememberClient(request, body);
        final headerDevice = request.headers.value('x-device-id')?.trim() ?? '';
        final results = <Map<String, dynamic>>[];
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
          results.add(await OfflineStore.instance.acceptRemoteOperation(item));
        }
        await _json(request, 200, {'data': {'results': results}});
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
        final data = switch (body['action']?.toString() ?? '') {
          'pay' => await CustomerAccountStore.instance.pay(customerId, (body['amount'] as num?)?.toInt() ?? 0),
          'redeem' => await CustomerAccountStore.instance.redeem(customerId, (body['points'] as num?)?.toInt() ?? 0),
          'post_sale' => await CustomerAccountStore.instance.postSale(
              customerId: customerId,
              saleId: body['sale_id']?.toString() ?? '',
              total: (body['total'] as num?)?.toInt() ?? 0,
              outstanding: (body['outstanding'] as num?)?.toInt() ?? 0,
              payments: (body['payments'] as List<dynamic>? ?? []).whereType<Map>().map(Map<String, dynamic>.from).toList(),
              reference: body['reference']?.toString(),
            ),
          _ => await CustomerAccountStore.instance.account(customerId),
        };
        await _json(request, 200, {'data': data});
        return;
      }
      if (path == '/api/v1/notifications/actions' && request.method == 'POST') {
        await _json(request, 200, {'data': await NotificationWatch.instance.snapshot()});
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
      if (path == '/api/v1/hospitality/actions' && request.method == 'POST') {
        final body = await _readJson(request);
        final action = body['action']?.toString() ?? '';
        final data = action == 'snapshot'
            ? await HospitalityStore.instance.snapshot()
            : await HospitalityStore.instance.apply(body);
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
    request.response.headers.set('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Tenant-ID, X-Store-ID, X-Device-ID, X-Device-Name');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS');
    if (status != 204) {
      request.response.write(jsonEncode(body));
    }
    await request.response.close();
  }

  void _rememberClient(HttpRequest request, Map<String, dynamic> body) {
    final id = body['device_id']?.toString().trim().isNotEmpty == true
        ? body['device_id'].toString().trim()
        : request.headers.value('x-device-id')?.trim() ?? '';
    if (id.isEmpty) return;
    final name = body['name']?.toString().trim() ?? '';
    clients[id] = LocalMasterClient(
      id: id,
      name: name.isEmpty ? id : name,
      pending: (body['pending'] as num?)?.toInt() ?? clients[id]?.pending ?? 0,
      seenAt: DateTime.now(),
    );
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
  });

  final String id;
  final String name;
  final int pending;
  final DateTime seenAt;
}
