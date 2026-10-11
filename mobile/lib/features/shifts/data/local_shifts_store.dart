import 'package:uuid/uuid.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../data/local/document_dao.dart';
import '../../../data/local/local_database.dart';
import '../../../sync/sync_numbers.dart';
import '../domain/shift_models.dart';

/// Caisses, shifts et mouvements lus et écrits uniquement en local.
class LocalShiftsStore {
  LocalShiftsStore._();

  static final LocalShiftsStore instance = LocalShiftsStore._();

  static const movementTypes = [
    MovementType(value: 'cash_in', label: 'Cash in', labelFr: 'Entrée', direction: 'in'),
    MovementType(value: 'cash_out', label: 'Cash out', labelFr: 'Sortie', direction: 'out'),
    MovementType(value: 'expense', label: 'Expense', labelFr: 'Dépense', direction: 'out'),
  ];

  /// The open shift for this till, preferring the register already selected.
  Future<({CashRegister register, CashRegisterSession session})?> openShift() async {
    final registers = await fetchRegisters();
    final config = TerminalConfigRepository.instance.config;
    ({CashRegister register, CashRegisterSession session})? fallback;
    for (final register in registers) {
      final session = register.openSession;
      if (session == null || !session.isOpen) continue;
      final match = (
        register: register,
        session: session,
      );
      if (register.id == config.cashRegisterId || session.id == config.cashSessionId) {
        return match;
      }
      fallback ??= match;
    }
    return fallback;
  }

