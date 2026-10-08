class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.reference,
    this.supplierId = '',
    this.status = 'draft',
  });

  final String id;
  final String reference;
  final String supplierId;
  final String status;
}
