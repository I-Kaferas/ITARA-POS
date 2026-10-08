import 'package:flutter/material.dart';

/// Station function chosen during Slave setup (mobile.md §48).
enum SlaveStationRole {
  cashier,
  kitchen,
  bar,
  reception,
  warehouse;

  static SlaveStationRole fromString(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    return SlaveStationRole.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => SlaveStationRole.cashier,
    );
  }

  String get label => switch (this) {
        SlaveStationRole.cashier => 'Cashier',
        SlaveStationRole.kitchen => 'Kitchen',
        SlaveStationRole.bar => 'Bar',
        SlaveStationRole.reception => 'Reception',
        SlaveStationRole.warehouse => 'Warehouse',
      };

  String get labelFr => switch (this) {
        SlaveStationRole.cashier => 'Caisse',
        SlaveStationRole.kitchen => 'Cuisine',
        SlaveStationRole.bar => 'Bar',
        SlaveStationRole.reception => 'Réception',
        SlaveStationRole.warehouse => 'Entrepôt',
      };

  String get suggestedDeviceName => switch (this) {
        SlaveStationRole.cashier => 'POS-01',
        SlaveStationRole.kitchen => 'KDS-01',
        SlaveStationRole.bar => 'BAR-01',
        SlaveStationRole.reception => 'RCP-01',
        SlaveStationRole.warehouse => 'WH-01',
      };

  IconData get icon => switch (this) {
        SlaveStationRole.cashier => Icons.point_of_sale_outlined,
        SlaveStationRole.kitchen => Icons.soup_kitchen_outlined,
        SlaveStationRole.bar => Icons.local_bar_outlined,
        SlaveStationRole.reception => Icons.desk_outlined,
        SlaveStationRole.warehouse => Icons.warehouse_outlined,
      };
}
