class StockBalance {
  const StockBalance({
    required this.productId,
    required this.quantity,
    this.locationId = '',
  });

  final String productId;
  final num quantity;
  final String locationId;
}
