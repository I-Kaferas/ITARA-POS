import '../../../core/api/api_client.dart';
import '../domain/order_models.dart';

class OrdersApiService {
  OrdersApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<PaginatedOrders> fetchOrders({
    String? status,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    final body = await _client.get('/purchase-orders', query: {
      'per_page': '50',
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      if (from != null) 'from': _day(from),
      if (to != null) 'to': _day(to),
    });
    return PaginatedOrders.fromJson(body);
  }

  Future<PaginatedInvoices> fetchInvoices({
    String? status,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    final body = await _client.get('/purchase-invoices', query: {
      'per_page': '50',
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      if (from != null) 'from': _day(from),
      if (to != null) 'to': _day(to),
    });
    return PaginatedInvoices.fromJson(body);
  }

  String _day(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
