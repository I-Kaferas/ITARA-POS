import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../config/terminal_config_repository.dart';

class ApiClient {
  ApiClient({
    http.Client? client,
    String? authToken,
    String? tenantId,
    String? storeId,
    String? deviceId,
  })  : _client = client ?? http.Client(),
        _authTokenOverride = authToken,
        _tenantIdOverride = tenantId,
        _storeIdOverride = storeId,
        _deviceIdOverride = deviceId;

  final http.Client _client;
  final String? _authTokenOverride;
  final String? _tenantIdOverride;
  final String? _storeIdOverride;
  final String? _deviceIdOverride;

  TerminalConfigRepository get _repo => TerminalConfigRepository.instance;

  String get storeId => _storeIdOverride ?? _repo.config.storeId;

  Map<String, String> get headers {
    final config = _repo.config;
    final authToken = _authTokenOverride ?? config.authToken;
    final tenantId = _tenantIdOverride ?? config.tenantId;
    final storeId = _storeIdOverride ?? config.storeId;
    final deviceId = _deviceIdOverride ?? config.deviceId;

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      if (tenantId.isNotEmpty) 'X-Tenant-ID': tenantId,
      if (storeId.isNotEmpty) 'X-Store-ID': storeId,
      if (deviceId.isNotEmpty) 'X-Device-ID': deviceId,
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final baseUrl = _repo.config.apiBaseUrl.isNotEmpty
        ? _repo.config.apiBaseUrl
        : AppConfig.apiBaseUrl;
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _getWithRetry(_uri(path, query));
    return _decode(response);
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    http.ClientException? last;
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        return await _client
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 15));
      } on http.ClientException catch (error) {
        last = error;
        if (attempt == 4 || !_isTransient(error)) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }

    throw last ?? http.ClientException('Request failed', uri);
  }

  bool _isTransient(http.ClientException error) {
    final text = error.toString();
    return text.contains('refused') ||
        text.contains('errno = 1225') ||
        text.contains('Connection closed') ||
        text.contains('Connection reset');
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _client
        .post(
          _uri(path),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 15));

    return _decode(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _client
        .patch(
          _uri(path),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 15));

    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final parts = <String>[];
      for (final entry in errors.entries) {
        final value = entry.value;
        if (value is List && value.isNotEmpty) {
          parts.add(value.first.toString());
        } else if (value != null) {
          parts.add(value.toString());
        }
      }
      if (parts.isNotEmpty) {
        throw ApiException(parts.join('\n'), response.statusCode);
      }
    }

    final message = body['message'] as String? ??
        'HTTP ${response.statusCode}: ${response.reasonPhrase}';
    throw ApiException(message, response.statusCode);
  }
}

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
