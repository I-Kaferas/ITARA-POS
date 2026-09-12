import 'package:flutter/material.dart';

import '../../services/hid_scanner_controller.dart';

/// Hidden input that listens for USB / Bluetooth keyboard-wedge scanners.
class HidScannerField extends StatefulWidget {
  const HidScannerField({
    super.key,
    required this.controller,
    this.autofocus = true,
  });

  final HidScannerController controller;
  final bool autofocus;

  @override
  State<HidScannerField> createState() => _HidScannerFieldState();
}

class _HidScannerFieldState extends State<HidScannerField> {
  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.focusNode.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.controller.focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: widget.controller.handleKeyEvent,
      child: Opacity(
        opacity: 0,
        child: SizedBox(
          height: 1,
          width: 1,
          child: TextField(
            controller: widget.controller.textController,
            enableInteractiveSelection: false,
            showCursor: false,
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
      ),
    );
  }
}
