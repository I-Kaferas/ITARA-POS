import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../sync/offline_store.dart';
import '../../../sync/sync_engine.dart';
import '../../barcode/data/barcode_api_service.dart';
import '../../barcode/domain/barcode_models.dart';
import '../domain/pos_models.dart';

class PosApiService {
  PosApiService({
    http.Client? client,
    String? authToken,
    String? tenantId,
    String? storeId,
    String? apiBaseUrl,
    BarcodeApiService? barcodeApi,
  })  : _client = client ?? http.Client(),
        _authTokenOverride = authToken,
        _tenantIdOverride = tenantId,
        _storeIdOverride = storeId,
        _apiBaseUrlOverride = apiBaseUrl,
        _barcodeApi = barcodeApi ?? BarcodeApiService();

  final http.Client _client;
  final String? _authTokenOverride;
  final String? _tenantIdOverride;
  final String? _storeIdOverride;
  final String? _apiBaseUrlOverride;
  final BarcodeApiService _barcodeApi;

  String get _authToken {
    final value = _authTokenOverride ?? TerminalConfigRepository.instance.config.authToken;
    return value.isNotEmpty ? value : AppConfig.authToken;
  }

  String get _tenantId {
    final value = _tenantIdOverride ?? TerminalConfigRepository.instance.config.tenantId;
    return value.isNotEmpty ? value : AppConfig.tenantId;
  }

  String get _storeId {
    final value = _storeIdOverride ?? TerminalConfigRepository.instance.config.storeId;
    return value.isNotEmpty ? value : AppConfig.storeId;
  }

