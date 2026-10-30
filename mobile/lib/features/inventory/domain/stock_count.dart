enum StockCountKind {
  full('full', 'Inventaire complet'),
  cycle('cycle', 'Comptage cyclique'),
  verification('verification', 'Vérification');

  const StockCountKind(this.wire, this.label);

  final String wire;
  final String label;

  static StockCountKind parse(String? raw) => StockCountKind.values.firstWhere(
        (kind) => kind.wire == raw,
        orElse: () => StockCountKind.full,
      );
}

/// `draft` → being counted, `variance` → checked with gaps, `verified` → checked
/// without gap, `posted` → gaps written to stock.
abstract final class StockCountStatusWire {
  static const draft = 'draft';
  static const variance = 'variance';
  static const verified = 'verified';
  static const posted = 'posted';
}

class StockCountLine {
  const StockCountLine({
    required this.productId,
    required this.name,
    required this.expectedQty,
    this.countedQty,
  });

  final String productId;
  final String name;
  final int expectedQty;
  final int? countedQty;

  int? get variance => countedQty == null ? null : countedQty! - expectedQty;

  StockCountLine withCounted(int? value) => StockCountLine(
        productId: productId,
        name: name,
        expectedQty: expectedQty,
        countedQty: value,
      );
}

class StockCountSheet {
  const StockCountSheet({
    required this.id,
    required this.kind,
    required this.status,
    required this.lines,
    required this.createdAt,
    this.warehouseId,
  });

  final String id;
  final StockCountKind kind;
  final String status;
  final List<StockCountLine> lines;
  final DateTime createdAt;
  final String? warehouseId;

  bool get isPosted => status == StockCountStatusWire.posted;

  int get countedLines => lines.where((line) => line.countedQty != null).length;

  int get varianceLines => lines.where((line) => (line.variance ?? 0) != 0).length;
}