  Future<List<CashRegister>> fetchRegisters() async {
    final storeId = TerminalConfigRepository.instance.config.storeId.trim();
    final rows = await DataModelDaos.cashRegisters.list(
      where: storeId.isEmpty ? null : "store_id = ? OR store_id IS NULL OR store_id = ''",
      whereArgs: storeId.isEmpty ? null : [storeId],
      orderBy: 'name ASC',
    );
    final registers = <CashRegister>[];
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      if (_inactive(row)) continue;
      registers.add(CashRegister(
        id: id,
        name: row['name']?.toString() ?? 'Caisse',
        code: row['code']?.toString() ?? '',
        isActive: true,
        openSession: await _openSession(id),
      ));
    }
    return registers;
  }

  Future<CashRegister> createRegister({
    required String name,
    required String code,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    final storeId = TerminalConfigRepository.instance.config.storeId.trim();
    final document = {
      'id': id,
      'name': name,
      'code': code,
      'is_active': true,
      'store_id': storeId,
      'updated_at': now,
    };
    await DataModelDaos.cashRegisters.upsert(document, columns: {
      'store_id': storeId,
      'code': code,
      'name': name,
      'is_active': 1,
      'updated_at': now,
    });
    return CashRegister(id: id, name: name, code: code, isActive: true);
  }

  Future<CurrentSessionResponse> currentSession(String registerId) async {
    final session = await _openSession(registerId);
    if (session == null) return const CurrentSessionResponse();
    final summary = await _summary(session);
    return CurrentSessionResponse(session: session, summary: summary, zReport: summary);
  }

  Future<CurrentSessionResponse> openSession({
    required String registerId,
    required int openingBalance,
    String? notes,
  }) async {
    final existing = await _openSession(registerId);
    if (existing != null) {
      final summary = await _summary(existing);
      return CurrentSessionResponse(session: existing, summary: summary, zReport: summary);
    }

    final config = TerminalConfigRepository.instance.config;
    final id = const Uuid().v4();
    final now = DateTime.now();
    final openedBy = config.cashierName.trim().isEmpty ? 'Caissier' : config.cashierName.trim();
    final document = {
      'id': id,
      'cash_register_id': registerId,
      'cash_session_id': id,
      'user_id': config.cashierId,
      'status': 'open',
      'opened_at': now.toIso8601String(),
      'opening_balance': openingBalance,
      'opening_notes': notes ?? '',
      'opened_by_user': {'name': openedBy},
    };
    await DataModelDaos.shifts.upsert(document, columns: {
      'cash_register_id': registerId,
      'cash_session_id': id,
      'user_id': config.cashierId,
      'status': 'open',
      'opened_at': now.toIso8601String(),
    });
    await TerminalConfigRepository.instance.save(
      config.copyWith(cashRegisterId: registerId, cashSessionId: id),
    );
    final session = CashRegisterSession.fromJson(document);
    final summary = await _summary(session);
    return CurrentSessionResponse(session: session, summary: summary, zReport: summary);
  }

  Future<CurrentSessionResponse> closeSession({
    required String registerId,
    required int actualCash,
    String? notes,
  }) async {
    final session = await _openSession(registerId);
    if (session == null) {
      throw Exception('Aucun shift ouvert');
    }
    final summary = await _summary(session);
    final variance = actualCash - summary.expectedCash;
    final closedAt = DateTime.now();
    final document = {
      'id': session.id,
      'cash_register_id': registerId,
      'cash_session_id': session.id,
      'status': 'closed',
      'opened_at': session.openedAt.toIso8601String(),
      'closed_at': closedAt.toIso8601String(),
      'opening_balance': session.openingBalance,
      'opening_notes': session.openingNotes,
      'closing_notes': notes ?? '',
      'actual_cash': actualCash,
      'expected_cash': summary.expectedCash,
      'variance': variance,
      'opened_by_user': {'name': session.openedByName ?? ''},
    };
    await DataModelDaos.shifts.upsert(document, columns: {
      'cash_register_id': registerId,
      'cash_session_id': session.id,
      'status': 'closed',
      'opened_at': session.openedAt.toIso8601String(),
      'closed_at': closedAt.toIso8601String(),
    });
    final repo = TerminalConfigRepository.instance;
    if (repo.config.cashSessionId == session.id) {
      await repo.save(repo.config.copyWith(cashSessionId: ''));
    }
    final closed = CashRegisterSession.fromJson(document);
    final report = SessionSummary(
      openingBalance: summary.openingBalance,
      salesTotal: summary.salesTotal,
      cashInTotal: summary.cashInTotal,
      cashOutTotal: summary.cashOutTotal,
      expensesTotal: summary.expensesTotal,
      expectedCash: summary.expectedCash,
      actualCash: actualCash,
      variance: variance,
      invoicesCount: summary.invoicesCount,
      invoicesTotal: summary.invoicesTotal,
      invoices: summary.invoices,
      paymentMethods: summary.paymentMethods,
      openedAt: summary.openedAt,
      closedAt: closedAt,
    );
    return CurrentSessionResponse(session: closed, summary: report, zReport: report);
  }

  Future<List<CashRegisterSession>> fetchSessions(String registerId) async {
    final rows = await DataModelDaos.shifts.list(
      where: 'cash_register_id = ?',
      whereArgs: [registerId],
      orderBy: 'opened_at DESC',
    );
    return rows.map((row) => CashRegisterSession.fromJson(_sessionJson(row))).toList();
  }

  Future<List<MovementType>> fetchMovementTypes() async => movementTypes;

  Future<SessionSummary> recordMovement({
    required String registerId,
    required String movementType,
    required int amount,
    String? description,
  }) async {
    final session = await _openSession(registerId);
    if (session == null) throw Exception('Aucun shift ouvert');
    final now = DateTime.now().toIso8601String();
    final id = const Uuid().v4();
    await DataModelDaos.cashMovements.upsert({
      'id': id,
      'cash_register_id': registerId,
      'cash_session_id': session.id,
      'type': movementType,
      'amount': amount,
      'memo': description ?? '',
      'created_at': now,
    }, columns: {
      'cash_register_id': registerId,
      'cash_session_id': session.id,
      'type': movementType,
      'amount': amount,
      'memo': description ?? '',
      'user_id': TerminalConfigRepository.instance.config.cashierId,
      'created_at': now,
    });
    return _summary(session);
  }

  Future<CashRegisterSession?> _openSession(String registerId) async {
    final rows = await DataModelDaos.shifts.list(
      where: 'cash_register_id = ? AND status = ?',
      whereArgs: [registerId, 'open'],
      orderBy: 'opened_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CashRegisterSession.fromJson(_sessionJson(rows.first));
  }

  Map<String, dynamic> _sessionJson(Map<String, dynamic> row) {
    final openedBy = row['opened_by_user'];
    return {
      ...row,
      'id': row['id']?.toString() ?? row['cash_session_id']?.toString() ?? '',
      'status': row['status']?.toString() ?? 'open',
      'opened_at': row['opened_at']?.toString() ?? DateTime.now().toIso8601String(),
      'opened_by_user': openedBy is Map ? Map<String, dynamic>.from(openedBy) : openedBy,
    };
  }

  Future<SessionSummary> _summary(CashRegisterSession session) async {
    final db = await LocalDatabase.instance.database;
    final sales = await db.query(
      'sales',
      where: 'cash_session_id = ?',
      whereArgs: [session.id],
      orderBy: 'created_at DESC',
    );
    final saleIds = sales.map((row) => row['id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();
    final payments = saleIds.isEmpty
        ? <Map<String, Object?>>[]
        : await db.query(
            'payments',
            where: 'sale_id IN (${List.filled(saleIds.length, '?').join(',')})',
            whereArgs: saleIds,
          );
    final movements = await db.query(
      'cash_movements',
      where: 'cash_session_id = ?',
      whereArgs: [session.id],
    );

    var cashSales = 0;
    final byMethod = <String, ({int count, int amount})>{};
    for (final payment in payments) {
      final method = payment['method']?.toString().trim().isNotEmpty == true
          ? payment['method'].toString()
          : 'cash';
      final amount = syncAsInt(payment['amount']);
      final current = byMethod[method];
      byMethod[method] = (count: (current?.count ?? 0) + 1, amount: (current?.amount ?? 0) + amount);
      if (method == 'cash') cashSales += amount;
    }
    if (byMethod.isEmpty) {
      for (final sale in sales) {
        final method = sale['method']?.toString().trim().isNotEmpty == true
            ? sale['method'].toString()
            : 'cash';
        final amount = syncAsInt(sale['total']);
        final current = byMethod[method];
        byMethod[method] = (count: (current?.count ?? 0) + 1, amount: (current?.amount ?? 0) + amount);
        if (method == 'cash') cashSales += amount;
      }
    }

    var cashIn = 0;
    var cashOut = 0;
    var expenses = 0;
    for (final movement in movements) {
      final amount = syncAsInt(movement['amount']);
      switch (movement['type']?.toString()) {
        case 'cash_in':
          cashIn += amount;
        case 'cash_out':
          cashOut += amount;
        case 'expense':
          expenses += amount;
      }
    }

    final salesTotal = sales.fold<int>(0, (sum, row) => sum + syncAsInt(row['total']));
    final expected = session.openingBalance + cashSales + cashIn - cashOut - expenses;
    return SessionSummary(
      openingBalance: session.openingBalance,
      salesTotal: salesTotal,
      cashInTotal: cashIn,
      cashOutTotal: cashOut,
      expensesTotal: expenses,
      expectedCash: expected,
      invoicesCount: sales.length,
      invoicesTotal: salesTotal,
      invoices: sales
          .map((row) => ShiftInvoice(
                reference: row['reference']?.toString() ?? '',
                total: syncAsInt(row['total']),
                completedAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
              ))
          .toList(),
      paymentMethods: byMethod.entries
          .map((entry) => PaymentMethodBreakdown(
                method: entry.key,
                label: entry.key.replaceAll('_', ' '),
                count: entry.value.count,
                amount: entry.value.amount,
              ))
          .toList(),
      openedAt: session.openedAt,
      closedAt: session.closedAt,
    );
  }

  bool _inactive(Map<String, dynamic> row) {
    final value = row['is_active'];
    return value == 0 || value == false || value == '0';
  }
}
