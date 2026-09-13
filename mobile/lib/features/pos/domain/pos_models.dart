import '../services/cart_calculator.dart';

class PosCategory {
  const PosCategory({
    required this.id,
    required this.name,
    this.parentId,
    this.sortOrder = 0,
    this.depth = 0,
  });

  final String id;
  final String name;
  final String? parentId;
  final int sortOrder;
  final int depth;

  factory PosCategory.fromJson(Map<String, dynamic> json) {
    return PosCategory(
      id: PosProduct._text(json['id']),
      name: PosProduct._text(json['name'], fallback: 'Catégorie'),
      parentId: PosProduct._textOrNull(json['parent_id']),
      sortOrder: json['sort_order'] as int? ?? 0,
      depth: json['depth'] as int? ?? 0,
    );
  }

  PosCategory copyWith({int? depth}) {
    return PosCategory(
      id: id,
      name: name,
      parentId: parentId,
      sortOrder: sortOrder,
      depth: depth ?? this.depth,
    );
  }
}

class PosProduct {
  const PosProduct({
    required this.storeProductId,
    required this.productId,
    required this.sku,
    required this.name,
    required this.price,
    this.categoryId,
    this.barcode,
    this.barcodes = const [],
    this.taxRate = 0,
    this.taxInclusive = false,
    this.primaryImageUrl,
    this.isAvailable = true,
    this.unit,
    this.productType,
    this.variants = const [],
    this.quantityOnHand,
    this.stockDisplay,
  });

  final String storeProductId;
  final String productId;
  final String sku;
  final String name;
  final int price;
  final String? categoryId;
  final String? barcode;
  final List<PosBarcode> barcodes;
  final double taxRate;
  final bool taxInclusive;
  final String? primaryImageUrl;
  final bool isAvailable;
  final String? unit;
  final String? productType;
  final List<PosVariant> variants;
  final int? quantityOnHand;
  final String? stockDisplay;

  bool get hasOptions => variants.isNotEmpty || productType == 'variant';

  factory PosProduct.fromJson(Map<String, dynamic> json) {
    final barcodesJson = json['barcodes'] as List<dynamic>? ?? [];
    final variantsJson = json['variants'] as List<dynamic>? ?? [];
    return PosProduct(
      storeProductId: _text(json['store_product_id'], fallback: _text(json['product_id'])),
      productId: _text(json['product_id']),
      sku: _text(json['sku']),
      name: _text(json['name'], fallback: 'Article'),
      price: _amount(json['price']),
      categoryId: _textOrNull(json['category_id']),
      barcode: _textOrNull(json['barcode']),
      barcodes: barcodesJson
          .whereType<Map>()
          .map((b) => PosBarcode.fromJson(Map<String, dynamic>.from(b)))
          .where((barcode) => barcode.barcode.isNotEmpty)
          .toList(),
      taxRate: _parseRate(json['tax_rate']),
      taxInclusive: json['tax_inclusive'] as bool? ?? false,
      primaryImageUrl: _textOrNull(json['primary_image_cdn_url']),
      isAvailable: json['is_available'] as bool? ?? true,
      unit: _textOrNull(json['unit']),
      productType: _textOrNull(json['product_type']),
      variants: variantsJson
          .whereType<Map<String, dynamic>>()
          .map(PosVariant.fromJson)
          .where((variant) => variant.id.isNotEmpty)
          .toList(),
      quantityOnHand: (json['quantity_on_hand'] as num?)?.toInt(),
      stockDisplay: _textOrNull(json['stock_display']),
    );
  }

  bool matchesBarcode(String code) {
    final normalized = code.trim();
    if (normalized.isEmpty) return false;
    if (barcode != null && barcode == normalized) return true;
    return barcodes.any((b) => b.barcode == normalized);
  }

