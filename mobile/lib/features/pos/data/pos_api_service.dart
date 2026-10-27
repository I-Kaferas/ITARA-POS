import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/terminal_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../data/local/document_dao.dart';
import '../../../data/local/local_database.dart';
import '../../../sync/local_master_server.dart';
import '../../../sync/offline_store.dart';
import '../../customers/data/customer_account_store.dart';
import '../../barcode/data/barcode_api_service.dart';
import '../../barcode/domain/barcode_models.dart';
import '../domain/pos_models.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

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
        if (TerminalConfigRepository.instance.config.deviceId.isNotEmpty)
          'X-Device-ID': TerminalConfigRepository.instance.config.deviceId,
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
    final bases = _bases;
    for (var i = 0; i < bases.length; i++) {
      final base = bases[i];
      // A dead local master must not consume the whole wait. The last base
      // (usually the cloud API) gets a longer budget because php artisan serve
      // handles one request at a time.
      final limit = i == bases.length - 1
          ? const Duration(seconds: 30)
          : const Duration(seconds: 6);
      try {
        final response = await _client
            .get(Uri.parse('$base/stores/$_storeId/pos/catalog'), headers: _headers)
            .timeout(limit);
        if (response.statusCode != 200) {
          lastError = Exception('Catalog fetch failed: HTTP ${response.statusCode}');
          continue;
        }
        return PosCatalog.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } on TimeoutException {
        lastError = TimeoutException('Le serveur n’a pas répondu à temps.', limit);
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? Exception('Catalog fetch failed');
  }

  Future<Map<String, String>> fetchPosImages() async {
    if (_storeId.isEmpty) return const {};
    Object? lastError;
    for (final base in _bases) {
      try {
        final response = await _client
            .get(Uri.parse('$base/stores/$_storeId/pos/images'), headers: _headers)
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) {
          lastError = Exception('Image index failed: HTTP ${response.statusCode}');
          continue;
        }
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rows = body['data'] as List<dynamic>? ?? const [];
        final urls = <String, String>{};
        for (final row in rows.whereType<Map>()) {
          final id = row['product_id']?.toString().trim() ?? '';
          final url = row['cdn_url']?.toString().trim() ?? '';
          if (id.isEmpty || url.isEmpty) continue;
          urls[id] = url;
        }
        return urls;
      } catch (error) {
        lastError = error;
      }
    }
    if (lastError != null) throw lastError;
    return const {};
  }

  Future<List<PosCustomer>> searchCustomers(String query) {
    return OfflineStore.instance.searchCustomers(query);
  }

  Future<PosCustomer> createCustomer({
    required String name,
    String? phone,
    String? email,
  }) {
    return OfflineStore.instance.createLocalCustomer(
      name: name,
      phone: phone,
      email: email,
    );
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

  Future<List<Map<String, dynamic>>?> voidLocalSale(String saleId) {
    return OfflineStore.instance.voidUnsyncedSale(saleId);
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
    final body = await _requestOrNull(method: 'GET', path: '/customers/$customerId/loyalty');
    if (body != null) return PosLoyaltySummary.fromJson(body);
    return const PosLoyaltySummary(points: 0, rewardPerPoint: 0);
  }

  Future<PosLoyaltySummary> redeemLoyalty(String customerId, int points) async {
    final body = await _requestOrNull(
      method: 'POST',
      path: '/customers/$customerId/loyalty/redeem',
      body: {'points': points},
    );
    if (body != null) return PosLoyaltySummary.fromJson(body);
    final current = await fetchLoyalty(customerId);
    final left = current.points - points;
    return PosLoyaltySummary(
      points: left < 0 ? 0 : left,
      rewardPerPoint: current.rewardPerPoint,
      tier: current.tier,
    );
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
    String? processedBy,
  }) async {
    if (_storeId.isEmpty) return [];
    final body = await _requestOrNull(
      method: 'GET',
      path: '/stores/$_storeId/sales',
      query: {
        if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (paymentStatus != null && paymentStatus.isNotEmpty) 'payment_status': paymentStatus,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (customerId != null && customerId.isNotEmpty) 'customer_id': customerId,
        if (processedBy != null && processedBy.isNotEmpty) 'processed_by': processedBy,
      },
    );
    if (body != null) return _listOfMaps(body['data']);
    final local = await OfflineStore.instance.listLocalSales(limit: 100);
    final query = search?.trim().toLowerCase() ?? '';
    return local.where((sale) {
      if (status != null && status.isNotEmpty && sale['status']?.toString() != status) return false;
      if (query.isEmpty) return true;
      final reference = sale['reference']?.toString().toLowerCase() ?? '';
      final customer = sale['customer_name']?.toString().toLowerCase() ?? '';
      return reference.contains(query) || customer.contains(query);
    }).toList();
  }

  Future<Map<String, dynamic>> fetchSaleDetail(String id) async {
    final local = await OfflineStore.instance.localSaleById(id);
    if (local != null) return local;
    final body = await _requestJson(method: 'GET', path: '/sales/$id');
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return body;
  }

  Future<Map<String, dynamic>> createReceipt(String saleId) async {
    final local = await _localDocument(saleId, documentType: 'receipt');
    if (local != null) return local;
    final body = await _requestJson(method: 'POST', path: '/sales/$saleId/receipt', body: const {});
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return body;
  }

  Future<Map<String, dynamic>> createInvoice(String saleId) async {
    final local = await _localDocument(saleId, documentType: 'invoice');
    if (local != null) return local;
    final body = await _requestJson(method: 'POST', path: '/sales/$saleId/invoice', body: const {});
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return body;
  }

  Future<List<SaleReturnReason>> fetchReturnReasons() async {
    final body = await _requestOrNull(method: 'GET', path: '/returns/reasons');
    final reasons = body == null
        ? const <SaleReturnReason>[]
        : _listOfMaps(body['data'])
            .map(SaleReturnReason.fromJson)
            .where((reason) => reason.value.isNotEmpty)
            .toList();
    if (reasons.isNotEmpty) return reasons;
    return [
      SaleReturnReason(value: 'customer_changed_mind', label: tr('Changement d’avis')),
      SaleReturnReason(value: 'defective', label: tr('Article défectueux')),
      SaleReturnReason(value: 'wrong_item', label: tr('Mauvais article')),
    ];
  }

  Future<List<SaleReturnRow>> fetchStoreReturns() async {
    if (_storeId.isEmpty) return _localReturns();
    final body = await _requestOrNull(
      method: 'GET',
      path: '/stores/$_storeId/sale-returns',
      query: const {'limit': '100'},
    );
    if (body != null) {
      return _listOfMaps(body['data']).map(SaleReturnRow.fromJson).where((row) => row.id.isNotEmpty).toList();
    }
    return _localReturns();
  }

  Future<SaleReturnRow> createSaleReturn(String saleId, Map<String, dynamic> payload) async {
    final body = await _requestOrNull(
      method: 'POST',
      path: '/sales/$saleId/returns',
      body: payload,
    );
    if (body != null) {
      final data = body['data'];
      return SaleReturnRow.fromJson(data is Map ? Map<String, dynamic>.from(data) : body);
    }
    return _recordLocalReturn(saleId, payload);
  }

  Future<List<MergeCandidate>> mergeCandidates(String saleId) async {
    final body = await _requestOrNull(method: 'GET', path: '/sales/$saleId/merge-candidates');
    if (body != null) {
      return _listOfMaps(body['data'])
          .map(MergeCandidate.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList();
    }
    final local = await OfflineStore.instance.listLocalSales(limit: 40);
    return local
        .where((sale) => sale['id']?.toString() != saleId && sale['status']?.toString() != 'cancelled')
        .map(
          (sale) => MergeCandidate(
            id: sale['id']?.toString() ?? '',
            reference: sale['reference']?.toString() ?? '',
            total: _money(sale['total']),
            currency: sale['currency']?.toString(),
            customer: sale['customer_name'] == null ? null : {'name': sale['customer_name']},
            itemCount: sale['items'] is List ? (sale['items'] as List).length : null,
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<MergePreview> mergePreview(String saleId, List<String> targetIds) async {
    if (targetIds.isEmpty) throw Exception('Au moins une vente cible est requise');
    final body = await _requestOrNull(
      method: 'POST',
      path: '/sales/$saleId/merge/preview',
      body: {
        'source_sale_id': targetIds.first,
        if (targetIds.length > 1) 'target_sale_ids': targetIds,
      },
    );
    if (body != null) return MergePreview.fromJson(body);
    return _localMergePreview(saleId, targetIds);
  }

  Future<Map<String, dynamic>> mergeSales(String saleId, List<String> targetIds) async {
    if (targetIds.isEmpty) throw Exception('Au moins une vente cible est requise');
    final body = await _requestOrNull(
      method: 'POST',
      path: '/sales/$saleId/merge',
      body: {
        'source_sale_id': targetIds.first,
        if (targetIds.length > 1) 'target_sale_ids': targetIds,
      },
    );
    if (body != null) {
      final data = body['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return body;
    }
    await _mergeLocalSales(saleId, targetIds);
    return {'id': saleId, 'merged': targetIds};
  }

  Future<List<PosReservation>> fetchReservations() async {
    if (_storeId.isNotEmpty) {
      final body = await _requestOrNull(method: 'GET', path: '/stores/$_storeId/pos/reservations');
      if (body != null) {
        return _listOfMaps(body['data'])
            .map(PosReservation.fromJson)
            .where((item) => item.id.isNotEmpty)
            .toList();
      }
    }
    return _localReservations();
  }

  Future<PosReservation> createReservation(Map<String, dynamic> payload) async {
    if (_storeId.isNotEmpty) {
      final body = await _requestOrNull(
        method: 'POST',
        path: '/stores/$_storeId/pos/reservations',
        body: payload,
      );
      if (body != null) {
        final data = body['data'];
        return PosReservation.fromJson(data is Map ? Map<String, dynamic>.from(data) : body);
      }
    }
    return _saveLocalReservation(payload);
  }

  Future<PosReservation> updateReservation(String id, Map<String, dynamic> payload) async {
    final body = await _requestOrNull(
      method: 'PATCH',
      path: '/pos-reservations/$id',
      body: payload,
    );
    if (body != null) {
      final data = body['data'];
      return PosReservation.fromJson(data is Map ? Map<String, dynamic>.from(data) : body);
    }
    return _saveLocalReservation({...payload, 'id': id});
  }

  Future<PosReservation> setReservationStatus(String id, String status) async {
    final body = await _requestOrNull(
      method: 'PATCH',
      path: '/pos-reservations/$id/status',
      body: {'status': status},
    );
    if (body != null) {
      final data = body['data'];
      return PosReservation.fromJson(data is Map ? Map<String, dynamic>.from(data) : body);
    }
    final current = await _localReservation(id);
    return _saveLocalReservation({...current, 'id': id, 'status': status});
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
    String? serviceMode,
    String? deliveryAddress,
    String? tableId,
    String? tableLabel,
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
      serviceMode: serviceMode,
      deliveryAddress: deliveryAddress,
      tableId: tableId,
      tableLabel: tableLabel,
    );

    if (customerId != null && customerId.isNotEmpty) {
      unawaited(CustomerAccountStore.instance.postSale(
        customerId: customerId,
        saleId: result.saleId,
        reference: result.reference,
        total: total,
        outstanding: total > paidAmount ? total - paidAmount : 0,
        payments: payments,
      ));
    }
    return result;
  }

  Future<MergePreview> _localMergePreview(String saleId, List<String> targetIds) async {
    final source = await OfflineStore.instance.localSaleById(saleId);
    final targets = <Map<String, dynamic>>[];
    for (final id in targetIds) {
      final sale = await OfflineStore.instance.localSaleById(id);
      if (sale != null) targets.add(sale);
    }
    if (source == null || targets.isEmpty) {
      throw Exception('Ces commandes ne sont pas sur cet appareil.');
    }
    MergeCandidate asCandidate(Map<String, dynamic> sale) => MergeCandidate(
          id: sale['id']?.toString() ?? '',
          reference: sale['reference']?.toString() ?? '',
          total: _money(sale['total']),
          currency: sale['currency']?.toString(),
          customer: sale['customer_name'] == null ? null : {'name': sale['customer_name']},
        );
    final items = <Map<String, dynamic>>[
      ...(source['items'] as List? ?? []).whereType<Map>().map(Map<String, dynamic>.from),
      for (final sale in targets) ...(sale['items'] as List? ?? []).whereType<Map>().map(Map<String, dynamic>.from),
    ];
    final total = _money(source['total']) + targets.fold<int>(0, (sum, sale) => sum + _money(sale['total']));
    return MergePreview(
      source: asCandidate(source),
      target: asCandidate(targets.first),
      items: items,
      totals: {'total': total},
    );
  }

  Future<void> _mergeLocalSales(String saleId, List<String> targetIds) async {
    final source = await OfflineStore.instance.localSaleById(saleId);
    if (source == null) {
      throw Exception('Cette commande n’est pas sur cet appareil.');
    }
    final db = await LocalDatabase.instance.database;
    var addedTotal = 0;
    var addedDue = 0;
    var merged = 0;
    for (final targetId in targetIds) {
      final target = await OfflineStore.instance.localSaleById(targetId);
      if (target == null || targetId == saleId) continue;
      merged += 1;
      addedTotal += _money(target['total']);
      addedDue += _money(target['outstanding_amount']);
      await db.update('sale_items', {'sale_id': saleId}, where: 'sale_id = ?', whereArgs: [targetId]);
      await db.update(
        'sales',
        {'total': 0, 'outstanding_amount': 0, 'sync_status': 'merged'},
        where: 'id = ?',
        whereArgs: [targetId],
      );
    }
    if (merged == 0) {
      throw Exception('Aucune commande locale à fusionner.');
    }
    await db.rawUpdate(
      'UPDATE sales SET total = total + ?, outstanding_amount = outstanding_amount + ? WHERE id = ?',
      [addedTotal, addedDue, saleId],
    );
    OfflineStore.instance.notifySalesChanged();
  }

  Future<Map<String, dynamic>?> _requestOrNull({
    required String method,
    required String path,
    Map<String, String>? query,
    Object? body,
  }) async {
    try {
      return await _requestJson(method: method, path: path, query: query, body: body);
    } catch (_) {
      return null;
    }
  }

  int _money(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('$value') ?? 0;
  }

  Future<Map<String, dynamic>> _localCompany(TerminalConfig config) async {
    final fallback = <String, dynamic>{
      'name': config.brandName.trim().isEmpty ? 'ITARA' : config.brandName.trim(),
      'currency_code': config.currencyCode,
    };
    try {
      final rows = await DataModelDaos.organizations.list(limit: 1);
      if (rows.isEmpty) return fallback;
      final org = rows.first;
      final settings = org['settings'] is Map
          ? Map<String, dynamic>.from(org['settings'] as Map)
          : <String, dynamic>{};
      final name = org['name']?.toString().trim();
      return {
        'name': name == null || name.isEmpty ? fallback['name'] : name,
        'trade_name': org['trade_name'],
        'legal_name': org['legal_name'],
        'tax_id': org['tax_id'],
        'registration_number': org['registration_number'],
        'email': org['email'],
        'logo_url': (settings['invoice_logo_url']?.toString().trim().isNotEmpty ?? false)
            ? settings['invoice_logo_url']
            : org['logo_url'],
        'address': org['address'],
        'currency_code': org['currency_code'] ?? config.currencyCode,
        'fiscal_center': settings['fiscal_center'] ?? settings['dpmc'],
        'activity_sector': settings['activity_sector'],
        'vat_registered': settings['vat_registered'] == true,
        'vat_exempt': settings['vat_status']?.toString() == 'exempt',
        'subject_to_tc': settings['subject_to_tc'] == true,
        'subject_to_pf': settings['subject_to_pf'] == true,
      };
    } catch (_) {
      return fallback;
    }
  }

  Future<Map<String, dynamic>?> _localDocument(String saleId, {required String documentType}) async {
    final sale = await OfflineStore.instance.localSaleById(saleId);
    if (sale == null) return null;
    final config = TerminalConfigRepository.instance.config;
    final reference = sale['reference']?.toString().trim().isNotEmpty == true
        ? sale['reference'].toString()
        : saleId;
    final items = (sale['items'] as List? ?? []).whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      return {
        'name': item['name']?.toString().trim().isNotEmpty == true
            ? item['name'].toString()
            : (item['product_name']?.toString() ?? 'Article'),
        'sku': item['sku']?.toString(),
        'quantity': _money(item['quantity'] ?? 1),
        'unit_price': _money(item['unit_price']),
        'line_discount': _money(item['line_discount']),
        'line_tax': _money(item['line_tax']),
        'line_total': _money(item['line_total']),
      };
    }).toList();
    final payments = (sale['payments'] as List? ?? []).whereType<Map>().map((raw) {
      final payment = Map<String, dynamic>.from(raw);
      final method = payment['method']?.toString() ?? 'cash';
      return {
        'method': method,
        'method_label': payment['method_label']?.toString() ?? method,
        'amount': _money(payment['amount']),
      };
    }).toList();
    final paid = payments.fold<int>(0, (sum, payment) => sum + _money(payment['amount']));
    final total = _money(sale['total']);
    final payload = {
      'document_type': documentType,
      'format': config.printerFormat,
      'company': await _localCompany(config),
      'service_mode': sale['service_mode']?.toString() ?? '',
      'branch': {'name': config.deviceName},
      'document_number': reference,
      'sale_reference': reference,
      'sale_id': sale['id']?.toString() ?? saleId,
      'date': sale['created_at']?.toString() ?? '',
      'cashier': {'name': sale['cashier_name']?.toString() ?? config.cashierName},
      'customer': {
        'name': sale['customer_name']?.toString(),
        'tax_id': sale['customer_tax_id']?.toString(),
      },
      'items': items,
      'subtotal': _money(sale['subtotal'] ?? total),
      'discount_total': _money(sale['discount_total']),
      'tax_total': _money(sale['tax_total']),
      'total': total,
      'currency': sale['currency']?.toString().isNotEmpty == true ? sale['currency'] : config.currencyCode,
      'payments': payments,
      'amount_paid': paid,
      'change': paid > total ? paid - total : 0,
      if (documentType == 'receipt') 'receipt_number': reference,
      if (documentType == 'invoice') 'invoice_number': reference,
    };
    return {'payload': payload};
  }

  Future<SaleReturnRow> _recordLocalReturn(String saleId, Map<String, dynamic> payload) async {
    final sale = await OfflineStore.instance.localSaleById(saleId);
    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    final items = payload['items'];
    var total = 0;
    if (sale != null && items is List) {
      final lines = (sale['items'] as List? ?? []).whereType<Map>().map(Map<String, dynamic>.from).toList();
      for (final raw in items.whereType<Map>()) {
        final itemId = raw['sale_item_id']?.toString() ?? '';
        final qty = _money(raw['quantity']);
        final line = lines.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['id']?.toString() == itemId || item?['sale_item_id']?.toString() == itemId,
          orElse: () => null,
        );
        if (line == null || qty < 1) continue;
        final lineQty = _money(line['quantity']);
        final lineTotal = _money(line['line_total']);
        total += lineQty > 0 ? ((lineTotal * qty) / lineQty).round() : lineTotal;
      }
    }
    final number = 'RET-${now.substring(0, 10).replaceAll('-', '')}-${id.substring(0, 4).toUpperCase()}';
    final document = {
      'id': id,
      'return_number': number,
      'status': 'recorded',
      'reason': payload['reason']?.toString() ?? '',
      'refund_method': payload['refund_method']?.toString() ?? 'cash',
      'total': total,
      'created_at': now,
      'sale_id': saleId,
      'sale': sale == null ? null : {'id': sale['id'], 'reference': sale['reference']},
    };
    final db = await LocalDatabase.instance.database;
    await db.insert('refunds', {
      'id': id,
      'sale_id': saleId,
      'amount': total,
      'method': document['refund_method'],
      'reason': document['reason'],
      'status': 'recorded',
      'json': jsonEncode(document),
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return SaleReturnRow.fromJson(document);
  }

  Future<List<SaleReturnRow>> _localReturns() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query('refunds', orderBy: 'created_at DESC', limit: 100);
    return rows.map((row) {
      Map<String, dynamic> json = {};
      try {
        final decoded = jsonDecode(row['json']?.toString() ?? '{}');
        if (decoded is Map) json = Map<String, dynamic>.from(decoded);
      } catch (_) {}
      return SaleReturnRow.fromJson({
        ...json,
        'id': row['id'],
        'total': row['amount'] ?? json['total'],
        'reason': row['reason'] ?? json['reason'],
        'status': row['status'] ?? json['status'],
        'refund_method': row['method'] ?? json['refund_method'],
        'created_at': row['created_at'] ?? json['created_at'],
      });
    }).where((row) => row.id.isNotEmpty).toList();
  }

  Future<List<PosReservation>> _localReservations() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'hospitality_docs',
      where: 'kind = ?',
      whereArgs: ['pos_reservation'],
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) {
      Map<String, dynamic> json = {};
      try {
        final decoded = jsonDecode(row['json']?.toString() ?? '{}');
        if (decoded is Map) json = Map<String, dynamic>.from(decoded);
      } catch (_) {}
      return PosReservation.fromJson({...json, 'id': row['id'], 'status': row['status'] ?? json['status']});
    }).where((item) => item.id.isNotEmpty).toList();
  }

  Future<Map<String, dynamic>> _localReservation(String id) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'hospitality_docs',
      where: 'id = ? AND kind = ?',
      whereArgs: [id, 'pos_reservation'],
      limit: 1,
    );
    if (rows.isEmpty) return {'id': id};
    try {
      final decoded = jsonDecode(rows.first['json']?.toString() ?? '{}');
      if (decoded is Map) return {...Map<String, dynamic>.from(decoded), 'id': id};
    } catch (_) {}
    return {'id': id};
  }

  Future<PosReservation> _saveLocalReservation(Map<String, dynamic> payload) async {
    final id = payload['id']?.toString().trim().isNotEmpty == true ? payload['id'].toString() : const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    final document = {
      ...payload,
      'id': id,
      'reference': payload['reference']?.toString().trim().isNotEmpty == true
          ? payload['reference']
          : 'RSV-${id.substring(0, 4).toUpperCase()}',
      'guest_name': payload['guest_name'] ?? payload['name'] ?? '',
      'party_size': _money(payload['party_size'] ?? 1),
      'reserved_at': payload['reserved_at']?.toString().isNotEmpty == true ? payload['reserved_at'] : now,
      'status': payload['status']?.toString().isNotEmpty == true ? payload['status'] : 'pending',
    };
    final db = await LocalDatabase.instance.database;
    await db.insert('hospitality_docs', {
      'id': id,
      'kind': 'pos_reservation',
      'status': document['status'],
      'json': jsonEncode(document),
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return PosReservation.fromJson(document);
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
}

