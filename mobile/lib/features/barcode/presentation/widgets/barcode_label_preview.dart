import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../domain/barcode_models.dart';

class BarcodeLabelPreview extends StatelessWidget {
  const BarcodeLabelPreview({
    super.key,
    required this.barcode,
    required this.type,
    this.label,
    this.height = 120,
  });

  final String barcode;
  final PosBarcodeType type;
  final String? label;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null && label!.isNotEmpty) ...[
          Text(
            label!,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: height,
          child: BarcodeWidget(
            barcode: _symbology(),
            data: barcode,
            drawText: true,
            width: double.infinity,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${type.label} · $barcode',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Barcode _symbology() {
    return switch (type) {
      PosBarcodeType.ean13 => Barcode.ean13(),
      PosBarcodeType.ean8 => Barcode.ean8(),
      PosBarcodeType.upc => Barcode.upcA(),
      PosBarcodeType.qr => Barcode.qrCode(),
      PosBarcodeType.code128 => Barcode.code128(),
      PosBarcodeType.internal => Barcode.code128(),
    };
  }
}
