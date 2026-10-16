import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../sync/offline_store.dart';
import '../../auth/data/pin_auth_service.dart';

/// Windows-style session lock: the app stays open underneath (cart, page)
/// and only the signed-in cashier's PIN unlocks it.
class ScreenLockController extends ChangeNotifier {
  ScreenLockController._();

  static final instance = ScreenLockController._();

  static const _lockedKey = 'pos_screen_locked';
  static const maxAttempts = 5;
  static const cooldown = Duration(seconds: 30);

  bool _locked = false;
  int _failures = 0;
  DateTime? _blockedUntil;

  /// Only a signed-in terminal can be locked; signing out drops the lock.
  bool get locked => _locked && canLock;

  bool get canLock {
    final repo = TerminalConfigRepository.instance;
    if (!repo.isLoaded) return false;
    final config = repo.config;
    return config.isConfigured && config.isSignedIn && config.authToken.trim().isNotEmpty;
  }

  Duration get remainingCooldown {
    final until = _blockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _locked = prefs.getBool(_lockedKey) ?? false;
    notifyListeners();
  }

  Future<void> lock() async {
    if (_locked || !canLock) return;
    _locked = true;
    _failures = 0;
    _blockedUntil = null;
    notifyListeners();
    await _persist();
  }

  /// Returns null on success, otherwise the message to show.
  Future<String?> unlock(String pin) async {
    if (remainingCooldown > Duration.zero) {
      return 'Trop de tentatives. Réessayez dans ${remainingCooldown.inSeconds + 1} s.';
    }
    if (!await _verify(pin)) {
      _failures += 1;
      if (_failures >= maxAttempts) {
        _failures = 0;
        _blockedUntil = DateTime.now().add(cooldown);
        notifyListeners();
        return 'Trop de tentatives. Réessayez dans ${cooldown.inSeconds} s.';
      }
      return 'PIN incorrect (${maxAttempts - _failures} essai(s) restant(s)).';
    }
    await _release();
    return null;
  }

  /// Leaves the lock through the PIN screen so another cashier can sign in.
  Future<void> switchUser() async {
    final repo = TerminalConfigRepository.instance;
    await _release();
    await repo.save(repo.config.copyWith(isSignedIn: false));
  }

  Future<bool> _verify(String pin) async {
    final config = TerminalConfigRepository.instance.config;
    if (config.cashierId.isNotEmpty && config.pinVerifier.isNotEmpty) {
      return PinAuthService.pinVerifier(config.cashierId, pin) == config.pinVerifier;
    }
    final offline = await OfflineStore.instance.findOfflineUserByPin(pin);
    if (offline != null) {
      final id = offline['id']?.toString() ?? '';
      return config.cashierId.isEmpty || id == config.cashierId;
    }
    try {
      final session = await PinAuthService().login(pin);
      return config.cashierId.isEmpty || session.id == config.cashierId;
    } catch (_) {
      return false;
    }
  }

  Future<void> _release() async {
    _locked = false;
    _failures = 0;
    _blockedUntil = null;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockedKey, _locked);
  }
}
