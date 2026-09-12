import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

class HealthService {
  Future<Map<String, dynamic>> checkHealth() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/health');
    final response = await http.get(uri).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Health check failed: HTTP ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
