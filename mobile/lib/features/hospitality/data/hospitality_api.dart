import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/terminal_config_repository.dart';
import '../../../sync/local_master_server.dart';
import 'hospitality_store.dart';

class HospitalityApi {
  HospitalityApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> snapshot() => _send(const {'action': 'snapshot'});

  Future<Map<String, dynamic>> apply(Map<String, dynamic> action) => _send(action);

  Future<Map<String, dynamic>> _send(Map<String, dynamic> action) async {
    final remote = LocalMasterServer.clientBaseUrl();
    if (remote != null) {
      http.Response? response;
      try {
        final config = TerminalConfigRepository.instance.config;
        response = await _client
            .post(
              Uri.parse('$remote/hospitality/actions'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                if (config.tenantId.isNotEmpty) 'X-Tenant-ID': config.tenantId,
                if (config.storeId.isNotEmpty) 'X-Store-ID': config.storeId,
              },
              body: jsonEncode(action),
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        response = null;
      }
      if (response != null) {
        Map<String, dynamic> map = {};
        try {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic>) map = body;
        } catch (_) {}
        if (response.statusCode != 200) {
          throw Exception(map['message']?.toString() ?? 'Maître local injoignable');
        }
        return map['data'] as Map<String, dynamic>? ?? map;
      }
    }
    if (action['action'] == 'snapshot') return HospitalityStore.instance.snapshot();
    return HospitalityStore.instance.apply(action);
  }
}
