class UnitConversionException implements Exception {
  const UnitConversionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One way to enter a quantity for a product: the base unit (factor 1) or a
/// packaging such as "Bouteille 750 ml" (factor 750 base units).
class InventoryUnit {
  const InventoryUnit({required this.id, required this.label, required this.factor});

  final String id;
  final String label;
  final num factor;

  bool get isBase => factor == 1;
}

abstract final class UnitConverter {
  /// Quantity entered in a unit → stock base units (ml, g, piece…).
  static int toBase({required num quantity, required num factor}) {
    if (quantity <= 0) throw const UnitConversionException('Quantité invalide');
    if (factor <= 0) throw const UnitConversionException('Facteur de conversion invalide');
    final base = (quantity * factor).round();
    if (base <= 0) throw const UnitConversionException('Quantité trop petite pour cette unité');
    return base;
  }

  /// Base units → whole packages plus the remainder, e.g. 1600 ml / 750 → 2 + 100.
  static ({int whole, int remainder}) split({required int base, required int factor}) {
    if (factor <= 1) return (whole: base, remainder: 0);
    return (whole: base ~/ factor, remainder: base % factor);
  }
}