  static String _text(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String? _textOrNull(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int _amount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _parseRate(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class PosVariant {
  const PosVariant({
    required this.id,
    required this.sku,
    required this.name,
    required this.price,
    this.label,
  });

  final String id;
  final String sku;
  final String name;
  final int price;
  final String? label;

  String get displayLabel {
    final text = (label ?? '').trim();
    if (text.isNotEmpty) return text;
    if (name.trim().isNotEmpty) return name.trim();
    return sku;
  }

  factory PosVariant.fromJson(Map<String, dynamic> json) {
    return PosVariant(
      id: json['variant_id'] as String? ?? json['id'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      name: json['name'] as String? ?? '',
      label: json['label'] as String?,
      price: (json['price'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'variant_id': id,
        'sku': sku,
        'name': name,
        'label': label,
        'price': price,
      };
}

class PosBarcode {
  const PosBarcode({
    required this.barcode,
    required this.type,
    this.isPrimary = false,
  });

  final String barcode;
  final String type;
  final bool isPrimary;

  factory PosBarcode.fromJson(Map<String, dynamic> json) {
    return PosBarcode(
      barcode: PosProduct._text(json['barcode']),
      type: json['type'] as String? ?? 'internal',
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}

class PosCustomer {
  const PosCustomer({
    required this.id,
    required this.name,
    this.code,
    this.email,
    this.phone,
    this.creditLimit,
    this.availableCredit,
    this.balance,
    this.serverId,
    this.pending = false,
  });

  final String id;
  final String name;
  final String? code;
  final String? email;
  final String? phone;
  final int? creditLimit;
  final int? availableCredit;
  final int? balance;
  final String? serverId;
  final bool pending;

  factory PosCustomer.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    return PosCustomer(
      id: id,
      name: json['name']?.toString().trim().isNotEmpty == true ? json['name'].toString() : 'Client',
      code: json['code']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      creditLimit: (json['credit_limit'] as num?)?.toInt(),
      availableCredit: (json['available_credit'] as num?)?.toInt(),
      balance: (json['balance'] as num?)?.toInt(),
      serverId: json['server_id']?.toString(),
      pending: json['pending'] == true || json['sync_status'] == 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (serverId != null) 'server_id': serverId,
        'name': name,
        if (code != null) 'code': code,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (creditLimit != null) 'credit_limit': creditLimit,
        if (availableCredit != null) 'available_credit': availableCredit,
        if (balance != null) 'balance': balance,
        'pending': pending,
        'sync_status': pending ? 'pending' : 'synced',
      };

  String get saleCustomerId => (serverId != null && serverId!.isNotEmpty) ? serverId! : id;

  String get displayLabel {
    if (code != null && code!.isNotEmpty) return '$name ($code)';
    return name;
  }

  String get subtitle {
    final parts = <String>[
      if (pending) 'En attente de synchro',
      if (phone != null && phone!.isNotEmpty) phone!,
      if (email != null && email!.isNotEmpty) email!,
      if (code != null && code!.isNotEmpty) code!,
    ];
    return parts.join(' · ');
  }
}

class PosPaymentMethod {
  const PosPaymentMethod({
    required this.value,
    required this.label,
    this.labelFr,
    this.requiresCustomer = false,
    this.supportsChange = false,
    this.sortOrder = 0,
  });

  final String value;
  final String label;
  final String? labelFr;
  final bool requiresCustomer;
  final bool supportsChange;
  final int sortOrder;

  String get displayLabel => (labelFr != null && labelFr!.trim().isNotEmpty) ? labelFr!.trim() : label;

  factory PosPaymentMethod.fromJson(Map<String, dynamic> json) {
    return PosPaymentMethod(
      value: json['value']?.toString() ?? json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? json['value']?.toString() ?? 'Paiement',
      labelFr: json['label_fr']?.toString(),
      requiresCustomer: json['requires_customer'] == true,
      supportsChange: json['supports_change'] == true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'value': value,
        'label': label,
        'label_fr': labelFr,
        'requires_customer': requiresCustomer,
        'supports_change': supportsChange,
        'sort_order': sortOrder,
      };

  static const defaults = <PosPaymentMethod>[
    PosPaymentMethod(value: 'cash', label: 'Cash', labelFr: 'Espèces', supportsChange: true),
    PosPaymentMethod(value: 'card', label: 'Card', labelFr: 'Carte'),
    PosPaymentMethod(value: 'mobile_money', label: 'Mobile Money', labelFr: 'Mobile Money'),
    PosPaymentMethod(value: 'credit', label: 'Credit', labelFr: 'Crédit client', requiresCustomer: true),
  ];
}

class PosCatalog {
  const PosCatalog({
    required this.storeId,
    required this.products,
    required this.categories,
  });

  final String storeId;
  final List<PosProduct> products;
  final List<PosCategory> categories;

  factory PosCatalog.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final productsJson = data['products'] as List<dynamic>? ?? [];
    final categoriesJson = data['categories'] as List<dynamic>? ?? [];

    return PosCatalog(
      storeId: PosProduct._text(data['store_id']),
      products: productsJson
          .whereType<Map>()
          .map((p) => PosProduct.fromJson(Map<String, dynamic>.from(p)))
          .where((product) => product.productId.isNotEmpty)
          .toList(),
      categories: categoriesJson
          .whereType<Map>()
          .map((c) => PosCategory.fromJson(Map<String, dynamic>.from(c)))
          .where((category) => category.id.isNotEmpty)
          .toList(),
    );
  }
}

class PosCartLine {
  PosCartLine({
    required this.lineId,
    required this.product,
    required this.unitPrice,
    this.quantity = 1,
    this.taxRate = 0,
    this.taxInclusive = false,
    this.lineDiscountFixed = 0,
    this.variantId,
    this.variantLabel,
  });

  final String lineId;
  final PosProduct product;
  final int unitPrice;
  final String? variantId;
  final String? variantLabel;
  int quantity;
  final double taxRate;
  final bool taxInclusive;
  final int lineDiscountFixed;

  int get lineSubtotal => unitPrice * quantity;

  int get lineTax {
    final base = (lineSubtotal - lineDiscountFixed).clamp(0, lineSubtotal);
    return (base * taxRate / 100).round();
  }

  String get displayName {
    final option = variantLabel?.trim();
    if (option == null || option.isEmpty) return product.name;
    return '${product.name} · $option';
  }

  Map<String, dynamic> toSaleItem() => {
        'product_id': product.productId,
        'quantity': quantity,
        'unit_price': unitPrice,
        if (variantId != null && variantId!.isNotEmpty) 'product_variant_id': variantId,
      };

  Map<String, dynamic> toJson() => {
        'line_id': lineId,
        'unit_price': unitPrice,
        'quantity': quantity,
        'tax_rate': taxRate,
        'tax_inclusive': taxInclusive,
        'line_discount_fixed': lineDiscountFixed,
        'variant_id': variantId,
        'variant_label': variantLabel,
        'product': {
          'store_product_id': product.storeProductId,
          'product_id': product.productId,
          'sku': product.sku,
          'name': product.name,
          'price': product.price,
          'category_id': product.categoryId,
          'barcode': product.barcode,
          'tax_rate': product.taxRate,
          'tax_inclusive': product.taxInclusive,
          'primary_image_cdn_url': product.primaryImageUrl,
          'is_available': product.isAvailable,
          'unit': product.unit,
          'product_type': product.productType,
          'variants': product.variants.map((variant) => variant.toJson()).toList(),
        },
      };

  factory PosCartLine.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'];
    return PosCartLine(
      lineId: json['line_id']?.toString() ?? 'line',
      product: productJson is Map ? PosProduct.fromJson(Map<String, dynamic>.from(productJson)) : PosProduct.fromJson(const {}),
      unitPrice: (json['unit_price'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0,
      taxInclusive: json['tax_inclusive'] == true,
      lineDiscountFixed: (json['line_discount_fixed'] as num?)?.toInt() ?? 0,
      variantId: json['variant_id']?.toString(),
      variantLabel: json['variant_label']?.toString(),
    );
  }

  PosCartLine copy() {
    return PosCartLine(
      lineId: lineId,
      product: product,
      unitPrice: unitPrice,
      quantity: quantity,
      taxRate: taxRate,
      taxInclusive: taxInclusive,
      lineDiscountFixed: lineDiscountFixed,
      variantId: variantId,
      variantLabel: variantLabel,
    );
  }
}

class PosHeldSale {
  const PosHeldSale({
    required this.id,
    required this.label,
    required this.lines,
    required this.heldAt,
    this.serverId,
    this.customer,
    this.note,
    this.discountAmount = 0,
    this.discountPercent = 0,
    this.fees = const [],
  });

  final String id;
  final String label;
  final String? serverId;
  final List<PosCartLine> lines;
  final DateTime heldAt;
  final PosCustomer? customer;
  final String? note;
  final int discountAmount;
  final double discountPercent;
  final List<int> fees;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  Map<String, dynamic> toLocalJson() => {
        'id': id,
        'label': label,
        'server_id': serverId,
        'held_at': heldAt.toIso8601String(),
        'note': note,
        'discount_amount': discountAmount,
        'discount_percent': discountPercent,
        'fees': fees,
        'customer': customer?.toJson(),
        'customer_id': customer?.saleCustomerId,
        'notes': note,
        'items': lines.map((line) => line.toSaleItem()).toList(),
        'lines': lines.map((line) => line.toJson()).toList(),
      };

  factory PosHeldSale.fromLocalJson(Map<String, dynamic> json) {
    final linesJson = json['lines'];
    final customerJson = json['customer'];
    return PosHeldSale(
      id: json['id']?.toString() ?? 'hold',
      label: json['label']?.toString() ?? 'Commande en attente',
      serverId: json['server_id']?.toString(),
      lines: linesJson is List
          ? linesJson.whereType<Map>().map((item) => PosCartLine.fromJson(Map<String, dynamic>.from(item))).toList()
          : const [],
      heldAt: DateTime.tryParse(json['held_at']?.toString() ?? '') ?? DateTime.now(),
      customer: customerJson is Map ? PosCustomer.fromJson(Map<String, dynamic>.from(customerJson)) : null,
      note: json['note']?.toString(),
      discountAmount: (json['discount_amount'] as num?)?.toInt() ?? 0,
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0,
      fees: (json['fees'] as List<dynamic>? ?? []).map((item) => (item as num).toInt()).toList(),
    );
  }

  int get total {
    final globalPercentPpm = discountPercent > 0
        ? CartCalculator.ratePpmFromPercent(discountPercent.toStringAsFixed(4))
        : 0;

    return CartCalculator.calculate(
      CartCalculationInput(
        lines: lines
            .map(
              (line) => CartCalculationLine(
                unitPrice: line.unitPrice,
                quantity: line.quantity,
                taxRatePpm: CartCalculator.ratePpmFromPercent(
                  line.taxRate.toStringAsFixed(4),
                ),
                taxInclusive: line.taxInclusive,
                lineDiscountFixed: line.lineDiscountFixed,
              ),
            )
            .toList(),
        globalDiscountFixed: discountPercent > 0 ? 0 : discountAmount,
        globalDiscountPercentPpm: globalPercentPpm,
        fees: fees,
      ),
    ).grandTotal;
  }
}

class PosPaymentResult {
  const PosPaymentResult({
    required this.success,
    required this.total,
    required this.method,
    this.change = 0,
    this.paidAmount = 0,
    this.outstandingAmount = 0,
    this.saleId,
    this.saleReference,
    this.message,
  });

  final bool success;
  final int total;
  final String method;
  final int change;
  final int paidAmount;
  final int outstandingAmount;
  final String? saleId;
  final String? saleReference;
  final String? message;
}

class PosCustomerBalance {
  const PosCustomerBalance({
    required this.balance,
    required this.receivable,
    this.creditLimit,
    this.availableCredit,
  });

  final int balance;
  final int receivable;
  final int? creditLimit;
  final int? availableCredit;

  factory PosCustomerBalance.fromJson(Map<String, dynamic> json) {
    return PosCustomerBalance(
      balance: json['balance'] as int? ?? 0,
      receivable: json['receivable'] as int? ?? 0,
      creditLimit: json['credit_limit'] as int?,
      availableCredit: json['available_credit'] as int?,
    );
  }
}

class PosSaleResult {
  const PosSaleResult({
    required this.saleId,
    required this.reference,
    required this.total,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.paymentStatus,
    this.dueDate,
  });

  final String saleId;
  final String reference;
  final int total;
  final int paidAmount;
  final int outstandingAmount;
  final String paymentStatus;
  final String? dueDate;

  factory PosSaleResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final sale = data['sale'] as Map<String, dynamic>? ?? data;
    final credit = sale['credit'] as Map<String, dynamic>?;

    return PosSaleResult(
      saleId: sale['id'] as String,
      reference: sale['reference'] as String,
      total: sale['total'] as int,
      paidAmount: credit?['paid_amount'] as int? ?? sale['paid_amount'] as int? ?? 0,
      outstandingAmount:
          credit?['outstanding_amount'] as int? ?? sale['outstanding_amount'] as int? ?? 0,
      paymentStatus: credit?['payment_status'] as String? ?? sale['payment_status'] as String? ?? 'paid',
      dueDate: credit?['due_date'] as String? ?? sale['due_date'] as String?,
    );
  }
}
