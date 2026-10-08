import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/terminal_config_repository.dart';
import '../features/receipt/domain/receipt_models.dart';
import 'local_master_server.dart';

/// Slave helper: enqueue print jobs on the Master spooler.
class MasterPrintClient {
  MasterPrintClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> enqueueReceipt(
    ReceiptPrintPayload payload, {
    String group = 'cashier',
  }) {
    return enqueue(
      group: group,
      documentType: payload.documentType,
      payload: payload.toJson(),
    );
  }

  Future<Map<String, dynamic>> enqueue({
    required String group,
    required String documentType,
    required Map<String, dynamic> payload,
    String? printerId,
  }) async {
    final base = LocalMasterServer.clientBaseUrl();
    if (base == null || base.isEmpty) {
      throw StateError('Master indisponible pour l’impression centralisée.');
    }
    final config = TerminalConfigRepository.instance.config;
    final response = await _client
        .post(
          Uri.parse('$base/print/jobs'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            if (config.tenantId.isNotEmpty) 'X-Tenant-ID': config.tenantId,
            if (config.storeId.isNotEmpty) 'X-Store-ID': config.storeId,
            if (config.deviceId.isNotEmpty) 'X-Device-ID': config.deviceId,
            if (config.masterPairToken.isNotEmpty)
              'X-Pair-Token': config.masterPairToken,
          },
          body: jsonEncode({
            'group': group,
            'document_type': documentType,
            'printer_id': printerId,
            'payload': payload,
          }),
        )
        .timeout(const Duration(seconds: 12));

    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        body['message']?.toString() ??
            'Échec file d’impression (${response.statusCode})',
      );
    }
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return body;
  }
}
