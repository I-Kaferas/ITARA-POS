/// Aggregate KPIs shown on the dashboard.
class DashboardSummary {
  const DashboardSummary({
    this.salesToday = 0,
    this.ordersOpen = 0,
    this.lowStock = 0,
    this.syncPending = 0,
  });

  final num salesToday;
  final int ordersOpen;
  final int lowStock;
  final int syncPending;
}
