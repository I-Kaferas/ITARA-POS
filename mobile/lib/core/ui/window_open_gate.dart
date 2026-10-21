import 'dart:async';

import 'package:flutter/foundation.dart';

/// One in-flight window action.
///
/// Clicks that arrive while the machine is frozen are delivered together when
/// it recovers. They all share the action already running, and the button
/// flag is cleared when that action ends or throws. A new instance — a
/// process started after a crash or a reboot — does not inherit the flag.
class WindowOpenGate {
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);
  Future<void>? _flight;

  Future<void> run(Future<void> Function() action) {
    final current = _flight;
    if (current != null) return current;
    final completer = Completer<void>();
    _flight = completer.future;
    busy.value = true;
    () async {
      try {
        await action();
      } catch (_) {
        // Callers fire this from a button. The lock and the button reset below.
      } finally {
        if (identical(_flight, completer.future)) {
          _flight = null;
          busy.value = false;
        }
        if (!completer.isCompleted) completer.complete();
      }
    }();
    return completer.future;
  }
}

/// Opens one window, or focuses the one that is already open.
///
/// A window that [isOpen] reports is never replaced. A failed [create] still
/// focuses the window when the native side actually created one.
Future<void> openSingleWindow({
  required Future<bool> Function() isOpen,
  required Future<void> Function() focus,
  required Future<void> Function() create,
}) async {
  if (await isOpen()) {
    try {
      await focus();
    } catch (_) {}
    return;
  }
  try {
    await create();
  } catch (_) {
    if (await isOpen()) {
      try {
        await focus();
      } catch (_) {}
      return;
    }
    rethrow;
  }
}
