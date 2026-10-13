import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local "has the presentation been finished" flag.
///
/// This is not a tenant, a role, or a sync state. It never stores credentials.
class OnboardingGate extends ChangeNotifier {
  OnboardingGate._();

  static final OnboardingGate instance = OnboardingGate._();

  static const storageKey = 'itara_presentation_completed';

  bool seen = false;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(storageKey) ?? false;
    } catch (_) {
      seen = false;
    }
    notifyListeners();
  }

  Future<void> complete() async {
    if (seen) return;
    seen = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(storageKey, true);
    } catch (_) {
      // The in-memory flag still avoids a loop for this session.
    }
  }
}