  String get _apiBaseUrl {
    final override = _apiBaseUrlOverride;
    if (override != null && override.isNotEmpty) return override;
    final configured = TerminalConfigRepository.instance.config.apiBaseUrl;
    return configured.isNotEmpty ? configured : AppConfig.apiBaseUrl;
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_authToken.isNotEmpty) 'Authorization': 'Bearer $_authToken',
        if (_tenantId.isNotEmpty) 'X-Tenant-ID': _tenantId,
        if (_storeId.isNotEmpty) 'X-Store-ID': _storeId,
      };

  String get storeId => _storeId;

  Future<PosCatalog> fetchCatalog() async {
    if (_storeId.isEmpty) {
      throw Exception('STORE_ID is required for POS catalog');
    }

    final uri = Uri.parse(
      '$_apiBaseUrl/stores/$_storeId/pos/catalog',
    );
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Catalog fetch failed: HTTP ${response.statusCode}');
    }

    return PosCatalog.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<PosCustomer>> searchCustomers(String query) async {
    final local = await OfflineStore.instance.searchCustomers(query);
    try {
      final remote = await _searchCustomersRemote(query);
      if (remote.isNotEmpty) {
        await OfflineStore.instance.cacheCustomers(remote, replaceSynced: false);
      }
      return _mergeCustomers(local, remote);
    } catch (_) {
      return local;
    }
  }

  Future<PosCustomer> createCustomer({
    required String name,
    String? phone,
    String? email,
  }) async {
    final customer = await OfflineStore.instance.createLocalCustomer(
      name: name,
      phone: phone,
      email: email,
    );
    unawaited(SyncEngine.instance.runCycle());
    return customer;
  }

  Future<List<PosCustomer>> _searchCustomersRemote(String query) async {
    final uri = Uri.parse('$_apiBaseUrl/customers').replace(
      queryParameters: {
        if (query.trim().isNotEmpty) 'search': query.trim(),
        'active_only': '1',
        'per_page': '20',
      },
    );
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Customer search failed: HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = body['data'];
    final data = raw is List
        ? raw
        : (raw as Map<String, dynamic>?)?['data'] as List<dynamic>? ??
            (raw as Map<String, dynamic>?)?['items'] as List<dynamic>? ??
            [];

    return data
        .whereType<Map>()
        .map((item) => PosCustomer.fromJson(Map<String, dynamic>.from(item)))
        .where((customer) => customer.id.isNotEmpty)
        .toList();
  }

  List<PosCustomer> _mergeCustomers(List<PosCustomer> local, List<PosCustomer> remote) {
    final merged = <String, PosCustomer>{};
    for (final customer in remote) {
      merged[customer.id] = customer;
    }
    for (final customer in local) {
      final key = customer.serverId ?? customer.id;
      merged.putIfAbsent(key, () => customer);
      if (customer.pending) merged[customer.id] = customer;
    }
    final values = merged.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return values;
  }

  Future<BarcodeLookupResult> lookupBarcode(String code) {
    return _barcodeApi.lookup(code, storeId: _storeId.isEmpty ? null : _storeId);
  }

  Future<List<PosPaymentMethod>> fetchPaymentMethods() async {
    final cached = await OfflineStore.instance.loadPaymentMethods();
    try {
      final uri = Uri.parse('$_apiBaseUrl/payments/methods').replace(
        queryParameters: {
          if (_storeId.isNotEmpty) 'store_id': _storeId,
          'pos_only': '1',
        },
      );
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Payment methods fetch failed: HTTP ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      final methods = data
          .whereType<Map>()
          .map((item) => PosPaymentMethod.fromJson(Map<String, dynamic>.from(item)))
          .where((method) => method.value.isNotEmpty)
          .toList();
      if (methods.isEmpty) return cached;
      await OfflineStore.instance.cachePaymentMethods(methods);
      return methods;
    } catch (_) {
      return cached;
    }
  }

  Future<PosCustomerBalance> fetchCustomerBalance(String customerId) async {
    final uri = Uri.parse('$_apiBaseUrl/customers/$customerId/balance');
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Customer balance fetch failed: HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;

    return PosCustomerBalance.fromJson(data);
  }

  Future<Map<String, dynamic>> holdSale(Map<String, dynamic> payload, {String? saleId}) async {
    if (_storeId.isEmpty) throw Exception('STORE_ID is required');
    final uri = saleId == null
        ? Uri.parse('$_apiBaseUrl/stores/$_storeId/sales/holds')
        : Uri.parse('$_apiBaseUrl/sales/$saleId');
    final response = await (saleId == null
            ? _client.post(uri, headers: _headers, body: jsonEncode(payload))
            : _client.put(uri, headers: _headers, body: jsonEncode(payload)))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Mise en attente refusée (HTTP ${response.statusCode})');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>? ?? body;
  }

  Future<List<Map<String, dynamic>>> fetchPendingSales() async {
    if (_storeId.isEmpty) return [];
    final uri = Uri.parse('$_apiBaseUrl/stores/$_storeId/sales').replace(queryParameters: {
      'status': 'pending',
      'limit': '50',
    });
    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is List) {
      return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> fetchSale(String saleId) async {
    final response = await _client
        .get(Uri.parse('$_apiBaseUrl/sales/$saleId'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>? ?? body;
  }

  Future<void> discardHold(String saleId) async {
    await _client
        .delete(Uri.parse('$_apiBaseUrl/sales/$saleId'), headers: _headers)
        .timeout(const Duration(seconds: 12));
  }

  Future<PosSaleResult> createSale({
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> payments,
    String? customerId,
    String? warehouseId,
    String? notes,
    String? dueDate,
    Map<String, dynamic>? installments,
    String? saleId,
  }) async {
    if (_storeId.isEmpty) {
      throw Exception('STORE_ID is required for sale creation');
    }

    final paidAmount = payments.fold<int>(
      0,
      (sum, payment) => sum + ((payment['amount'] as num?)?.toInt() ?? 0),
    );
    final method = payments.isEmpty ? 'cash' : payments.first['method'] as String? ?? 'cash';
    final total = items.fold<int>(0, (sum, item) {
      final price = (item['unit_price'] as num?)?.toInt() ?? 0;
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      return sum + price * qty;
    });

    final result = await OfflineStore.instance.commitSale(
      items: items,
      payments: payments,
      customerId: customerId,
      warehouseId: warehouseId,
      notes: notes,
      dueDate: dueDate,
      installments: installments,
      total: total,
      paidAmount: paidAmount,
      outstandingAmount: total > paidAmount ? total - paidAmount : 0,
      method: method,
      saleId: saleId,
    );

    return result;
  }
}
