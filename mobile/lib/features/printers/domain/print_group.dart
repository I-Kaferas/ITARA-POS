/// Logical print destinations (mobile.md §39).
enum PrintGroup {
  kitchen,
  bar,
  cashier,
  reception,
  warehouse,
  dessert;

  static PrintGroup fromString(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    return PrintGroup.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => PrintGroup.cashier,
    );
  }

  String get label => switch (this) {
        PrintGroup.kitchen => 'Cuisine',
        PrintGroup.bar => 'Bar',
        PrintGroup.cashier => 'Caisse',
        PrintGroup.reception => 'Réception',
        PrintGroup.warehouse => 'Entrepôt',
        PrintGroup.dessert => 'Dessert',
      };
}
