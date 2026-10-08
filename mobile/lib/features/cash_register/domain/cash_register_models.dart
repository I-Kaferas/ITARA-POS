class CashRegister {
  const CashRegister({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
    this.openSession,
  });

  factory CashRegister.fromJson(Map<String, dynamic> json) {
    final openSessionJson = json['open_session'] as Map<String, dynamic>?;
    return CashRegister(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      isActive: json['is_active'] as bool? ?? true,
      openSession: openSessionJson != null
          ? CashRegisterSession.fromJson(openSessionJson)
          : null,
    );
  }

  final String id;
  final String name;
  final String code;
  final bool isActive;
  final CashRegisterSession? openSession;

  bool get hasOpenSession => openSession != null;
}

class CashRegisterSession {
  const CashRegisterSession({
    required this.id,
    required this.registerId,
    required this.status,
    required this.openingBalance,
    required this.openedAt,
    this.salesTotal = 0,
    this.cashInTotal = 0,
    this.cashOutTotal = 0,
    this.expensesTotal = 0,
    this.expectedCash = 0,
    this.actualCash,
    this.difference,
    this.openingNotes,
    this.closingNotes,
    this.closedAt,
    this.countedAt,
    this.openedByName,
  });

  factory CashRegisterSession.fromJson(Map<String, dynamic> json) {
    final openedBy = json['opened_by_user'] as Map<String, dynamic>?;
    final expected = _int(json['expected_cash']);
    final actual = json['actual_cash'] != null ? _int(json['actual_cash']) : null;
    final variance = json['variance'] != null ? _int(json['variance']) : null;
    final difference = json['difference'] != null
        ? _int(json['difference'])
        : (actual != null ? actual - expected : variance);

    return CashRegisterSession(
      id: json['id'] as String,
      registerId: json['cash_register_id'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      openingBalance: _int(json['opening_balance']),
      openedAt: DateTime.tryParse(json['opened_at'] as String? ?? '') ?? DateTime.now(),
      salesTotal: _int(json['sales_total']),
      cashInTotal: _int(json['cash_in_total']),
      cashOutTotal: _int(json['cash_out_total']),
      expensesTotal: _int(json['expenses_total']),
      expectedCash: expected,
      actualCash: actual,
      difference: difference,
      openingNotes: json['opening_notes'] as String?,
      closingNotes: json['closing_notes'] as String?,
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'] as String)
          : null,
      countedAt: json['counted_at'] != null
          ? DateTime.tryParse(json['counted_at'] as String)
          : null,
      openedByName: openedBy?['name'] as String?,
    );
  }

  final String id;
  final String registerId;
  final String status;
  final int openingBalance;
  final DateTime openedAt;
  final int salesTotal;
  final int cashInTotal;
  final int cashOutTotal;
  final int expensesTotal;
  final int expectedCash;
  final int? actualCash;
  final int? difference;
  final String? openingNotes;
  final String? closingNotes;
  final DateTime? closedAt;
  final DateTime? countedAt;
  final String? openedByName;

  bool get isOpen => status == 'open';

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class RegisterSummary {
  const RegisterSummary({
    required this.openingBalance,
    required this.salesTotal,
    required this.cashInTotal,
    required this.cashOutTotal,
    required this.expensesTotal,
    required this.expectedCash,
    this.actualCash,
    this.difference,
    this.status,
    this.countedAt,
    this.openedAt,
    this.closedAt,
  });

  factory RegisterSummary.fromJson(Map<String, dynamic> json) {
    final reconciliation = json['reconciliation'] as Map<String, dynamic>?;
    final expected = _int(json['expected_cash'] ?? reconciliation?['expected_cash']);
    final actual = json['actual_cash'] != null
        ? _int(json['actual_cash'])
        : (reconciliation?['actual_cash'] != null ? _int(reconciliation!['actual_cash']) : null);
    final difference = json['difference'] != null
        ? _int(json['difference'])
        : (reconciliation?['difference'] != null
            ? _int(reconciliation!['difference'])
            : (json['variance'] != null
                ? _int(json['variance'])
                : (actual != null ? actual - expected : null)));

    return RegisterSummary(
      openingBalance: _int(json['opening_balance']),
      salesTotal: _int(json['sales_total']),
      cashInTotal: _int(json['cash_in_total']),
      cashOutTotal: _int(json['cash_out_total']),
      expensesTotal: _int(json['expenses_total']),
      expectedCash: expected,
      actualCash: actual,
      difference: difference,
      status: json['status'] as String?,
      countedAt: json['counted_at'] != null
          ? DateTime.tryParse(json['counted_at'] as String)
          : null,
      openedAt: json['opened_at'] != null
          ? DateTime.tryParse(json['opened_at'] as String)
          : null,
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'] as String)
          : null,
    );
  }

  final int openingBalance;
  final int salesTotal;
  final int cashInTotal;
  final int cashOutTotal;
  final int expensesTotal;
  final int expectedCash;
  final int? actualCash;
  final int? difference;
  final String? status;
  final DateTime? countedAt;
  final DateTime? openedAt;
  final DateTime? closedAt;

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class Reconciliation {
  const Reconciliation({
    required this.expectedCash,
    this.actualCash,
    this.difference,
    this.countedAt,
  });

  factory Reconciliation.fromJson(Map<String, dynamic> json) {
    final expected = RegisterSummary._int(json['expected_cash']);
    final actual = json['actual_cash'] != null ? RegisterSummary._int(json['actual_cash']) : null;
    final difference = json['difference'] != null
        ? RegisterSummary._int(json['difference'])
        : (json['variance'] != null
            ? RegisterSummary._int(json['variance'])
            : (actual != null ? actual - expected : null));

    return Reconciliation(
      expectedCash: expected,
      actualCash: actual,
      difference: difference,
      countedAt: json['counted_at'] != null
          ? DateTime.tryParse(json['counted_at'] as String)
          : null,
    );
  }

  final int expectedCash;
  final int? actualCash;
  final int? difference;
  final DateTime? countedAt;
}

class SessionPayload {
  const SessionPayload({this.session, this.summary, this.reconciliation});

  factory SessionPayload.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return SessionPayload(
      session: data is Map<String, dynamic> ? CashRegisterSession.fromJson(data) : null,
      summary: json['summary'] is Map<String, dynamic>
          ? RegisterSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : null,
      reconciliation: json['reconciliation'] is Map<String, dynamic>
          ? Reconciliation.fromJson(json['reconciliation'] as Map<String, dynamic>)
          : null,
    );
  }

  final CashRegisterSession? session;
  final RegisterSummary? summary;
  final Reconciliation? reconciliation;
}
