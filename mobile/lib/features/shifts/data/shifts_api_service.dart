import '../../../core/api/api_client.dart';
import '../domain/shift_models.dart';

class ShiftsApiService {
  ShiftsApiService({ApiClient? client}) : _client = client ?? ApiClient();

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

  Future<CashRegister> createRegister({
    required String name,
    required String code,
  }) async {
    final body = await _client.post(
      '/stores/$_storeId/cash-registers',
      body: {'name': name, 'code': code, 'is_active': true},
    );
    return CashRegister.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<CurrentSessionResponse> currentSession(String registerId) async {
    final body = await _client.get('/cash-registers/$registerId/sessions/current');
    return CurrentSessionResponse.fromJson(body);
  }

  Future<CurrentSessionResponse> openSession({
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
    return CurrentSessionResponse.fromJson(body);
  }

  Future<CurrentSessionResponse> closeSession({
    required String registerId,
    required int actualCash,
    String? notes,
  }) async {
    final body = await _client.post(
      '/cash-registers/$registerId/sessions/close',
      body: {
        'actual_cash': actualCash,
        if (notes != null && notes.isNotEmpty) 'closing_notes': notes,
      },
    );
    return CurrentSessionResponse.fromJson(body);
  }

  Future<List<CashRegisterSession>> fetchSessions(String registerId) async {
    final body = await _client.get('/cash-registers/$registerId/sessions');
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => CashRegisterSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SessionSummary> recordMovement({
    required String registerId,
    required String movementType,
    required int amount,
    String? description,
  }) async {
    final body = await _client.post(
      '/cash-registers/$registerId/movements',
      body: {
        'movement_type': movementType,
        'amount': amount,
        if (description != null && description.isNotEmpty) 'description': description,
      },
    );
    return SessionSummary.fromJson(body['summary'] as Map<String, dynamic>);
  }

  Future<List<MovementType>> fetchMovementTypes() async {
    final body = await _client.get('/registers/movement-types');
    final data = body['data'] as List<dynamic>? ?? [];
    const allowed = {'cash_in', 'cash_out', 'expense'};
    return data
        .map((e) => MovementType.fromJson(e as Map<String, dynamic>))
        .where((t) => allowed.contains(t.value))
        .toList();
  }
}
