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
      sortOrder: PosProduct._amount(json['sort_order']),
      depth: PosProduct._amount(json['depth']),
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

class PosAccompaniment {
  const PosAccompaniment({
    required this.productId,
    required this.sku,
    required this.name,
  });

  final String productId;
  final String sku;
  final String name;

  factory PosAccompaniment.fromJson(Map<String, dynamic> json) {
    return PosAccompaniment(
      productId: PosProduct._text(json['product_id'] ?? json['id']),
      sku: PosProduct._text(json['sku']),
      name: PosProduct._text(json['name'], fallback: 'Accompagnement'),
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'sku': sku,
        'name': name,
      };
}

class PosSaleUnit {
  const PosSaleUnit({
    required this.id,
    required this.name,
    this.code,
    this.volumeMl = 0,
    this.price = 0,
    this.isBase = false,
    this.yieldPerBottle,
  });

  final String id;
  final String name;
  final String? code;
  final int volumeMl;
  final int price;
  final bool isBase;
  final double? yieldPerBottle;

  factory PosSaleUnit.fromJson(Map<String, dynamic> json) {
    return PosSaleUnit(
      id: PosProduct._text(json['id']),
      name: PosProduct._text(json['name'], fallback: 'Unité'),
      code: PosProduct._textOrNull(json['code']),
      volumeMl: PosProduct._amount(json['volume_ml']),
      price: PosProduct._amount(json['price']),
      isBase: json['is_base'] == true,
      yieldPerBottle: json['yield_per_bottle'] == null ? null : PosProduct._parseRate(json['yield_per_bottle']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (code != null) 'code': code,
        'volume_ml': volumeMl,
        'price': price,
        'is_base': isBase,
        if (yieldPerBottle != null) 'yield_per_bottle': yieldPerBottle,
      };
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
    this.stockVersion = 0,
    this.bundleItems = const [],
    this.categoryName,
    this.lowStockThreshold,
    this.costPrice = 0,
    this.trackExpiration = false,
    this.expiresAt,
    this.accompanimentEnabled = false,
    this.accompaniments = const [],
    this.saleUnits = const [],
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
  final int stockVersion;
  final List<PosBundleItem> bundleItems;
  final String? categoryName;
  final int? lowStockThreshold;
  final int costPrice;
  final bool trackExpiration;
  final String? expiresAt;
  final bool accompanimentEnabled;
  final List<PosAccompaniment> accompaniments;
  final List<PosSaleUnit> saleUnits;

  bool get hasOptions => variants.isNotEmpty || productType == 'variant';

  factory PosProduct.fromJson(Map<String, dynamic> json) {
    final barcodesJson = json['barcodes'] as List<dynamic>? ?? [];
    final variantsJson = json['variants'] as List<dynamic>? ?? [];
    final accompanimentsJson =
        json['accompaniments'] as List<dynamic>? ?? json['accompaniment_products'] as List<dynamic>? ?? [];
    final saleUnitsJson = json['sale_units'] as List<dynamic>? ?? [];
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
      quantityOnHand: _intOrNull(json['quantity_on_hand']),
      stockDisplay: _textOrNull(json['stock_display']),
      stockVersion: _amount(json['stock_version']),
      bundleItems: (json['bundle_items'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => PosBundleItem.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.componentProductId.isNotEmpty && item.quantity > 0)
          .toList(),
      categoryName: _textOrNull(json['category_name']),
      lowStockThreshold: _intOrNull(json['low_stock_threshold']),
      costPrice: _amount(json['cost_price']),
      trackExpiration: json['track_expiration'] as bool? ?? false,
      expiresAt: _textOrNull(json['expires_at']),
      accompanimentEnabled: json['accompaniment_enabled'] == true,
      accompaniments: accompanimentsJson
          .whereType<Map>()
          .map((item) => PosAccompaniment.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.productId.isNotEmpty)
          .toList(),
      saleUnits: saleUnitsJson
          .whereType<Map>()
          .map((item) => PosSaleUnit.fromJson(Map<String, dynamic>.from(item)))
          .where((unit) => unit.id.isNotEmpty)
          .toList(),
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

  static int _amount(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? _intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return int.tryParse(text) ?? double.tryParse(text)?.round();
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
      price: PosProduct._amount(json['price']),
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
      creditLimit: PosProduct._intOrNull(json['credit_limit']),
      availableCredit: PosProduct._intOrNull(json['available_credit']),
      balance: PosProduct._intOrNull(json['balance']),
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
      sortOrder: PosProduct._amount(json['sort_order']),
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

class PosBundleItem {
  const PosBundleItem({
    required this.componentProductId,
    required this.quantity,
  });

  final String componentProductId;
  final num quantity;

  factory PosBundleItem.fromJson(Map<String, dynamic> json) {
    return PosBundleItem(
      componentProductId: PosProduct._text(json['component_product_id']),
      quantity: PosProduct._amount(json['quantity']),
    );
  }

  Map<String, dynamic> toJson() => {
        'component_product_id': componentProductId,
        'quantity': quantity,
      };
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
    this.saleUnitId,
    this.isAccompaniment = false,
    this.parentLineId,
  });

  final String lineId;
  final PosProduct product;
  final int unitPrice;
  final String? variantId;
  final String? variantLabel;
  final String? saleUnitId;
  final bool isAccompaniment;
  final String? parentLineId;
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
        if (saleUnitId != null && saleUnitId!.isNotEmpty) 'sale_unit_id': saleUnitId,
        if (isAccompaniment) 'is_accompaniment': true,
        if (parentLineId != null && parentLineId!.isNotEmpty) 'parent_line_id': parentLineId,
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
        'sale_unit_id': saleUnitId,
        'is_accompaniment': isAccompaniment,
        'parent_line_id': parentLineId,
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
          'accompaniment_enabled': product.accompanimentEnabled,
          'accompaniments': product.accompaniments.map((item) => item.toJson()).toList(),
          'sale_units': product.saleUnits.map((unit) => unit.toJson()).toList(),
        },
      };

  factory PosCartLine.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'];
    return PosCartLine(
      lineId: json['line_id']?.toString() ?? 'line',
      product: productJson is Map ? PosProduct.fromJson(Map<String, dynamic>.from(productJson)) : PosProduct.fromJson(const {}),
      unitPrice: PosProduct._amount(json['unit_price']),
      quantity: PosProduct._amount(json['quantity'], fallback: 1),
      taxRate: PosProduct._parseRate(json['tax_rate']),
      taxInclusive: json['tax_inclusive'] == true,
      lineDiscountFixed: PosProduct._amount(json['line_discount_fixed']),
      variantId: json['variant_id']?.toString(),
      variantLabel: json['variant_label']?.toString(),
      saleUnitId: json['sale_unit_id']?.toString(),
      isAccompaniment: json['is_accompaniment'] == true,
      parentLineId: json['parent_line_id']?.toString(),
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
      saleUnitId: saleUnitId,
      isAccompaniment: isAccompaniment,
      parentLineId: parentLineId,
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
    this.tableId,
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
  final String? tableId;

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
        if (tableId != null && tableId!.isNotEmpty) 'table_id': tableId,
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
      discountAmount: PosProduct._amount(json['discount_amount']),
      discountPercent: PosProduct._parseRate(json['discount_percent']),
      fees: (json['fees'] as List<dynamic>? ?? [])
          .map((item) => PosProduct._amount(item))
          .toList(),
      tableId: json['table_id']?.toString(),
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
    this.receipt,
    this.loyaltyEarned,
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
  final Map<String, dynamic>? receipt;
  final int? loyaltyEarned;
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
      balance: PosProduct._amount(json['balance']),
      receivable: PosProduct._amount(json['receivable']),
      creditLimit: PosProduct._intOrNull(json['credit_limit']),
      availableCredit: PosProduct._intOrNull(json['available_credit']),
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
    this.storedLocally = false,
    this.pendingSync = false,
    this.receipt,
    this.loyaltyEarned,
  });

  final String saleId;
  final String reference;
  final int total;
  final int paidAmount;
  final int outstandingAmount;
  final String paymentStatus;
  final String? dueDate;
  final bool storedLocally;
  final bool pendingSync;
  final Map<String, dynamic>? receipt;
  final int? loyaltyEarned;

  factory PosSaleResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final sale = data['sale'] as Map<String, dynamic>? ?? data;
    final credit = sale['credit'] as Map<String, dynamic>?;
    final receiptRaw = data['receipt'];
    final loyaltyRaw = data['loyalty'] ?? sale['loyalty'];
    final loyalty = loyaltyRaw is Map ? Map<String, dynamic>.from(loyaltyRaw) : null;

    return PosSaleResult(
      saleId: sale['id']?.toString() ?? '',
      reference: sale['reference']?.toString() ?? '',
      total: PosProduct._amount(sale['total']),
      paidAmount: PosProduct._amount(credit?['paid_amount'] ?? sale['paid_amount']),
      outstandingAmount: PosProduct._amount(credit?['outstanding_amount'] ?? sale['outstanding_amount']),
      paymentStatus: credit?['payment_status']?.toString() ?? sale['payment_status']?.toString() ?? 'paid',
      dueDate: credit?['due_date']?.toString() ?? sale['due_date']?.toString(),
      receipt: receiptRaw is Map ? Map<String, dynamic>.from(receiptRaw) : null,
      loyaltyEarned: PosProduct._intOrNull(loyalty?['earned']),
    );
  }
}

class CartCalculation {
  const CartCalculation({
    required this.subtotal,
    required this.taxTotal,
    required this.discountTotal,
    required this.feesTotal,
    required this.total,
    this.lines = const [],
    this.fees = const [],
  });

