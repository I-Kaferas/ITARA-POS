import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/terminal_config_repository.dart';

class PinAuthService {
  PinAuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static Future<bool>? _refreshing;

  Future<({String name, String id, String token, String refreshToken, int expiresIn})> login(String pin) async {
    final config = TerminalConfigRepository.instance.config;
    if (config.tenantId.isEmpty) {
      throw Exception('Tenant ID manquant. Configurez le terminal.');
    }

    final bases = [
      if (config.internalApiBaseUrl.trim().isNotEmpty)
        config.internalApiBaseUrl.trim().replaceAll(RegExp(r'/$'), ''),
      config.apiBaseUrl.replaceAll(RegExp(r'/$'), ''),
    ];

    http.Response? response;
    Object? lastError;
    for (final base in bases) {
      try {
        response = await _client
            .post(
              Uri.parse('$base/auth/pin-login'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'X-Tenant-ID': config.tenantId,
              },
              body: jsonEncode({
                'pin': pin,
                'device_name': config.deviceName.isEmpty ? 'pos-mobile' : config.deviceName,
              }),
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200 || response.statusCode == 422) break;
      } catch (error) {
        lastError = error;
      }
    }

    if (response == null) {
      throw Exception(lastError?.toString() ?? 'Serveur injoignable');
    }

    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}

    if (response.statusCode != 200) {
      final errors = body['errors'] as Map<String, dynamic>?;
      final pinError = (errors?['pin'] as List?)?.first?.toString();
      throw Exception(pinError ?? body['message']?.toString() ?? 'PIN refusé');
    }

    final user = body['user'] as Map<String, dynamic>? ?? {};
    final token = body['access_token'] as String? ?? '';
    if (token.isEmpty) {
      throw Exception('Jeton d\'accès absent');
    }

    return (
      name: user['name'] as String? ?? 'Caissier',
      id: user['id'] as String? ?? '',
      token: token,
      refreshToken: body['refresh_token'] as String? ?? '',
      expiresIn: (body['expires_in'] as num?)?.toInt() ?? 3600,
    );
  }

  static Future<bool> refreshIfNeeded({bool force = false}) {
    final pending = _refreshing;
    if (pending != null) return pending;
    final run = _refreshIfNeeded(force: force);
    _refreshing = run;
    return run.whenComplete(() {
      if (identical(_refreshing, run)) _refreshing = null;
    });
  }

  static Future<bool> _refreshIfNeeded({required bool force}) async {
    final repo = TerminalConfigRepository.instance;
    final config = repo.config;
    final refreshToken = config.refreshToken.trim();
    if (refreshToken.isEmpty) return !force && config.authToken.trim().isNotEmpty;

    final expiresAt = DateTime.tryParse(config.tokenExpiresAt);
    final stillValid = expiresAt != null && expiresAt.isAfter(DateTime.now().add(const Duration(seconds: 90)));
    if (!force && stillValid && config.authToken.trim().isNotEmpty) return true;

    final bases = [
      if (config.internalApiBaseUrl.trim().isNotEmpty)
        config.internalApiBaseUrl.trim().replaceAll(RegExp(r'/$'), ''),
      config.apiBaseUrl.replaceAll(RegExp(r'/$'), ''),
    ];

    for (final base in bases.toSet()) {
      try {
        final response = await http
            .post(
              Uri.parse('$base/auth/refresh'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                if (config.tenantId.isNotEmpty) 'X-Tenant-ID': config.tenantId,
              },
              body: jsonEncode({'refresh_token': refreshToken}),
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) continue;
        final access = (decoded['access_token'] as String? ?? '').trim();
        if (access.isEmpty) continue;
        final nextRefresh = (decoded['refresh_token'] as String? ?? '').trim();
        final expiresIn = (decoded['expires_in'] as num?)?.toInt() ?? 3600;
        await repo.save(repo.config.copyWith(
          authToken: access,
          refreshToken: nextRefresh.isEmpty ? refreshToken : nextRefresh,
          tokenExpiresAt: DateTime.now().add(Duration(seconds: expiresIn)).toIso8601String(),
        ));
        return true;
      } catch (_) {}
    }
    return false;
  }

  static Future<void> signOut() async {
    final repo = TerminalConfigRepository.instance;
    try {
      await PinAuthService().logout();
    } catch (_) {}
    await repo.save(repo.config.copyWith(
      authToken: '',
      refreshToken: '',
      tokenExpiresAt: '',
      cashierId: '',
      cashierName: '',
      isSignedIn: false,
    ));
  }

  Future<void> logout() async {
    final config = TerminalConfigRepository.instance.config;
    if (config.authToken.isEmpty) return;
    final base = config.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    try {
      await _client
          .post(
            Uri.parse('$base/auth/logout'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer ${config.authToken}',
              if (config.tenantId.isNotEmpty) 'X-Tenant-ID': config.tenantId,
            },
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }
}
