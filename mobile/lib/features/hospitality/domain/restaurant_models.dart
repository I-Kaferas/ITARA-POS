/// Statuts restaurant (mobile.md §23).
enum RestaurantStatus {
  free,
  occupied,
  ordering,
  preparing,
  ready,
  served,
  paying,
  closed;

  String get wire => name.toUpperCase();

  String get label => switch (this) {
        RestaurantStatus.free => 'Libre',
        RestaurantStatus.occupied => 'Occupée',
        RestaurantStatus.ordering => 'Commande',
        RestaurantStatus.preparing => 'Préparation',
        RestaurantStatus.ready => 'Prête',
        RestaurantStatus.served => 'Servie',
        RestaurantStatus.paying => 'Paiement',
        RestaurantStatus.closed => 'Fermée',
      };

  static RestaurantStatus fromWire(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return RestaurantStatus.free;
    final key = raw.toLowerCase();
    // Legacy hospitality statuses → §23.
    return switch (key) {
      'free' || 'vacant' => RestaurantStatus.free,
      'occupied' || 'open' => RestaurantStatus.occupied,
      'ordering' || 'order' => RestaurantStatus.ordering,
      'preparing' || 'kitchen' || 'sent' => RestaurantStatus.preparing,
      'ready' => RestaurantStatus.ready,
      'served' => RestaurantStatus.served,
      'paying' || 'payment' => RestaurantStatus.paying,
      'closed' || 'paid' => RestaurantStatus.closed,
      _ => RestaurantStatus.values.firstWhere(
          (item) => item.name == key || item.wire == raw.toUpperCase(),
          orElse: () => RestaurantStatus.occupied,
        ),
    };
  }

  bool get isActive =>
      this != RestaurantStatus.free && this != RestaurantStatus.closed;

  bool get canOrder =>
      this == RestaurantStatus.occupied ||
      this == RestaurantStatus.ordering ||
      this == RestaurantStatus.served ||
      this == RestaurantStatus.ready;

  bool get canSendKitchen =>
      this == RestaurantStatus.ordering ||
      this == RestaurantStatus.occupied ||
      this == RestaurantStatus.served ||
      this == RestaurantStatus.ready;

  bool get canPay =>
      this == RestaurantStatus.served ||
      this == RestaurantStatus.ready ||
      this == RestaurantStatus.ordering ||
      this == RestaurantStatus.paying ||
      this == RestaurantStatus.preparing;
}

/// Ligne de commande avec extras / modifiers / accompagnements (§23).
class OrderLineDraft {
  const OrderLineDraft({
    required this.name,
    this.quantity = 1,
    this.unitPrice = 0,
    this.course = 'plat',
    this.productId,
    this.modifiers = const [],
    this.extras = const [],
    this.sides = const [],
    this.notes = '',
  });

  final String name;
  final int quantity;
  final int unitPrice;
  final String course;
  final String? productId;

  /// Modifiers (ex. cuisson, sans oignon).
  final List<String> modifiers;

  /// Extras payants (ex. fromage +).
  final List<Map<String, dynamic>> extras;

  /// Accompagnements (ex. frites, riz).
  final List<String> sides;
  final String notes;

  int get extrasTotal => extras.fold<int>(
        0,
        (sum, item) => sum + ((item['unit_price'] as num?)?.toInt() ?? 0),
      );

  int get lineTotal => (unitPrice + extrasTotal) * quantity;

  Map<String, dynamic> toJson({required String id, required String checkId}) => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'unit_price': unitPrice,
        'course': course,
        if (productId != null) 'product_id': productId,
        'check_id': checkId,
        'modifiers': modifiers,
        'extras': extras,
        'sides': sides,
        'accompagnements': sides,
        if (notes.isNotEmpty) 'notes': notes,
        'line_total': lineTotal,
      };
}
