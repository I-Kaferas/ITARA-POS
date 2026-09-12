enum ReceiptDocumentFormat {
  thermal58('thermal_58'),
  thermal80('thermal_80'),
  a4('a4'),
  pdf('pdf');

  const ReceiptDocumentFormat(this.value);
  final String value;

  static ReceiptDocumentFormat fromString(String value) {
    return ReceiptDocumentFormat.values.firstWhere(
      (f) => f.value == value,
      orElse: () => ReceiptDocumentFormat.thermal80,
    );
  }

  double get paperWidthMm => switch (this) {
        ReceiptDocumentFormat.thermal58 => 58,
        ReceiptDocumentFormat.thermal80 => 80,
        ReceiptDocumentFormat.a4 => 210,
        ReceiptDocumentFormat.pdf => 210,
      };

  bool get isThermal =>
      this == ReceiptDocumentFormat.thermal58 || this == ReceiptDocumentFormat.thermal80;
}

class ReceiptCompany {
  const ReceiptCompany({
    this.name,
    this.legalName,
    this.taxId,
    this.address,
    this.currencyCode,
  });

  factory ReceiptCompany.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReceiptCompany();
    return ReceiptCompany(
      name: json['name'] as String?,
      legalName: json['legal_name'] as String?,
      taxId: json['tax_id'] as String?,
      address: json['address'],
      currencyCode: json['currency_code'] as String?,
    );
  }

  final String? name;
  final String? legalName;
  final String? taxId;
  final dynamic address;
  final String? currencyCode;
}

class ReceiptBranch {
  const ReceiptBranch({this.name, this.code, this.address});

  factory ReceiptBranch.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReceiptBranch();
    return ReceiptBranch(
      name: json['name'] as String?,
      code: json['code'] as String?,
      address: json['address'],
    );
  }

  final String? name;
  final String? code;
  final dynamic address;
}

class ReceiptPerson {
  const ReceiptPerson({this.id, this.name, this.email, this.phone});

  factory ReceiptPerson.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReceiptPerson();
    return ReceiptPerson(
      id: json['id'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }

  final String? id;
  final String? name;
  final String? email;
  final String? phone;
}

class ReceiptLineItem {
  const ReceiptLineItem({
    required this.name,
    this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.lineDiscount,
    required this.lineTax,
    required this.lineTotal,
  });

  factory ReceiptLineItem.fromJson(Map<String, dynamic> json) {
    return ReceiptLineItem(
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String?,
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: json['unit_price'] as int? ?? 0,
      lineDiscount: json['line_discount'] as int? ?? 0,
      lineTax: json['line_tax'] as int? ?? 0,
      lineTotal: json['line_total'] as int? ?? 0,
    );
  }

  final String name;
  final String? sku;
  final int quantity;
  final int unitPrice;
  final int lineDiscount;
  final int lineTax;
  final int lineTotal;
}

class ReceiptPaymentLine {
  const ReceiptPaymentLine({
    required this.method,
    required this.methodLabel,
    required this.amount,
    this.tendered,
    this.change,
  });

  factory ReceiptPaymentLine.fromJson(Map<String, dynamic> json) {
    return ReceiptPaymentLine(
      method: json['method'] as String? ?? '',
      methodLabel: json['method_label'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      tendered: json['tendered'] as int?,
      change: json['change'] as int?,
    );
  }

  final String method;
  final String methodLabel;
  final int amount;
  final int? tendered;
  final int? change;
}

class ReceiptPrintPayload {
  const ReceiptPrintPayload({
    required this.documentType,
    required this.format,
    required this.company,
    required this.branch,
    this.receiptNumber,
    this.invoiceNumber,
    required this.documentNumber,
    required this.saleReference,
    required this.saleId,
    required this.date,
    this.cashier,
    this.customer,
    required this.items,
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.feesTotal,
    required this.total,
    required this.currency,
    required this.payments,
    required this.amountPaid,
    required this.change,
    this.footer,
    this.notes,
  });

