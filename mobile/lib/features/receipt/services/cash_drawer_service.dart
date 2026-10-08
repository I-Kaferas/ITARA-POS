import 'dart:io';
import 'dart:typed_data';

import '../../../core/config/terminal_config_repository.dart';

/// Opens a cash drawer via ESC/POS kick on a network thermal printer.
///
/// Most POS printers expose the drawer on RJ-11/RJ-12 and open it with:
/// `ESC p m t1 t2` (0x1B 0x70 …).
class CashDrawerService {
  CashDrawerService({
    this.connectTimeout = const Duration(seconds: 2),
  });

  final Duration connectTimeout;

  /// Standard ESC/POS pulse on pin 2 (drawer connector).
  static Uint8List get escPosKickPin2 => Uint8List.fromList(const [
        0x1B, // ESC
        0x70, // p
        0x00, // pin 2
        0x19, // t1 on-time
        0xFA, // t2 off-time
      ]);

  /// Alternate pulse on pin 5 (some Epson / Star harnesses).
  static Uint8List get escPosKickPin5 => Uint8List.fromList(const [
        0x1B,
        0x70,
        0x01,
        0x19,
        0xFA,
      ]);

  /// True when the payment likely involved cash (drawer should open).
  static bool shouldOpenForPayment({
    required String method,
    int change = 0,
  }) {
    final normalized = method.trim().toLowerCase();
    if (change > 0) return true;
    return normalized == 'cash' ||
        normalized.contains('cash') ||
        normalized.contains('espèce') ||
        normalized.contains('espece');
  }

  Future<bool> openFromTerminalConfig({bool alsoTryPin5 = false}) async {
    final config = TerminalConfigRepository.instance.config;
    if (!config.printerEnabled && config.printerHost.trim().isEmpty) {
      return false;
    }
    final host = config.printerHost.trim();
    if (host.isEmpty) return false;
    final port = config.printerPort <= 0 ? 9100 : config.printerPort;
    return openNetwork(host: host, port: port, alsoTryPin5: alsoTryPin5);
  }

  Future<bool> openNetwork({
    required String host,
    int port = 9100,
    bool alsoTryPin5 = false,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: connectTimeout);
      socket.add(escPosKickPin2);
      if (alsoTryPin5) {
        socket.add(escPosKickPin5);
      }
      await socket.flush();
      return true;
    } catch (_) {
      return false;
    } finally {
      await socket?.close();
    }
  }
}
