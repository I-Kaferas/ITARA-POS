import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../domain/cashier_preferences.dart';
import '../domain/screen_lock_controller.dart';
import 'lock_screen.dart';

/// Shows the Windows-style [LockScreen] after the chosen idle time
/// (or on Ctrl+L) while keeping the app state underneath.
class AutoLockGuard extends StatefulWidget {
  const AutoLockGuard({required this.child, super.key});

  final Widget child;

  @override
  State<AutoLockGuard> createState() => _AutoLockGuardState();
}

class _AutoLockGuardState extends State<AutoLockGuard> {
  final _lock = ScreenLockController.instance;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    CashierPreferences.instance.addListener(_arm);
    _lock.addListener(_onLockChanged);
    TerminalConfigRepository.instance.addListener(_onLockChanged);
    unawaited(_lock.load());
    _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    CashierPreferences.instance.removeListener(_arm);
    _lock.removeListener(_onLockChanged);
    TerminalConfigRepository.instance.removeListener(_onLockChanged);
    super.dispose();
  }

  void _onLockChanged() {
    if (!mounted) return;
    setState(() {});
    _arm();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyL &&
        HardwareKeyboard.instance.isControlPressed &&
        !_lock.locked) {
      unawaited(_lock.lock());
      return true;
    }
    _arm();
    return false;
  }

  void _arm() {
    _timer?.cancel();
    if (_lock.locked) return;
    final minutes = CashierPreferences.instance.autoLockMinutes;
    if (minutes <= 0) return;
    _timer = Timer(Duration(minutes: minutes), () => unawaited(_lock.lock()));
  }

  @override
  Widget build(BuildContext context) {
    final locked = _lock.locked;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _arm(),
      onPointerSignal: (_) => _arm(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: locked,
            child: widget.child,
          ),
          if (locked) const Positioned.fill(child: LockScreen()),
        ],
      ),
    );
  }
}