  final int subtotal;
  final int taxTotal;
  final int discountTotal;
  final int feesTotal;
  final int total;
  final List<Map<String, dynamic>> lines;
  final List<Map<String, dynamic>> fees;

  factory CartCalculation.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final linesRaw = data['lines'];
    final feesRaw = data['fees'];
    return CartCalculation(
      subtotal: PosProduct._amount(data['subtotal']),
      taxTotal: PosProduct._amount(data['tax_total']),
      discountTotal: PosProduct._amount(data['discount_total']),
      feesTotal: PosProduct._amount(data['fees_total']),
      total: PosProduct._amount(data['total'] ?? data['grand_total']),
      lines: linesRaw is List
          ? linesRaw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : const [],
      fees: feesRaw is List
          ? feesRaw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : const [],
    );
  }
}

class PosLoyaltySummary {
  const PosLoyaltySummary({
    required this.points,
    required this.rewardPerPoint,
    this.tier,
  });

  final int points;
  final int rewardPerPoint;
  final String? tier;

  factory PosLoyaltySummary.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return PosLoyaltySummary(
      points: PosProduct._amount(data['points']),
      rewardPerPoint: PosProduct._amount(data['reward_per_point']),
      tier: data['tier']?.toString(),
    );
  }
}

class PosOverview {
  const PosOverview({
    required this.orderCount,
    required this.revenue,
    this.myShiftOpen = false,
    this.openShiftsCount = 0,
    this.bestSellers = const [],
    this.recentOrders = const [],
    this.paymentMix = const [],
  });

