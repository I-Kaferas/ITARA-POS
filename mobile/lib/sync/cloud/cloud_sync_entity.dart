/// Entities exchanged Master → ITARA ERP Cloud (mobile.md §35).
enum CloudSyncEntity {
  sales('sale', 'Ventes', CloudSyncDirection.bidirectional),
  payments('payment', 'Paiements', CloudSyncDirection.push),
  stocks('stock', 'Stocks', CloudSyncDirection.bidirectional),
  products('product', 'Produits', CloudSyncDirection.pull),
  customers('customer', 'Clients', CloudSyncDirection.bidirectional),
  orders('order', 'Commandes', CloudSyncDirection.push),
  expenses('expense', 'Dépenses', CloudSyncDirection.push),
  users('user', 'Utilisateurs', CloudSyncDirection.pull),
  configuration('configuration', 'Configuration', CloudSyncDirection.bidirectional),
  auditLogs('audit_log', 'Journaux d’audit', CloudSyncDirection.push);

  const CloudSyncEntity(this.wire, this.label, this.direction);

  final String wire;
  final String label;
  final CloudSyncDirection direction;

  bool get canPush =>
      direction == CloudSyncDirection.push ||
      direction == CloudSyncDirection.bidirectional;

  bool get canPull =>
      direction == CloudSyncDirection.pull ||
      direction == CloudSyncDirection.bidirectional;

  static CloudSyncEntity? tryParse(String? raw) {
    final key = (raw ?? '').trim().toLowerCase();
    for (final item in CloudSyncEntity.values) {
      if (item.wire == key || item.name.toLowerCase() == key) return item;
    }
    // Legacy aliases from the outbox / sync_queue.
    return switch (key) {
      'sales' => CloudSyncEntity.sales,
      'payments' => CloudSyncEntity.payments,
      'stock_movement' || 'stocks' => CloudSyncEntity.stocks,
      'products' => CloudSyncEntity.products,
      'customers' => CloudSyncEntity.customers,
      'orders' || 'restaurant_order' => CloudSyncEntity.orders,
      'expenses' => CloudSyncEntity.expenses,
      'users' => CloudSyncEntity.users,
      'config' || 'settings' => CloudSyncEntity.configuration,
      'audit' || 'audit_logs' => CloudSyncEntity.auditLogs,
      _ => null,
    };
  }
}

enum CloudSyncDirection { push, pull, bidirectional }
