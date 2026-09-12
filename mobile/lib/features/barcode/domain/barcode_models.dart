enum PosBarcodeType {
  ean13('ean13', 'EAN-13'),
  ean8('ean8', 'EAN-8'),
  upc('upc', 'UPC'),
  code128('code128', 'Code 128'),
  qr('qr', 'QR Code'),
  internal('internal', 'Interne');

  const PosBarcodeType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PosBarcodeType? fromApi(String? value) {
    if (value == null) return null;
    for (final type in PosBarcodeType.values) {
      if (type.apiValue == value) return type;
    }
    return null;
  }
}

class BarcodeRecord {
  const BarcodeRecord({
    required this.barcode,
    required this.type,
    this.id,
    this.isPrimary = false,
    this.productName,
  });

  final String? id;
  final String barcode;
  final PosBarcodeType type;
  final bool isPrimary;
  final String? productName;

  factory BarcodeRecord.fromJson(Map<String, dynamic> json) {
    return BarcodeRecord(
      id: json['id'] as String?,
      barcode: json['barcode'] as String,
      type: PosBarcodeType.fromApi(json['type'] as String?) ?? PosBarcodeType.internal,
      isPrimary: json['is_primary'] as bool? ?? false,
      productName: json['product_name'] as String?,
    );
  }
}

class BarcodeLookupResult {
  const BarcodeLookupResult({
    required this.found,
    this.barcode,
    this.productName,
    this.productSku,
    this.variantSku,
  });

  final bool found;
  final BarcodeRecord? barcode;
  final String? productName;
  final String? productSku;
  final String? variantSku;

  factory BarcodeLookupResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final found = data['found'] as bool? ?? false;

    if (!found) {
      return const BarcodeLookupResult(found: false);
    }

    final barcodeJson = data['barcode'] as Map<String, dynamic>?;
    final productJson = data['product'] as Map<String, dynamic>?;
    final variantJson = data['variant'] as Map<String, dynamic>?;

    return BarcodeLookupResult(
      found: true,
      barcode: barcodeJson == null ? null : BarcodeRecord.fromJson(barcodeJson),
      productName: productJson?['name'] as String?,
      productSku: productJson?['sku'] as String?,
      variantSku: variantJson?['sku'] as String?,
    );
  }
}

class BarcodePrintPayload {
  const BarcodePrintPayload({
    required this.barcode,
    required this.type,
    required this.label,
    required this.typeLabel,
    required this.isPrimary,
  });

  final String barcode;
  final PosBarcodeType type;
  final String label;
  final String typeLabel;
  final bool isPrimary;

  factory BarcodePrintPayload.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return BarcodePrintPayload(
      barcode: data['barcode'] as String,
      type: PosBarcodeType.fromApi(data['type'] as String?) ?? PosBarcodeType.internal,
      label: data['label'] as String? ?? '',
      typeLabel: data['type_label'] as String? ?? '',
      isPrimary: data['is_primary'] as bool? ?? false,
    );
  }
}
