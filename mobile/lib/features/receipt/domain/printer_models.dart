import 'package:flutter/material.dart';

import '../../printers/domain/printer_connection_type.dart';
import 'receipt_models.dart';

export '../../printers/domain/printer_connection_type.dart';

class PrinterModelPreset {
  const PrinterModelPreset({
    required this.id,
    required this.label,
    required this.brand,
    required this.format,
    required this.hint,
    this.defaultPort = 9100,
    this.connection = PrinterConnectionType.lan,
  });

  final String id;
  final String label;
  final String brand;
  final ReceiptDocumentFormat format;
  final int defaultPort;
  final String hint;
  final PrinterConnectionType connection;

  static const all = <PrinterModelPreset>[
    PrinterModelPreset(
      id: 'generic_58',
      label: 'Ticket 58 mm',
      brand: 'Générique',
      format: ReceiptDocumentFormat.thermal58,
      hint: 'Petite caisse, souvent Bluetooth',
      connection: PrinterConnectionType.bluetooth,
    ),
    PrinterModelPreset(
      id: 'generic_80',
      label: 'Ticket 80 mm',
      brand: 'Générique',
      format: ReceiptDocumentFormat.thermal80,
      hint: 'Ticket standard réseau',
    ),
    PrinterModelPreset(
      id: 'epson_tm_t20',
      label: 'Epson TM-T20',
      brand: 'Epson',
      format: ReceiptDocumentFormat.thermal80,
      hint: 'USB, réseau ou Bluetooth',
    ),
    PrinterModelPreset(
      id: 'epson_tm_t82',
      label: 'Epson TM-T82',
      brand: 'Epson',
      format: ReceiptDocumentFormat.thermal80,
      hint: 'Ticket 80 mm',
    ),
    PrinterModelPreset(
      id: 'epson_tm_t88',
      label: 'Epson TM-T88',
      brand: 'Epson',
      format: ReceiptDocumentFormat.thermal80,
      hint: 'Ticket cuisine ou caisse',
    ),
    PrinterModelPreset(
      id: 'star_tsp100',
      label: 'Star TSP100',
      brand: 'Star',
      format: ReceiptDocumentFormat.thermal80,
      hint: 'Souvent en USB système',
      connection: PrinterConnectionType.usb,
    ),
    PrinterModelPreset(
      id: 'star_tsp143',
      label: 'Star TSP143',
      brand: 'Star',
      format: ReceiptDocumentFormat.thermal80,
      hint: 'Réseau ou USB',
    ),
    PrinterModelPreset(
      id: 'star_tsp650',
      label: 'Star TSP650',
      brand: 'Star',
      format: ReceiptDocumentFormat.thermal80,
      hint: 'Ticket 80 mm',
    ),
    PrinterModelPreset(
      id: 'xprinter_58',
      label: 'Xprinter 58',
      brand: 'Xprinter',
      format: ReceiptDocumentFormat.thermal58,
      hint: 'Bluetooth ou USB',
      connection: PrinterConnectionType.bluetooth,
    ),
    PrinterModelPreset(
      id: 'xprinter_80',
      label: 'Xprinter 80',
      brand: 'Xprinter',
      format: ReceiptDocumentFormat.thermal80,
      hint: 'Réseau ou USB',
    ),
    PrinterModelPreset(
      id: 'bixolon_srp350',
      label: 'Bixolon SRP-350',
      brand: 'Bixolon',
      format: ReceiptDocumentFormat.thermal80,
      hint: 'Ticket 80 mm',
    ),
    PrinterModelPreset(
      id: 'rongta_80',
      label: 'Rongta 80',
      brand: 'Rongta',
      format: ReceiptDocumentFormat.thermal80,
      hint: 'Ticket réseau',
    ),
    PrinterModelPreset(
      id: 'sunmi',
      label: 'Sunmi intégré',
      brand: 'Sunmi',
      format: ReceiptDocumentFormat.thermal58,
      hint: 'Imprimante du terminal Android',
      connection: PrinterConnectionType.system,
    ),
    PrinterModelPreset(
      id: 'a4',
      label: 'Imprimante A4',
      brand: 'Bureau',
      format: ReceiptDocumentFormat.a4,
      hint: 'Facture laser ou jet d’encre',
      connection: PrinterConnectionType.system,
    ),
  ];

  static PrinterModelPreset byId(String? id) {
    return all.firstWhere((item) => item.id == id, orElse: () => all[1]);
  }
}

IconData printerConnectionIcon(PrinterConnectionType connection) =>
    connection.icon;