  final int orderCount;
  final int revenue;
  final bool myShiftOpen;
  final int openShiftsCount;
  final List<Map<String, dynamic>> bestSellers;
  final List<Map<String, dynamic>> recentOrders;
  final List<Map<String, dynamic>> paymentMix;

  factory PosOverview.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final kpis = data['kpis'] is Map ? Map<String, dynamic>.from(data['kpis'] as Map) : const <String, dynamic>{};
    final myShift = data['my_shift'];
    final bool shiftOpen;
    if (myShift is Map) {
      shiftOpen = myShift['open'] == true || myShift['status']?.toString() == 'open';
    } else if (myShift is bool) {
      shiftOpen = myShift;
    } else {
      shiftOpen = data['my_shift_open'] == true;
    }

    List<Map<String, dynamic>> mapsOf(dynamic raw) {
      if (raw is! List) return const [];
      return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }

    return PosOverview(
      orderCount: PosProduct._amount(
        data['order_count'] ?? kpis['sales_count'] ?? data['sales_count'],
      ),
      revenue: PosProduct._amount(data['revenue'] ?? kpis['revenue']),
      myShiftOpen: shiftOpen,
      openShiftsCount: PosProduct._amount(data['open_shifts_count']),
      bestSellers: mapsOf(data['best_sellers'] ?? data['best_selling_products']),
      recentOrders: mapsOf(data['recent_orders']),
      paymentMix: mapsOf(data['payment_mix'] ?? data['payment_methods']),
    );
  }
}

class SaleReturnRow {
  const SaleReturnRow({
    required this.id,
    required this.returnNumber,
    required this.status,
    required this.reason,
    required this.total,
    this.refundMethod,
    this.createdAt,
    this.sale,
    this.customer,
  });

  final String id;
  final String returnNumber;
  final String status;
  final String reason;
  final int total;
  final String? refundMethod;
  final String? createdAt;
  final Map<String, dynamic>? sale;
  final Map<String, dynamic>? customer;

