import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Captures keyboard-wedge input from USB and Bluetooth HID scanners.
///
/// Most retail scanners emulate a keyboard: they type the barcode quickly
/// and send Enter/Return at the end.
class HidScannerController {
  HidScannerController({
    this.onScan,
    this.scanSuffix = const [
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
    ],
    this.interKeyThreshold = const Duration(milliseconds: 80),
  });

  final void Function(String barcode)? onScan;
  final List<LogicalKeyboardKey> scanSuffix;
  final Duration interKeyThreshold;

  final FocusNode focusNode = FocusNode();
  final TextEditingController textController = TextEditingController();

  DateTime? _lastKeyTime;
  String _buffer = '';

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // Let POS desktop shortcuts / navigation through (F1–F12, Esc, Tab…).
    if (_isPassthroughKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }

    final now = DateTime.now();
    if (_lastKeyTime != null &&
        now.difference(_lastKeyTime!) > interKeyThreshold) {
      _buffer = '';
    }
    _lastKeyTime = now;

    if (scanSuffix.contains(event.logicalKey)) {
      final value = _buffer.trim();
      _buffer = '';
      textController.clear();
      if (value.isNotEmpty) {
        onScan?.call(value);
      }
      return KeyEventResult.handled;
    }

    final character = event.character;
    if (character != null && character.isNotEmpty) {
      _buffer += character;
      textController.text = _buffer;
      textController.selection = TextSelection.collapsed(offset: _buffer.length);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  static bool _isPassthroughKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.home ||
        key == LogicalKeyboardKey.end ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      return true;
    }
    // F1–F12
    final id = key.keyId;
    return id >= LogicalKeyboardKey.f1.keyId && id <= LogicalKeyboardKey.f12.keyId;
  }

  void dispose() {
    focusNode.dispose();
    textController.dispose();
  }
}
