import '../../../core/api/api_client.dart';
import '../domain/receipt_models.dart';

class ReceiptApiService {
  ReceiptApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<ReceiptPrintPayload> fetchReceiptPayload(
    String saleId, {
    ReceiptDocumentFormat format = ReceiptDocumentFormat.thermal80,
  }) async {
    final body = await _client.get('/sales/$saleId/receipt?format=${format.value}');
    return ReceiptPrintPayload.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<ReceiptIssueResult> issueReceipt(
    String saleId, {
    ReceiptDocumentFormat format = ReceiptDocumentFormat.thermal80,
    String? deviceId,
    bool reprint = false,
  }) async {
    final body = await _client.post(
      '/sales/$saleId/receipt',
      body: {
        'format': format.value,
        if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
        'reprint': reprint,
      },
    );
    return ReceiptIssueResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<ReceiptPrintPayload> fetchInvoicePayload(
    String saleId, {
    ReceiptDocumentFormat format = ReceiptDocumentFormat.a4,
  }) async {
    final body = await _client.get('/sales/$saleId/invoice?format=${format.value}');
    return ReceiptPrintPayload.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<InvoiceIssueResult> issueInvoice(
    String saleId, {
    ReceiptDocumentFormat format = ReceiptDocumentFormat.a4,
  }) async {
    final body = await _client.post(
      '/sales/$saleId/invoice',
      body: {'format': format.value},
    );
    return InvoiceIssueResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<List<ReceiptDocumentFormat>> fetchFormats() async {
    final body = await _client.get('/receipt-formats');
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ReceiptDocumentFormat.fromString((e as Map)['value'] as String))
        .toList();
  }
}
