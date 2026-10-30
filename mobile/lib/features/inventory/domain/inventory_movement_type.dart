/// Stock movement kinds the POS can post. [wire] matches the backend
/// `InventoryMovementType` values accepted by `/sync/push`.
enum InventoryMovementType {
  purchase('PURCHASE', 1, 'Entrée (achat)'),
  adjustmentIn('ADJUSTMENT_IN', 1, 'Ajustement +'),
  saleReturn('SALE_RETURN', 1, 'Retour client'),
  adjustmentOut('ADJUSTMENT_OUT', -1, 'Sortie'),
  purchaseReturn('PURCHASE_RETURN', -1, 'Retour fournisseur'),
  damage('DAMAGE', -1, 'Casse'),
  loss('LOSS', -1, 'Perte'),
  expired('EXPIRED', -1, 'Périmé'),
  transferOut('TRANSFER_OUT', -1, 'Transfert sortant'),
  transferIn('TRANSFER_IN', 1, 'Transfert entrant');

  const InventoryMovementType(this.wire, this.sign, this.label);

  final String wire;
  final int sign;
  final String label;

  bool get isInbound => sign > 0;

  bool get isWaste =>
      this == InventoryMovementType.damage ||
      this == InventoryMovementType.loss ||
      this == InventoryMovementType.expired;

  static InventoryMovementType? tryParse(String? raw) {
    final value = (raw ?? '').trim().toUpperCase();
    for (final type in InventoryMovementType.values) {
      if (type.wire == value) return type;
    }
    return null;
  }

  /// Types offered by the manual movement form (transfers have their own flow).
  static const manual = [
    purchase,
    adjustmentIn,
    saleReturn,
    adjustmentOut,
    purchaseReturn,
    damage,
    loss,
    expired,
  ];
}
