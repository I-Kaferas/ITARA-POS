import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../sync/local_master_server.dart';
import '../../../sync/offline_store.dart';
import '../../../sync/sync_engine.dart';
import '../../customers/data/customer_account_store.dart';
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

  List<String> get _bases {
    final cloud = _apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    final local = LocalMasterServer.clientBaseUrl();
    if (local == null || local.isEmpty || local == cloud) return [cloud];
    return [local, cloud];
  }

  Future<PosCatalog> fetchCatalog() async {
    if (_storeId.isEmpty) {
      throw Exception('STORE_ID is required for POS catalog');
    }

    Object? lastError;
    for (final base in _bases) {
      try {
        final response = await _client
            .get(Uri.parse('$base/stores/$_storeId/pos/catalog'), headers: _headers)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          lastError = Exception('Catalog fetch failed: HTTP ${response.statusCode}');
          continue;
        }
        return PosCatalog.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? Exception('Catalog fetch failed');
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
    http.Response? response;
    Object? lastError;
    for (final base in _bases) {
      try {
        final uri = Uri.parse('$base/customers').replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'search': query.trim(),
            'active_only': '1',
            'per_page': '20',
          },
        );
        final attempt = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
        if (attempt.statusCode == 200) {
          response = attempt;
          break;
        }
        lastError = Exception('Customer search failed: HTTP ${attempt.statusCode}');
      } catch (error) {
        lastError = error;
      }
    }
    if (response == null) {
      throw lastError ?? Exception('Customer search failed');
    }

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
      http.Response? response;
      for (final base in _bases) {
        try {
          final uri = Uri.parse('$base/payments/methods').replace(
            queryParameters: {
              if (_storeId.isNotEmpty) 'store_id': _storeId,
              'pos_only': '1',
            },
          );
          final attempt = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
          if (attempt.statusCode == 200) {
            response = attempt;
            break;
          }
        } catch (_) {}
      }
      if (response == null) return cached;

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

  Future<CartCalculation> calculateCart(Map<String, dynamic> payload) async {
    if (_storeId.isEmpty) throw Exception('STORE_ID is required');
    final body = await _requestJson(
      method: 'POST',
      path: '/stores/$_storeId/cart/calculate',
      body: payload,
    );
    return CartCalculation.fromJson(body);
  }

  Future<PosLoyaltySummary> fetchLoyalty(String customerId) async {
    final body = await _requestJson(method: 'GET', path: '/customers/$customerId/loyalty');
    return PosLoyaltySummary.fromJson(body);
  }

  Future<PosLoyaltySummary> redeemLoyalty(String customerId, int points) async {
    final body = await _requestJson(
      method: 'POST',
      path: '/customers/$customerId/loyalty/redeem',
      body: {'points': points},
    );
    return PosLoyaltySummary.fromJson(body);
  }

  Future<PosOverview> fetchOverview() async {
    if (_storeId.isEmpty) throw Exception('STORE_ID is required');
    final body = await _requestJson(method: 'GET', path: '/stores/$_storeId/pos/overview');
    return PosOverview.fromJson(body);
  }

  Future<List<Map<String, dynamic>>> fetchSales({
    String? search,
    String? status,
    String? paymentStatus,
    String? from,
    String? to,
    String? customerId,
  }) async {
    if (_storeId.isEmpty) return [];
    final body = await _requestJson(
      method: 'GET',
      path: '/stores/$_storeId/sales',
      query: {
        if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (paymentStatus != null && paymentStatus.isNotEmpty) 'payment_status': paymentStatus,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (customerId != null && customerId.isNotEmpty) 'customer_id': customerId,
      },
    );
    return _listOfMaps(body['data']);
  }

  Future<Map<String, dynamic>> fetchSaleDetail(String id) async {
    final body = await _requestJson(method: 'GET', path: '/sales/$id');
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return body;
  }

  Future<Map<String, dynamic>> createReceipt(String saleId) async {
    final body = await _requestJson(method: 'POST', path: '/sales/$saleId/receipt', body: const {});
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return body;
  }

  Future<Map<String, dynamic>> createInvoice(String saleId) async {
    final body = await _requestJson(method: 'POST', path: '/sales/$saleId/invoice', body: const {});
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return body;
  }

  Future<List<SaleReturnReason>> fetchReturnReasons() async {
    final body = await _requestJson(method: 'GET', path: '/returns/reasons');
    return _listOfMaps(body['data'])
        .map(SaleReturnReason.fromJson)
        .where((reason) => reason.value.isNotEmpty)
        .toList();
  }

  Future<List<SaleReturnRow>> fetchStoreReturns() async {
    if (_storeId.isEmpty) return [];
    final body = await _requestJson(
      method: 'GET',
      path: '/stores/$_storeId/sale-returns',
      query: const {'limit': '100'},
    );
    return _listOfMaps(body['data']).map(SaleReturnRow.fromJson).where((row) => row.id.isNotEmpty).toList();
  }

  Future<SaleReturnRow> createSaleReturn(String saleId, Map<String, dynamic> payload) async {
    final body = await _requestJson(
      method: 'POST',
      path: '/sales/$saleId/returns',
      body: payload,
    );
    final data = body['data'];
    return SaleReturnRow.fromJson(data is Map ? Map<String, dynamic>.from(data) : body);
  }

  Future<List<MergeCandidate>> mergeCandidates(String saleId) async {
    final body = await _requestJson(method: 'GET', path: '/sales/$saleId/merge-candidates');
    return _listOfMaps(body['data'])
        .map(MergeCandidate.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<MergePreview> mergePreview(String saleId, List<String> targetIds) async {
    if (targetIds.isEmpty) throw Exception('Au moins une vente cible est requise');
    final body = await _requestJson(
      method: 'POST',
      path: '/sales/$saleId/merge/preview',
      body: {
        'source_sale_id': targetIds.first,
        if (targetIds.length > 1) 'target_sale_ids': targetIds,
      },
    );
    return MergePreview.fromJson(body);
  }

  Future<Map<String, dynamic>> mergeSales(String saleId, List<String> targetIds) async {
    if (targetIds.isEmpty) throw Exception('Au moins une vente cible est requise');
    final body = await _requestJson(
      method: 'POST',
      path: '/sales/$saleId/merge',
      body: {
        'source_sale_id': targetIds.first,
        if (targetIds.length > 1) 'target_sale_ids': targetIds,
      },
    );
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return body;
  }

  Future<List<PosReservation>> fetchReservations() async {
    if (_storeId.isEmpty) return [];
    final body = await _requestJson(method: 'GET', path: '/stores/$_storeId/pos/reservations');
    return _listOfMaps(body['data'])
        .map(PosReservation.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<PosReservation> createReservation(Map<String, dynamic> payload) async {
    if (_storeId.isEmpty) throw Exception('STORE_ID is required');
    final body = await _requestJson(
      method: 'POST',
      path: '/stores/$_storeId/pos/reservations',
      body: payload,
    );
    final data = body['data'];
    return PosReservation.fromJson(data is Map ? Map<String, dynamic>.from(data) : body);
  }

  Future<PosReservation> updateReservation(String id, Map<String, dynamic> payload) async {
    final body = await _requestJson(
      method: 'PATCH',
      path: '/pos-reservations/$id',
      body: payload,
    );
    final data = body['data'];
    return PosReservation.fromJson(data is Map ? Map<String, dynamic>.from(data) : body);
  }

  Future<PosReservation> setReservationStatus(String id, String status) async {
    final body = await _requestJson(
      method: 'PATCH',
      path: '/pos-reservations/$id/status',
      body: {'status': status},
    );
    final data = body['data'];
    return PosReservation.fromJson(data is Map ? Map<String, dynamic>.from(data) : body);
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
    int? loyaltyPoints,
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

    final onlinePayload = <String, dynamic>{
      'items': items,
      'payments': payments,
      if (customerId != null && customerId.isNotEmpty) 'customer_id': customerId,
      if (notes != null) 'notes': notes,
      if (saleId != null && saleId.isNotEmpty) 'sale_id': saleId,
      if (loyaltyPoints != null && loyaltyPoints > 0) 'loyalty_points': loyaltyPoints,
      if (warehouseId != null) 'warehouse_id': warehouseId,
      if (dueDate != null) 'due_date': dueDate,
      if (installments != null) 'installments': installments,
    };

    try {
      final online = await _tryOnlineCheckout(onlinePayload);
      if (online != null) {
        if (customerId != null && customerId.isNotEmpty) {
          unawaited(_postCustomerAccount(
            customerId: customerId,
            saleId: online.saleId,
            reference: online.reference,
            total: online.total,
            outstanding: online.outstandingAmount,
            payments: payments,
          ));
        }
        unawaited(SyncEngine.instance.runCycle());
        return online;
      }
    } on _PosHttpException {
      rethrow;
    } catch (_) {}

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

    if (customerId != null && customerId.isNotEmpty) {
      unawaited(_postCustomerAccount(
        customerId: customerId,
        saleId: result.saleId,
        reference: result.reference,
        total: total,
        outstanding: total > paidAmount ? total - paidAmount : 0,
        payments: payments,
      ));
    }
    unawaited(SyncEngine.instance.runCycle());
    return result;
  }

  Future<PosSaleResult?> _tryOnlineCheckout(Map<String, dynamic> payload) async {
    Object? lastNetworkError;
    for (final base in _bases) {
      try {
        final response = await _client
            .post(
              Uri.parse('$base/stores/$_storeId/sales'),
              headers: _headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 25));
        if (response.statusCode == 200 || response.statusCode == 201) {
          return PosSaleResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        }
        if (response.statusCode >= 400 && response.statusCode < 500) {
          throw _PosHttpException('Checkout refusé (HTTP ${response.statusCode})');
        }
        lastNetworkError = Exception('Checkout failed: HTTP ${response.statusCode}');
      } on TimeoutException catch (error) {
        lastNetworkError = error;
      } on SocketException catch (error) {
        lastNetworkError = error;
      } on http.ClientException catch (error) {
        lastNetworkError = error;
      } on _PosHttpException {
        rethrow;
      } catch (error) {
        lastNetworkError = error;
      }
    }
    if (lastNetworkError != null) return null;
    return null;
  }

  Future<Map<String, dynamic>> _requestJson({
    required String method,
    required String path,
    Map<String, String>? query,
    Object? body,
  }) async {
    Object? lastError;
    for (final base in _bases) {
      try {
        final uri = Uri.parse('$base$path').replace(queryParameters: query);
        final http.Response response;
        switch (method) {
          case 'GET':
            response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
          case 'POST':
            response = await _client
                .post(uri, headers: _headers, body: jsonEncode(body ?? const {}))
                .timeout(const Duration(seconds: 20));
          case 'PUT':
            response = await _client
                .put(uri, headers: _headers, body: jsonEncode(body ?? const {}))
                .timeout(const Duration(seconds: 20));
          case 'PATCH':
            response = await _client
                .patch(uri, headers: _headers, body: jsonEncode(body ?? const {}))
                .timeout(const Duration(seconds: 20));
          case 'DELETE':
            response = await _client.delete(uri, headers: _headers).timeout(const Duration(seconds: 12));
          default:
            throw Exception('Unsupported method $method');
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = Exception('Request failed: HTTP ${response.statusCode}');
          continue;
        }
        if (response.body.isEmpty) return <String, dynamic>{};
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return {'data': decoded};
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? Exception('Request failed');
  }

  List<Map<String, dynamic>> _listOfMaps(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    if (raw is Map) {
      final nested = raw['data'] ?? raw['items'];
      if (nested is List) {
        return nested.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      }
    }
    return const [];
  }


  Future<void> _postCustomerAccount({
    required String customerId,
    required String saleId,
    required String reference,
    required int total,
    required int outstanding,
    required List<Map<String, dynamic>> payments,
  }) async {
    final action = {
      'action': 'post_sale',
      'customer_id': customerId,
      'sale_id': saleId,
      'reference': reference,
      'total': total,
      'outstanding': outstanding,
      'payments': payments,
    };
    final remote = LocalMasterServer.clientBaseUrl();
    if (remote != null) {
      try {
        final response = await _client
            .post(
              Uri.parse('$remote/customer-accounts/actions'),
              headers: _headers,
              body: jsonEncode(action),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) return;
      } catch (_) {}
    }
    await CustomerAccountStore.instance.postSale(
      customerId: customerId,
      saleId: saleId,
      total: total,
      outstanding: outstanding,
      payments: payments,
      reference: reference,
    );
  }
}

class _PosHttpException implements Exception {
  _PosHttpException(this.message);
  final String message;

  @override
  String toString() => message;
}

