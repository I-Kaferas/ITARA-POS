/// Kitchen Display ticket statuses (mobile.md §24).
enum KitchenTicketStatus {
  neu,
  preparing,
  ready,
  served,
  cancelled;

  /// Wire value: NEW / PREPARING / READY / SERVED / CANCELLED.
  String get wire => switch (this) {
        KitchenTicketStatus.neu => 'NEW',
        KitchenTicketStatus.preparing => 'PREPARING',
        KitchenTicketStatus.ready => 'READY',
        KitchenTicketStatus.served => 'SERVED',
        KitchenTicketStatus.cancelled => 'CANCELLED',
      };

  /// Persistence / hospitality desk value (lowercase).
  String get storage => switch (this) {
        KitchenTicketStatus.neu => 'new',
        _ => name,
      };

  String get label => switch (this) {
        KitchenTicketStatus.neu => 'Nouveau',
        KitchenTicketStatus.preparing => 'Préparation',
        KitchenTicketStatus.ready => 'Prêt',
        KitchenTicketStatus.served => 'Servi',
        KitchenTicketStatus.cancelled => 'Annulé',
      };

  /// Next status when advancing the ticket on the KDS.
  KitchenTicketStatus? get next => switch (this) {
        KitchenTicketStatus.neu => KitchenTicketStatus.preparing,
        KitchenTicketStatus.preparing => KitchenTicketStatus.ready,
        KitchenTicketStatus.ready => KitchenTicketStatus.served,
        KitchenTicketStatus.served || KitchenTicketStatus.cancelled => null,
      };

  String get advanceLabel => switch (next) {
        KitchenTicketStatus.preparing => 'Préparer',
        KitchenTicketStatus.ready => 'Prêt',
        KitchenTicketStatus.served => 'Servi',
        _ => '',
      };

  bool get isOpen =>
      this != KitchenTicketStatus.served && this != KitchenTicketStatus.cancelled;

  /// Accepts NEW/new/sent/queued and CANCELLED/canceled.
  static KitchenTicketStatus fromWire(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return KitchenTicketStatus.neu;
    final key = raw.toLowerCase();
    return switch (key) {
      'new' || 'sent' || 'queued' || 'neu' => KitchenTicketStatus.neu,
      'preparing' => KitchenTicketStatus.preparing,
      'ready' => KitchenTicketStatus.ready,
      'served' => KitchenTicketStatus.served,
      'cancelled' || 'canceled' => KitchenTicketStatus.cancelled,
      _ => KitchenTicketStatus.values.firstWhere(
          (item) => item.name == key || item.wire == raw.toUpperCase(),
          orElse: () => KitchenTicketStatus.neu,
        ),
    };
  }
}
