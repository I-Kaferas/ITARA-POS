import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../domain/barcode_models.dart';

class BarcodeApiService {
  BarcodeApiService({
    http.Client? client,
    String? authToken,
    String? tenantId,
  })  : _client = client ?? http.Client(),
        _authToken = authToken ?? AppConfig.authToken,
        _tenantId = tenantId ?? AppConfig.tenantId;

  final http.Client _client;
  final String? _authToken;
  final String? _tenantId;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_authToken != null && _authToken.isNotEmpty)
          'Authorization': 'Bearer $_authToken',
        if (_tenantId != null && _tenantId.isNotEmpty) 'X-Tenant-ID': _tenantId,
      };

  Future<BarcodeLookupResult> lookup(String code, {String? storeId}) async {
    final params = {
      'code': code,
      'store_id': ?storeId,
    };
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/barcodes/lookup')
        .replace(queryParameters: params);
    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) {
      return const BarcodeLookupResult(found: false);
    }

    if (response.statusCode != 200) {
      throw Exception('Lookup failed: HTTP ${response.statusCode}');
    }

    return BarcodeLookupResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<BarcodeRecord>> search(String query, {int limit = 25}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/barcodes/search').replace(
      queryParameters: {'q': query, 'limit': '$limit'},
    );
    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Search failed: HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];

    return data
        .map((item) => BarcodeRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<BarcodeRecord> generate(PosBarcodeType type) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/barcodes/generate');
    final response = await _client
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({'type': type.apiValue}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Generate failed: HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return BarcodeRecord.fromJson(data);
  }

  Future<BarcodePrintPayload> printPayload(String barcodeId) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/barcodes/$barcodeId/print');
    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Print payload failed: HTTP ${response.statusCode}');
    }

    return BarcodePrintPayload.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<BarcodeRecord> assignToProduct({
    required String productId,
    required String barcode,
    required PosBarcodeType type,
    bool isPrimary = false,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/products/$productId/barcodes');
    final response = await _client
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'barcode': barcode,
            'type': type.apiValue,
            'is_primary': isPrimary,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 201) {
      throw Exception('Assign failed: HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return BarcodeRecord.fromJson(body['data'] as Map<String, dynamic>);
  }
}
