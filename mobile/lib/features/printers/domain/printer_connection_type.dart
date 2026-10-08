import 'package:flutter/material.dart';

/// Physical / logical link to a printer (mobile.md §37).
enum PrinterConnectionType {
  usb,
  lan,
  ethernet,
  wifi,
  bluetooth,
  /// OS-installed printer (Windows spooler / Android print service).
  system;

  static PrinterConnectionType fromString(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    // Legacy alias from earlier configs / spooler rows.
    if (raw == 'network') return PrinterConnectionType.lan;
    return PrinterConnectionType.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => PrinterConnectionType.system,
    );
  }

  String get label => switch (this) {
        PrinterConnectionType.usb => 'USB',
        PrinterConnectionType.lan => 'LAN',
        PrinterConnectionType.ethernet => 'Ethernet',
        PrinterConnectionType.wifi => 'Wi-Fi',
        PrinterConnectionType.bluetooth => 'Bluetooth',
        PrinterConnectionType.system => 'Système',
      };

  String get hint => switch (this) {
        PrinterConnectionType.usb => 'Imprimante branchée en USB sur ce terminal',
        PrinterConnectionType.lan => 'Imprimante ticket sur le réseau local (port 9100)',
        PrinterConnectionType.ethernet => 'Imprimante câblée Ethernet (IP fixe)',
        PrinterConnectionType.wifi => 'Imprimante Wi-Fi sur le même réseau',
        PrinterConnectionType.bluetooth => 'Imprimante appairée en Bluetooth',
        PrinterConnectionType.system => 'Imprimante Windows ou Android déjà installée',
      };

  /// Needs host + port (raw socket / JetDirect).
  bool get isNetwork =>
      this == PrinterConnectionType.lan ||
      this == PrinterConnectionType.ethernet ||
      this == PrinterConnectionType.wifi;

  bool get usesBluetoothAddress => this == PrinterConnectionType.bluetooth;

  bool get usesUsbPath => this == PrinterConnectionType.usb;

  bool get usesSystemName => this == PrinterConnectionType.system;

  IconData get icon => switch (this) {
        PrinterConnectionType.usb => Icons.usb,
        PrinterConnectionType.lan => Icons.lan_outlined,
        PrinterConnectionType.ethernet => Icons.settings_ethernet,
        PrinterConnectionType.wifi => Icons.wifi,
        PrinterConnectionType.bluetooth => Icons.bluetooth,
        PrinterConnectionType.system => Icons.print_outlined,
      };
}