  factory SaleReturnRow.fromJson(Map<String, dynamic> json) {
    final saleRaw = json['sale'];
    final customerRaw = json['customer'];
    return SaleReturnRow(
      id: json['id']?.toString() ?? '',
      returnNumber: json['return_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      total: PosProduct._amount(json['total']),
      refundMethod: json['refund_method']?.toString(),
      createdAt: json['created_at']?.toString(),
      sale: saleRaw is Map ? Map<String, dynamic>.from(saleRaw) : null,
      customer: customerRaw is Map ? Map<String, dynamic>.from(customerRaw) : null,
    );
  }
}

class SaleReturnReason {
  const SaleReturnReason({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  factory SaleReturnReason.fromJson(Map<String, dynamic> json) {
    return SaleReturnReason(
      value: json['value']?.toString() ?? json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? json['value']?.toString() ?? '',
    );
  }
}

class MergeCandidate {
  const MergeCandidate({
    required this.id,
    required this.reference,
    required this.total,
    this.currency,
    this.customer,
    this.table,
    this.itemCount,
  });

  final String id;
  final String reference;
  final int total;
  final String? currency;
  final Map<String, dynamic>? customer;
  final Map<String, dynamic>? table;
  final int? itemCount;

  factory MergeCandidate.fromJson(Map<String, dynamic> json) {
    final customerRaw = json['customer'];
    final tableRaw = json['table'];
    return MergeCandidate(
      id: json['id']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      total: PosProduct._amount(json['total']),
      currency: json['currency']?.toString(),
      customer: customerRaw is Map ? Map<String, dynamic>.from(customerRaw) : null,
      table: tableRaw is Map ? Map<String, dynamic>.from(tableRaw) : null,
      itemCount: PosProduct._intOrNull(json['item_count']),
    );
  }
}

class MergePreview {
  const MergePreview({
    required this.source,
    required this.target,
    this.customersDiffer = false,
    this.tables = const [],
    this.finalTableId,
    this.customerId,
    this.customer,
    this.items = const [],
    this.totals = const {},
  });

  final MergeCandidate source;
  final MergeCandidate target;
  final bool customersDiffer;
  final List<Map<String, dynamic>> tables;
  final String? finalTableId;
  final String? customerId;
  final Map<String, dynamic>? customer;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> totals;

  factory MergePreview.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final sourceRaw = data['source'] is Map ? Map<String, dynamic>.from(data['source'] as Map) : <String, dynamic>{};
    final targetRaw = data['target'] is Map ? Map<String, dynamic>.from(data['target'] as Map) : <String, dynamic>{};
    final customerRaw = data['customer'];
    final tablesRaw = data['tables'];
    final itemsRaw = data['items'];
    final totalsRaw = data['totals'];
    return MergePreview(
      source: MergeCandidate.fromJson(sourceRaw),
      target: MergeCandidate.fromJson(targetRaw),
      customersDiffer: data['customers_differ'] == true,
      tables: tablesRaw is List
          ? tablesRaw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : const [],
      finalTableId: data['final_table_id']?.toString(),
      customerId: data['customer_id']?.toString(),
      customer: customerRaw is Map ? Map<String, dynamic>.from(customerRaw) : null,
      items: itemsRaw is List
          ? itemsRaw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : const [],
      totals: totalsRaw is Map ? Map<String, dynamic>.from(totalsRaw) : const {},
    );
  }
}

class PosReservation {
  const PosReservation({
    required this.id,
    required this.reference,
    required this.guestName,
    required this.partySize,
    required this.reservedAt,
    required this.status,
    this.phone,
    this.tableLabel,
    this.notes,
    this.customerId,
    this.customer,
  });

  final String id;
  final String reference;
  final String guestName;
  final int partySize;
  final String reservedAt;
  final String status;
  final String? phone;
  final String? tableLabel;
  final String? notes;
  final String? customerId;
  final Map<String, dynamic>? customer;

  factory PosReservation.fromJson(Map<String, dynamic> json) {
    final customerRaw = json['customer'];
    return PosReservation(
      id: json['id']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      guestName: json['guest_name']?.toString() ?? '',
      partySize: PosProduct._amount(json['party_size'], fallback: 1),
      reservedAt: json['reserved_at']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      phone: json['phone']?.toString(),
      tableLabel: json['table_label']?.toString(),
      notes: json['notes']?.toString(),
      customerId: json['customer_id']?.toString(),
      customer: customerRaw is Map ? Map<String, dynamic>.from(customerRaw) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference': reference,
        'guest_name': guestName,
        'party_size': partySize,
        'reserved_at': reservedAt,
        'status': status,
        if (phone != null) 'phone': phone,
        if (tableLabel != null) 'table_label': tableLabel,
        if (notes != null) 'notes': notes,
        if (customerId != null) 'customer_id': customerId,
        if (customer != null) 'customer': customer,
      };
}
