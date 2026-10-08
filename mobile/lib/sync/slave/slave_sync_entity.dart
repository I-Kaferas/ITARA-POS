/// Entities pushed Slave → Master (mobile.md §34).
enum SlaveSyncEntity {
  sales('sale', 'Ventes'),
  payments('payment', 'Paiements'),
  orders('order', 'Commandes'),
  stockMovements('stock', 'Mouvements de stock'),
  expenses('expense', 'Dépenses'),
  customers('customer', 'Clients'),
  cashMovements('cash_movement', 'Mouvements de caisse'),
  shifts('shift', 'Shifts');

  const SlaveSyncEntity(this.wire, this.label);

  final String wire;
  final String label;

  /// All §34 entities — used by harvest / accept matrices.
  static const outbound = SlaveSyncEntity.values;

  static SlaveSyncEntity? tryParse(String? raw) {
    final key = (raw ?? '').trim().toLowerCase();
    for (final item in SlaveSyncEntity.values) {
      if (item.wire == key || item.name.toLowerCase() == key) return item;
    }
    return switch (key) {
      'sales' => SlaveSyncEntity.sales,
      'payments' => SlaveSyncEntity.payments,
      'orders' || 'restaurant_order' => SlaveSyncEntity.orders,
      'stock_movement' || 'stocks' || 'stock_movements' => SlaveSyncEntity.stockMovements,
      'expenses' => SlaveSyncEntity.expenses,
      'customers' => SlaveSyncEntity.customers,
      'cash_movements' || 'cash' => SlaveSyncEntity.cashMovements,
      'shifts' || 'cashier_shift' => SlaveSyncEntity.shifts,
      _ => null,
    };
  }
}
