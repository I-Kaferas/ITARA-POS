class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
    required this.createdAt,
    this.supplierName,
    this.warehouseName,
    this.currencyCode = 'USD',
    this.notes,
    this.expectedAt,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    final supplier = json['supplier'] as Map<String, dynamic>?;
    final warehouse = json['warehouse'] as Map<String, dynamic>?;

    return PurchaseOrder(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String? ?? '—',
      status: json['status'] as String? ?? 'draft',
      total: _int(json['total']),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      supplierName: supplier?['name'] as String?,
      warehouseName: warehouse?['name'] as String?,
      currencyCode: json['currency_code'] as String? ?? 'USD',
      notes: json['notes'] as String?,
      expectedAt: json['expected_at'] != null
          ? DateTime.tryParse(json['expected_at'] as String)
          : null,
    );
  }

  final String id;
  final String orderNumber;
  final String status;
  final int total;
  final DateTime createdAt;
  final String? supplierName;
  final String? warehouseName;
  final String currencyCode;
  final String? notes;
  final DateTime? expectedAt;

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class PaginatedOrders {
  const PaginatedOrders({required this.items, required this.total});

  factory PaginatedOrders.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final items = (data['data'] as List<dynamic>? ?? [])
        .map((e) => PurchaseOrder.fromJson(e as Map<String, dynamic>))
        .toList();

    return PaginatedOrders(
      items: items,
      total: _int(data['total']),
    );
  }

  final List<PurchaseOrder> items;
  final int total;

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class PurchaseInvoice {
  const PurchaseInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.total,
    required this.paidAmount,
    required this.invoicedAt,
    this.supplierName,
    this.orderNumber,
  });

  factory PurchaseInvoice.fromJson(Map<String, dynamic> json) {
    final supplier = json['supplier'] as Map<String, dynamic>?;
    final order = json['purchase_order'] as Map<String, dynamic>?;

    return PurchaseInvoice(
      id: json['id'] as String,
      invoiceNumber: json['invoice_number'] as String? ?? '—',
      status: json['status'] as String? ?? 'posted',
      total: _int(json['total']),
      paidAmount: _int(json['paid_amount']),
      invoicedAt: DateTime.tryParse(json['invoiced_at'] as String? ?? '') ?? DateTime.now(),
      supplierName: supplier?['name'] as String?,
      orderNumber: order?['order_number'] as String?,
    );
  }

  final String id;
  final String invoiceNumber;
  final String status;
  final int total;
  final int paidAmount;
  final DateTime invoicedAt;
  final String? supplierName;
  final String? orderNumber;

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class PaginatedInvoices {
  const PaginatedInvoices({required this.items, required this.total});

  factory PaginatedInvoices.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final items = (data['data'] as List<dynamic>? ?? [])
        .map((e) => PurchaseInvoice.fromJson(e as Map<String, dynamic>))
        .toList();

    return PaginatedInvoices(
      items: items,
      total: _int(data['total']),
    );
  }

  final List<PurchaseInvoice> items;
  final int total;

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
