import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'tenant_branding.dart';

class BrandingService {
  Future<TenantBranding> fetchPublic({
    required String slug,
    String? apiBaseUrl,
  }) async {
    final base = (apiBaseUrl ?? AppConfig.apiBaseUrl).replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/public/tenants/${Uri.encodeComponent(slug.trim().toLowerCase())}/branding');
    final response = await http.get(uri, headers: {'Accept': 'application/json'});

    if (response.statusCode == 404) {
      throw Exception('Tenant introuvable pour ce slug');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Impossible de charger la marque (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Réponse branding invalide');
    }
    return TenantBranding.fromJson(data);
  }
}
