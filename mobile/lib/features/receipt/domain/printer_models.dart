import 'package:flutter/material.dart';

import '../../printers/domain/printer_connection_type.dart';
import 'receipt_models.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

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

  static final all = <PrinterModelPreset>[
    PrinterModelPreset(
      id: 'generic_58',
      label: tr('Ticket 58 mm'),
      brand: 'Générique',
      format: ReceiptDocumentFormat.thermal58,
      hint: tr('Petite caisse, souvent Bluetooth'),
      connection: PrinterConnectionType.bluetooth,
    ),
    PrinterModelPreset(
      id: 'generic_80',
      label: tr('Ticket 80 mm'),
      brand: 'Générique',
      format: ReceiptDocumentFormat.thermal80,
      hint: tr('Ticket standard réseau'),
    ),
    PrinterModelPreset(
      id: 'epson_tm_t20',
      label: tr('Epson TM-T20'),
      brand: 'Epson',
      format: ReceiptDocumentFormat.thermal80,
      hint: tr('USB, réseau ou Bluetooth'),
    ),
    PrinterModelPreset(
      id: 'epson_tm_t82',
      label: tr('Epson TM-T82'),
      brand: 'Epson',
      format: ReceiptDocumentFormat.thermal80,
      hint: tr('Ticket 80 mm'),
    ),
    PrinterModelPreset(
      id: 'epson_tm_t88',
      label: tr('Epson TM-T88'),
      brand: 'Epson',
      format: ReceiptDocumentFormat.thermal80,
      hint: tr('Ticket cuisine ou caisse'),
    ),
    PrinterModelPreset(
      id: 'star_tsp100',
      label: tr('Star TSP100'),
      brand: 'Star',
      format: ReceiptDocumentFormat.thermal80,
      hint: tr('Souvent en USB système'),
      connection: PrinterConnectionType.usb,
    ),
    PrinterModelPreset(
      id: 'star_tsp143',
      label: tr('Star TSP143'),
      brand: 'Star',
      format: ReceiptDocumentFormat.thermal80,
      hint: tr('Réseau ou USB'),
    ),
    PrinterModelPreset(
      id: 'star_tsp650',
      label: tr('Star TSP650'),
      brand: 'Star',
      format: ReceiptDocumentFormat.thermal80,
      hint: tr('Ticket 80 mm'),
    ),
    PrinterModelPreset(
      id: 'xprinter_58',
      label: tr('Xprinter 58'),
      brand: 'Xprinter',
      format: ReceiptDocumentFormat.thermal58,
      hint: tr('Bluetooth ou USB'),
      connection: PrinterConnectionType.bluetooth,
    ),
    PrinterModelPreset(
      id: 'xprinter_80',
      label: tr('Xprinter 80'),
      brand: 'Xprinter',
      format: ReceiptDocumentFormat.thermal80,
      hint: tr('Réseau ou USB'),
    ),
    PrinterModelPreset(
      id: 'bixolon_srp350',
      label: tr('Bixolon SRP-350'),
      brand: 'Bixolon',
      format: ReceiptDocumentFormat.thermal80,
      hint: tr('Ticket 80 mm'),
    ),
    PrinterModelPreset(
      id: 'rongta_80',
      label: tr('Rongta 80'),
      brand: 'Rongta',
      format: ReceiptDocumentFormat.thermal80,
      hint: tr('Ticket réseau'),
    ),
    PrinterModelPreset(
      id: 'sunmi',
      label: tr('Sunmi intégré'),
      brand: 'Sunmi',
      format: ReceiptDocumentFormat.thermal58,
      hint: tr('Imprimante du terminal Android'),
      connection: PrinterConnectionType.system,
    ),
    PrinterModelPreset(
      id: 'a4',
      label: tr('Imprimante A4'),
      brand: 'Bureau',
      format: ReceiptDocumentFormat.a4,
      hint: tr('Facture laser ou jet d’encre'),
      connection: PrinterConnectionType.system,
    ),
  ];

  static PrinterModelPreset byId(String? id) {
    return all.firstWhere((item) => item.id == id, orElse: () => all[1]);
  }
}

IconData printerConnectionIcon(PrinterConnectionType connection) =>
    connection.icon;