  factory ReceiptPrintPayload.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((e) => ReceiptLineItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final payments = (json['payments'] as List<dynamic>? ?? [])
        .map((e) => ReceiptPaymentLine.fromJson(e as Map<String, dynamic>))
        .toList();

    return ReceiptPrintPayload(
      documentType: json['document_type'] as String? ?? 'receipt',
      format: ReceiptDocumentFormat.fromString(json['format'] as String? ?? 'thermal_80'),
      company: ReceiptCompany.fromJson(json['company'] as Map<String, dynamic>?),
      branch: ReceiptBranch.fromJson(json['branch'] as Map<String, dynamic>?),
      receiptNumber: json['receipt_number'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      documentNumber: json['document_number'] as String? ?? '',
      saleReference: json['sale_reference'] as String? ?? '',
      saleId: json['sale_id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      cashier: ReceiptPerson.fromJson(json['cashier'] as Map<String, dynamic>?),
      customer: ReceiptPerson.fromJson(json['customer'] as Map<String, dynamic>?),
      items: items,
      subtotal: json['subtotal'] as int? ?? 0,
      discountTotal: json['discount_total'] as int? ?? 0,
      taxTotal: json['tax_total'] as int? ?? 0,
      feesTotal: json['fees_total'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      payments: payments,
      amountPaid: json['amount_paid'] as int? ?? 0,
      change: json['change'] as int? ?? 0,
      footer: json['footer'] as String?,
      notes: json['notes'] as String?,
    );
  }

  final String documentType;
  final ReceiptDocumentFormat format;
  final ReceiptCompany company;
  final ReceiptBranch branch;
  final String? receiptNumber;
  final String? invoiceNumber;
  final String documentNumber;
  final String saleReference;
  final String saleId;
  final String date;
  final ReceiptPerson? cashier;
  final ReceiptPerson? customer;
  final List<ReceiptLineItem> items;
  final int subtotal;
  final int discountTotal;
  final int taxTotal;
  final int feesTotal;
  final int total;
  final String currency;
  final List<ReceiptPaymentLine> payments;
  final int amountPaid;
  final int change;
  final String? footer;
  final String? notes;

  ReceiptPrintPayload copyWith({ReceiptDocumentFormat? format}) {
    return ReceiptPrintPayload(
      documentType: documentType,
      format: format ?? this.format,
      company: company,
      branch: branch,
      receiptNumber: receiptNumber,
      invoiceNumber: invoiceNumber,
      documentNumber: documentNumber,
      saleReference: saleReference,
      saleId: saleId,
      date: date,
      cashier: cashier,
      customer: customer,
      items: items,
      subtotal: subtotal,
      discountTotal: discountTotal,
      taxTotal: taxTotal,
      feesTotal: feesTotal,
      total: total,
      currency: currency,
      payments: payments,
      amountPaid: amountPaid,
      change: change,
      footer: footer,
      notes: notes,
    );
  }

  bool get isInvoice => documentType == 'invoice';
}

class ReceiptIssueResult {
  const ReceiptIssueResult({
    required this.receiptNumber,
    required this.payload,
  });

  factory ReceiptIssueResult.fromJson(Map<String, dynamic> json) {
    return ReceiptIssueResult(
      receiptNumber: json['receipt']?['receipt_number'] as String? ?? '',
      payload: ReceiptPrintPayload.fromJson(json['payload'] as Map<String, dynamic>),
    );
  }

  final String receiptNumber;
  final ReceiptPrintPayload payload;
}

class InvoiceIssueResult {
  const InvoiceIssueResult({
    required this.invoiceNumber,
    required this.payload,
  });

  factory InvoiceIssueResult.fromJson(Map<String, dynamic> json) {
    return InvoiceIssueResult(
      invoiceNumber: json['invoice']?['invoice_number'] as String? ?? '',
      payload: ReceiptPrintPayload.fromJson(json['payload'] as Map<String, dynamic>),
    );
  }

  final String invoiceNumber;
  final ReceiptPrintPayload payload;
}

class NetworkPrinterConfig {
  const NetworkPrinterConfig({
    this.host = '',
    this.port = 9100,
    this.enabled = false,
  });

  final String host;
  final int port;
  final bool enabled;

  bool get isConfigured => enabled && host.isNotEmpty;
}
