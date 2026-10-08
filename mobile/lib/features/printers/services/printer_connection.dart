import 'dart:io';

import 'package:printing/printing.dart' as printing;

import '../domain/printer.dart';
import '../domain/printer_connection_type.dart';

class PrinterConnectionResult {
  const PrinterConnectionResult({
    required this.ok,
    this.message = '',
    this.latencyMs,
  });

  final bool ok;
  final String message;
  final int? latencyMs;

  factory PrinterConnectionResult.success({String message = 'OK', int? latencyMs}) =>
      PrinterConnectionResult(ok: true, message: message, latencyMs: latencyMs);

  factory PrinterConnectionResult.failure(String message) =>
      PrinterConnectionResult(ok: false, message: message);
}

/// Opens / probes a printer over USB, LAN, Ethernet, Wi-Fi, Bluetooth, or system.
class PrinterConnection {
  const PrinterConnection({
    this.probeTimeout = const Duration(milliseconds: 800),
  });

  final Duration probeTimeout;

  Future<PrinterConnectionResult> probe(Printer printer) async {
    if (!printer.enabled) {
      return PrinterConnectionResult.failure('Imprimante désactivée');
    }

    switch (printer.connection) {
      case PrinterConnectionType.lan:
      case PrinterConnectionType.ethernet:
      case PrinterConnectionType.wifi:
        return _probeNetwork(printer);
      case PrinterConnectionType.usb:
        return _probeUsb(printer);
      case PrinterConnectionType.bluetooth:
        return _probeBluetooth(printer);
      case PrinterConnectionType.system:
        return _probeSystem(printer);
    }
  }

  /// Validates endpoint configuration before enqueueing.
  PrinterConnectionResult validate(Printer printer) {
    switch (printer.connection) {
      case PrinterConnectionType.lan:
      case PrinterConnectionType.ethernet:
      case PrinterConnectionType.wifi:
        if (printer.host.trim().isEmpty) {
          return PrinterConnectionResult.failure('Adresse IP manquante');
        }
        if (printer.port <= 0 || printer.port > 65535) {
          return PrinterConnectionResult.failure('Port invalide');
        }
      case PrinterConnectionType.usb:
        if (printer.usbPath.isEmpty && printer.systemName.isEmpty) {
          return PrinterConnectionResult.failure('Chemin USB ou nom système manquant');
        }
      case PrinterConnectionType.bluetooth:
        if (printer.bluetoothAddress.trim().isEmpty) {
          return PrinterConnectionResult.failure('Adresse Bluetooth manquante');
        }
      case PrinterConnectionType.system:
        if (printer.systemName.isEmpty && printer.name.isEmpty) {
          return PrinterConnectionResult.failure('Nom d’imprimante système manquant');
        }
    }
    return PrinterConnectionResult.success(message: 'Configuration valide');
  }

  /// Socket URL used by the printing package for network transports.
  String? networkSocketUrl(Printer printer) {
    if (!printer.connection.isNetwork || printer.host.isEmpty) return null;
    return 'socket://${printer.host}:${printer.port}';
  }

  Future<PrinterConnectionResult> _probeNetwork(Printer printer) async {
    final host = printer.host.trim();
    if (host.isEmpty) {
      return PrinterConnectionResult.failure('Adresse IP manquante');
    }
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, printer.port, timeout: probeTimeout);
      await socket.close();
      sw.stop();
      return PrinterConnectionResult.success(
        message: '${printer.connection.label} joignable',
        latencyMs: sw.elapsedMilliseconds,
      );
    } catch (error) {
      return PrinterConnectionResult.failure(
        'Impossible de joindre $host:${printer.port} (${printer.connection.label}): $error',
      );
    }
  }

  Future<PrinterConnectionResult> _probeUsb(Printer printer) async {
    // USB thermal printers are exposed via the OS print subsystem on Windows/Android.
    if (printer.systemName.isNotEmpty || printer.usbPath.isNotEmpty) {
      final target = printer.systemName.isNotEmpty ? printer.systemName : printer.usbPath;
      try {
        final printers = await printing.Printing.listPrinters();
        final match = printers.any(
          (item) =>
              item.name == target ||
              item.url.contains(target) ||
              item.name.toLowerCase().contains(target.toLowerCase()),
        );
        if (match) {
          return PrinterConnectionResult.success(message: 'USB / système trouvé');
        }
        return PrinterConnectionResult.failure('Périphérique USB introuvable: $target');
      } catch (error) {
        return PrinterConnectionResult.failure('Scan USB impossible: $error');
      }
    }
    return PrinterConnectionResult.success(
      message: 'USB prêt (chemin à picker sur le terminal)',
    );
  }

  Future<PrinterConnectionResult> _probeBluetooth(Printer printer) async {
    final address = printer.bluetoothAddress.trim();
    if (address.isEmpty) {
      return PrinterConnectionResult.failure('Adresse Bluetooth manquante');
    }
    final normalized = address.replaceAll('-', ':').toUpperCase();
    final macOk = RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(normalized);
    if (!macOk && !address.startsWith('btspp://')) {
      return PrinterConnectionResult.failure('Adresse Bluetooth invalide: $address');
    }
    return PrinterConnectionResult.success(
      message: 'Bluetooth configuré ($normalized)',
    );
  }

  Future<PrinterConnectionResult> _probeSystem(Printer printer) async {
    final name = printer.systemName.isNotEmpty ? printer.systemName : printer.name;
    try {
      final printers = await printing.Printing.listPrinters();
      if (name.isEmpty) {
        if (printers.isEmpty) {
          return PrinterConnectionResult.failure('Aucune imprimante système');
        }
        return PrinterConnectionResult.success(
          message: '${printers.length} imprimante(s) système',
        );
      }
      final match = printers.where((item) => item.name == name).toList();
      if (match.isEmpty) {
        return PrinterConnectionResult.failure('Imprimante système introuvable: $name');
      }
      final available = match.first.isAvailable;
      return available
          ? PrinterConnectionResult.success(message: 'Système disponible')
          : PrinterConnectionResult.failure('Imprimante système indisponible');
    } catch (error) {
      return PrinterConnectionResult.failure('Liste système impossible: $error');
    }
  }
}
