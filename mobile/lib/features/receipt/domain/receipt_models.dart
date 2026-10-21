int _asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value') ?? fallback;
}

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
    this.tradeName,
    this.legalName,
    this.taxId,
    this.registrationNumber,
    this.email,
    this.logoUrl,
    this.address,
    this.currencyCode,
    this.fiscalCenter,
    this.activitySector,
    this.vatRegistered = false,
    this.vatExempt = false,
    this.subjectToTc = false,
    this.subjectToPf = false,
  });

  factory ReceiptCompany.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReceiptCompany();
    final status = json['vat_status']?.toString().trim().toLowerCase();
    return ReceiptCompany(
      name: json['name'] as String?,
      tradeName: json['trade_name'] as String?,
      legalName: json['legal_name'] as String?,
      taxId: json['tax_id'] as String?,
      registrationNumber: json['registration_number'] as String?,
      email: json['email'] as String?,
      logoUrl: json['logo_url'] as String?,
      address: json['address'],
      currencyCode: json['currency_code'] as String?,
      fiscalCenter: (json['fiscal_center'] ?? json['dpmc']) as String?,
      activitySector: json['activity_sector'] as String?,
      vatRegistered: json['vat_registered'] == true,
      vatExempt: json['vat_exempt'] == true || status == 'exempt' || status == 'exo',
      subjectToTc: json['subject_to_tc'] == true,
      subjectToPf: json['subject_to_pf'] == true,
    );
  }

  final String? name;
  final String? tradeName;
  final String? legalName;
  final String? taxId;
  final String? registrationNumber;
  final String? email;
  final String? logoUrl;
  final dynamic address;
  final String? currencyCode;
  final String? fiscalCenter;
  final String? activitySector;
  final bool vatRegistered;
  final bool vatExempt;
  final bool subjectToTc;
  final bool subjectToPf;

  Map<String, dynamic> toJson() => {
        'name': name,
        'trade_name': tradeName,
        'legal_name': legalName,
        'tax_id': taxId,
        'registration_number': registrationNumber,
        'email': email,
        'logo_url': logoUrl,
        'address': address,
        'currency_code': currencyCode,
        'fiscal_center': fiscalCenter,
        'activity_sector': activitySector,
        'vat_registered': vatRegistered,
        'vat_exempt': vatExempt,
        'subject_to_tc': subjectToTc,
        'subject_to_pf': subjectToPf,
      };
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

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'address': address,
      };
}

class ReceiptPerson {
  const ReceiptPerson({this.id, this.name, this.email, this.phone, this.taxId});

  factory ReceiptPerson.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReceiptPerson();
    return ReceiptPerson(
      id: json['id'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      taxId: json['tax_id'] as String?,
    );
  }

  final String? id;
  final String? name;
  final String? email;
  final String? phone;
  final String? taxId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'tax_id': taxId,
      };
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
      quantity: _asInt(json['quantity']),
      unitPrice: _asInt(json['unit_price']),
      lineDiscount: _asInt(json['line_discount']),
      lineTax: _asInt(json['line_tax']),
      lineTotal: _asInt(json['line_total']),
    );
  }

  final String name;
  final String? sku;
  final int quantity;
  final int unitPrice;
  final int lineDiscount;
  final int lineTax;
  final int lineTotal;

  Map<String, dynamic> toJson() => {
        'name': name,
        'sku': sku,
        'quantity': quantity,
        'unit_price': unitPrice,
        'line_discount': lineDiscount,
        'line_tax': lineTax,
        'line_total': lineTotal,
      };
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
      amount: _asInt(json['amount']),
      tendered: json['tendered'] == null ? null : _asInt(json['tendered']),
      change: json['change'] == null ? null : _asInt(json['change']),
    );
  }

  final String method;
  final String methodLabel;
  final int amount;
  final int? tendered;
  final int? change;

  Map<String, dynamic> toJson() => {
        'method': method,
        'method_label': methodLabel,
        'amount': amount,
        'tendered': tendered,
        'change': change,
      };
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
    this.serviceMode = '',
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
      subtotal: _asInt(json['subtotal']),
      discountTotal: _asInt(json['discount_total']),
      taxTotal: _asInt(json['tax_total']),
      feesTotal: _asInt(json['fees_total']),
      total: _asInt(json['total']),
      currency: json['currency'] as String? ?? 'USD',
      payments: payments,
      amountPaid: _asInt(json['amount_paid']),
      change: _asInt(json['change']),
      footer: json['footer'] as String?,
      notes: json['notes'] as String?,
      serviceMode: json['service_mode'] as String? ?? '',
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
  final String serviceMode;

  Map<String, dynamic> toJson() => {
        'document_type': documentType,
        'format': format.value,
        'company': company.toJson(),
        'branch': branch.toJson(),
        'receipt_number': receiptNumber,
        'invoice_number': invoiceNumber,
        'document_number': documentNumber,
        'sale_reference': saleReference,
        'sale_id': saleId,
        'date': date,
        'cashier': cashier?.toJson(),
        'customer': customer?.toJson(),
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal': subtotal,
        'discount_total': discountTotal,
        'tax_total': taxTotal,
        'fees_total': feesTotal,
        'total': total,
        'currency': currency,
        'payments': payments.map((e) => e.toJson()).toList(),
        'amount_paid': amountPaid,
        'change': change,
        'footer': footer,
        'notes': notes,
        'service_mode': serviceMode,
      };

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
      serviceMode: serviceMode,
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
