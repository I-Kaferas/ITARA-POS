import '../../../core/api/api_client.dart';
import '../domain/cash_register_models.dart';

class CashRegisterApiService {
  CashRegisterApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  String get _storeId {
    final id = _client.storeId;
    if (id.isEmpty) throw Exception('STORE_ID requis');
    return id;
  }

  Future<List<CashRegister>> fetchRegisters() async {
    final body = await _client.get('/stores/$_storeId/cash-registers');
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => CashRegister.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SessionPayload> currentSession(String registerId) async {
    final body = await _client.get('/cash-registers/$registerId/sessions/current');
    return SessionPayload.fromJson(body);
  }

  Future<SessionPayload> openRegister({
    required String registerId,
    required int openingBalance,
    String? notes,
  }) async {
    final body = await _client.post(
      '/cash-registers/$registerId/sessions/open',
      body: {
        'opening_balance': openingBalance,
        if (notes != null && notes.isNotEmpty) 'opening_notes': notes,
      },
    );
    return SessionPayload.fromJson(body);
  }

  Future<SessionPayload> closeRegister({
    required String registerId,
    required int actualCash,
    String? notes,
    String? varianceReason,
  }) async {
    final body = await _client.post(
      '/cash-registers/$registerId/sessions/close',
      body: {
        'actual_cash': actualCash,
        if (notes != null && notes.isNotEmpty) 'closing_notes': notes,
        if (varianceReason != null && varianceReason.isNotEmpty) 'variance_reason': varianceReason,
      },
    );
    return SessionPayload.fromJson(body);
  }

  Future<RegisterSummary> cashIn({
    required String registerId,
    required int amount,
    String? description,
  }) {
    return _recordMovement(
      registerId: registerId,
      movementType: 'cash_in',
      amount: amount,
      description: description,
    );
  }

  Future<RegisterSummary> cashOut({
    required String registerId,
    required int amount,
    String? description,
  }) {
    return _recordMovement(
      registerId: registerId,
      movementType: 'cash_out',
      amount: amount,
      description: description,
    );
  }

  Future<RegisterSummary> cashAdjustment({
    required String registerId,
    required int amount,
    required String direction,
    String? description,
  }) {
    return _recordMovement(
      registerId: registerId,
      movementType: 'cash_adjustment',
      amount: amount,
      description: description,
      direction: direction,
    );
  }

  Future<SessionPayload> cashCount({
    required String registerId,
    required int actualCash,
    String? notes,
  }) async {
    final body = await _client.post(
      '/cash-registers/$registerId/sessions/count',
      body: {
        'actual_cash': actualCash,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return SessionPayload.fromJson(body);
  }

  Future<SessionPayload> reconciliation(String registerId) async {
    final body = await _client.get('/cash-registers/$registerId/reconciliation');
    return SessionPayload.fromJson(body);
  }

  Future<RegisterSummary> _recordMovement({
    required String registerId,
    required String movementType,
    required int amount,
    String? description,
    String? direction,
  }) async {
    final body = await _client.post(
      '/cash-registers/$registerId/movements',
      body: {
        'movement_type': movementType,
        'amount': amount,
        if (description != null && description.isNotEmpty) 'description': description,
        if (direction != null && direction.isNotEmpty) 'direction': direction,
      },
    );
    return RegisterSummary.fromJson(body['summary'] as Map<String, dynamic>);
  }
}
