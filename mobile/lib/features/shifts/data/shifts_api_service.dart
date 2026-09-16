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

  Future<Map<String, dynamic>?> currentCashierShift() async {
    final body = await _client.get('/me/cashier-shifts/current');
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<Map<String, dynamic>> openCashierShiftWithPin({
    required String registerId,
    required String pin,
    required int openingFloat,
    String? notes,
  }) async {
    final body = await _client.post(
      '/cash-registers/$registerId/cashier-shifts/open-with-pin',
      body: {
        'pin': pin,
        'opening_float': openingFloat,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return body;
  }

  Future<Map<String, dynamic>> closeCashierShiftWithPin({
    required String registerId,
    required String pin,
    required int countedCash,
    String? notes,
    String? varianceReason,
  }) async {
    final body = await _client.post(
      '/cash-registers/$registerId/cashier-shifts/close-with-pin',
      body: {
        'pin': pin,
        'counted_cash': countedCash,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (varianceReason != null && varianceReason.isNotEmpty) 'variance_reason': varianceReason,
      },
    );
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return body;
  }

  Future<List<Map<String, dynamic>>> fetchStoreCashierShifts({String? status}) async {
    final body = await _client.get('/stores/$_storeId/cashier-shifts', query: {
      if (status != null && status.isNotEmpty) 'status': status,
    });
    final data = body['data'];
    if (data is List) {
      return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return [];
  }

  Future<SessionSummary> recordCashierMovement({
    required String registerId,
    required String shiftId,
    required String movementType,
    required int amount,
    String? description,
  }) async {
    final body = await _client.post(
      '/cash-registers/$registerId/cashier-shifts/$shiftId/movements',
      body: {
        'movement_type': movementType,
        'amount': amount,
        if (description != null && description.isNotEmpty) 'description': description,
      },
    );
    return SessionSummary.fromJson(body['summary'] as Map<String, dynamic>? ?? body);
  }
}
