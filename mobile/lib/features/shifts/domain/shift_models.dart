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
    required this.status,
    required this.openingBalance,
    required this.openedAt,
    this.salesTotal = 0,
    this.cashInTotal = 0,
    this.cashOutTotal = 0,
    this.expensesTotal = 0,
    this.expectedCash = 0,
    this.actualCash,
    this.variance,
    this.openingNotes,
    this.closingNotes,
    this.closedAt,
    this.openedByName,
    this.openedById,
  });

  factory CashRegisterSession.fromJson(Map<String, dynamic> json) {
    final openedBy = json['opened_by_user'] as Map<String, dynamic>?;
    return CashRegisterSession(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'open',
      openingBalance: _int(json['opening_balance']),
      openedAt: DateTime.tryParse(json['opened_at'] as String? ?? '') ?? DateTime.now(),
      salesTotal: _int(json['sales_total']),
      cashInTotal: _int(json['cash_in_total']),
      cashOutTotal: _int(json['cash_out_total']),
      expensesTotal: _int(json['expenses_total']),
      expectedCash: _int(json['expected_cash']),
      actualCash: json['actual_cash'] != null ? _int(json['actual_cash']) : null,
      variance: json['variance'] != null ? _int(json['variance']) : null,
      openingNotes: json['opening_notes'] as String?,
      closingNotes: json['closing_notes'] as String?,
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'] as String)
          : null,
      openedByName: openedBy?['name'] as String?,
      openedById: json['user_id']?.toString(),
    );
  }

  final String id;
  final String status;
  final int openingBalance;
  final DateTime openedAt;
  final int salesTotal;
  final int cashInTotal;
  final int cashOutTotal;
  final int expensesTotal;
  final int expectedCash;
  final int? actualCash;
  final int? variance;
  final String? openingNotes;
  final String? closingNotes;
  final DateTime? closedAt;
  final String? openedByName;
  final String? openedById;

  bool get isOpen => status.toLowerCase() == 'open' && closedAt == null;

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class SessionSummary {
  const SessionSummary({
    required this.openingBalance,
    required this.salesTotal,
    required this.cashInTotal,
    required this.cashOutTotal,
    required this.expensesTotal,
    required this.expectedCash,
    this.actualCash,
    this.variance,
    this.invoicesCount = 0,
    this.invoicesTotal = 0,
    this.invoices = const [],
    this.paymentMethods = const [],
    this.openedAt,
    this.closedAt,
    this.handover = const ShiftHandover(),
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    return SessionSummary(
      openingBalance: _int(json['opening_balance']),
      salesTotal: _int(json['sales_total']),
      cashInTotal: _int(json['cash_in_total']),
      cashOutTotal: _int(json['cash_out_total']),
      expensesTotal: _int(json['expenses_total']),
      expectedCash: _int(json['expected_cash']),
      actualCash: json['actual_cash'] != null ? _int(json['actual_cash']) : null,
      variance: json['variance'] != null ? _int(json['variance']) : null,
      invoicesCount: _int(json['invoices_count']),
      invoicesTotal: _int(json['invoices_total']),
      invoices: (json['invoices'] as List<dynamic>? ?? [])
          .map((e) => ShiftInvoice.fromJson(e as Map<String, dynamic>))
          .toList(),
      paymentMethods: (json['payment_methods'] as List<dynamic>? ?? [])
          .map((e) => PaymentMethodBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      openedAt: json['opened_at'] != null
          ? DateTime.tryParse(json['opened_at'] as String)
          : null,
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'] as String)
          : null,
      handover: json['handover'] is Map
          ? ShiftHandover.fromJson(Map<String, dynamic>.from(json['handover'] as Map))
          : const ShiftHandover(),
    );
  }

  final int openingBalance;
  final int salesTotal;
  final int cashInTotal;
  final int cashOutTotal;
  final int expensesTotal;
  final int expectedCash;
  final int? actualCash;
  final int? variance;
  final int invoicesCount;
  final int invoicesTotal;
  final List<ShiftInvoice> invoices;
  final List<PaymentMethodBreakdown> paymentMethods;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final ShiftHandover handover;

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class ShiftInvoice {
  const ShiftInvoice({
    required this.reference,
    required this.total,
    this.completedAt,
    this.currency,
    this.itemCount = 0,
    this.customerName,
    this.method,
    this.outstanding = 0,
    this.discount = 0,
  });

  factory ShiftInvoice.fromJson(Map<String, dynamic> json) {
    return ShiftInvoice(
      reference: json['reference'] as String? ?? '',
      total: SessionSummary._int(json['total']),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      currency: json['currency'] as String?,
      itemCount: SessionSummary._int(json['item_count']),
      customerName: json['customer_name'] as String?,
      method: json['method'] as String?,
      outstanding: SessionSummary._int(json['outstanding_amount']),
      discount: SessionSummary._int(json['discount_total']),
    );
  }

  final String reference;
  final int total;
  final DateTime? completedAt;
  final String? currency;
  final int itemCount;
  final String? customerName;
  final String? method;
  final int outstanding;
  final int discount;
}

class PaymentMethodBreakdown {
  const PaymentMethodBreakdown({
    required this.method,
    required this.label,
    required this.count,
    required this.amount,
  });

  factory PaymentMethodBreakdown.fromJson(Map<String, dynamic> json) {
    return PaymentMethodBreakdown(
      method: json['method'] as String? ?? '',
      label: json['label'] as String? ?? json['method'] as String? ?? '',
      count: SessionSummary._int(json['count']),
      amount: SessionSummary._int(json['amount']),
    );
  }

  final String method;
  final String label;
  final int count;
  final int amount;
}

class ShiftSoldLine {
  const ShiftSoldLine({
    required this.name,
    required this.code,
    required this.sold,
    required this.creditQty,
    required this.remaining,
    required this.total,
  });

  factory ShiftSoldLine.fromJson(Map<String, dynamic> json) {
    return ShiftSoldLine(
      name: json['name']?.toString() ?? 'Article',
      code: json['code']?.toString() ?? '',
      sold: SessionSummary._int(json['sold']),
      creditQty: SessionSummary._int(json['credit_qty']),
      remaining: json['remaining'] == null ? null : SessionSummary._int(json['remaining']),
      total: SessionSummary._int(json['total']),
    );
  }

  final String name;
  final String code;
  final int sold;
  final int creditQty;
  final int? remaining;
  final int total;
}

class ShiftStoreGroup {
  const ShiftStoreGroup({
    required this.id,
    required this.name,
    required this.lines,
  });

  factory ShiftStoreGroup.fromJson(Map<String, dynamic> json) {
    return ShiftStoreGroup(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString().trim().isNotEmpty == true ? json['name'].toString() : 'Magasin',
      lines: (json['lines'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((row) => ShiftSoldLine.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
    );
  }

  final String id;
  final String name;
  final List<ShiftSoldLine> lines;

  int get articlesCount => lines.fold(0, (sum, line) => sum + line.sold);
}

class ShiftHandover {
  const ShiftHandover({
    this.articlesSold = 0,
    this.articlesOnCredit = 0,
    this.ordersCount = 0,
    this.storesCount = 0,
    this.creditSalesTotal = 0,
    this.creditOrdersCount = 0,
    this.currency = 'USD',
    this.stores = const [],
  });

  factory ShiftHandover.fromJson(Map<String, dynamic> json) {
    final stores = (json['stores'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((row) => ShiftStoreGroup.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    return ShiftHandover(
      articlesSold: SessionSummary._int(json['articles_sold']),
      articlesOnCredit: SessionSummary._int(json['articles_on_credit']),
      ordersCount: SessionSummary._int(json['orders_count']),
      storesCount: json.containsKey('stores_count') ? SessionSummary._int(json['stores_count']) : stores.length,
      creditSalesTotal: SessionSummary._int(json['credit_sales_total']),
      creditOrdersCount: SessionSummary._int(json['credit_orders_count']),
      currency: json['currency']?.toString().trim().isNotEmpty == true ? json['currency'].toString() : 'USD',
      stores: stores,
    );
  }

  final int articlesSold;
  final int articlesOnCredit;
  final int ordersCount;
  final int storesCount;
  final int creditSalesTotal;
  final int creditOrdersCount;
  final String currency;
  final List<ShiftStoreGroup> stores;

  int get soldTotal => stores.fold(0, (sum, store) => sum + store.lines.fold(0, (lineSum, line) => lineSum + line.total));
}

class CurrentSessionResponse {
  const CurrentSessionResponse({this.session, this.summary, this.zReport});

  factory CurrentSessionResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data == null) return const CurrentSessionResponse();

    return CurrentSessionResponse(
      session: CashRegisterSession.fromJson(data as Map<String, dynamic>),
      summary: json['summary'] != null
          ? SessionSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : null,
      zReport: json['z_report'] != null
          ? SessionSummary.fromJson(json['z_report'] as Map<String, dynamic>)
          : (json['summary'] != null
              ? SessionSummary.fromJson(json['summary'] as Map<String, dynamic>)
              : null),
    );
  }

  final CashRegisterSession? session;
  final SessionSummary? summary;
  final SessionSummary? zReport;
}

class MovementType {
  const MovementType({
    required this.value,
    required this.label,
    required this.labelFr,
    required this.direction,
  });

  factory MovementType.fromJson(Map<String, dynamic> json) {
    return MovementType(
      value: json['value'] as String,
      label: json['label'] as String? ?? json['value'] as String,
      labelFr: json['label_fr'] as String? ?? json['label'] as String? ?? '',
      direction: json['direction'] as String? ?? 'neutral',
    );
  }

  final String value;
  final String label;
  final String labelFr;
  final String direction;
}

class SessionDepartmentStats {
  const SessionDepartmentStats({
    required this.name,
    required this.orders,
    required this.gross,
    required this.paidInvoices,
    required this.net,
    required this.creditInvoices,
    required this.amountDue,
  });

  final String name;
  final int orders;
  final int gross;
  final int paidInvoices;
  final int net;
  final int creditInvoices;
  final int amountDue;
}

class SessionProductQty {
  const SessionProductQty({required this.name, required this.quantity});

  final String name;
  final int quantity;
}

class SessionPaymentLine {
  const SessionPaymentLine({required this.label, required this.amount});

  final String label;
  final int amount;
}

/// Figures for the closed-shift session performance report.
class SessionPerformance {
  const SessionPerformance({
    required this.companyName,
    required this.website,
    required this.userName,
    required this.sessionCode,
    required this.openedAt,
    required this.closedAt,
    required this.currency,
    required this.stores,
    required this.orders,
    required this.gross,
    required this.paidInvoices,
    required this.collected,
    required this.creditInvoices,
    required this.outstanding,
    required this.departments,
    required this.payments,
    required this.topProducts,
  });

  final String companyName;
  final String website;
  final String userName;
  final String sessionCode;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String currency;
  final int stores;
  final int orders;
  final int gross;
  final int paidInvoices;
  final int collected;
  final int creditInvoices;
  final int outstanding;
  final List<SessionDepartmentStats> departments;
  final List<SessionPaymentLine> payments;
  final List<SessionProductQty> topProducts;
}
