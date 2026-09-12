import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();
  static const _key = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    _mode = stored == 'dark' ? ThemeMode.dark : ThemeMode.light;
    _apply();
  }

  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    _apply();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, isDark ? 'dark' : 'light');
  }

  /// Re-bind palette after terminal/branding config changes.
  void applyFromConfig() {
    _apply();
    notifyListeners();
  }

  void _apply() {
    AppColors.bind(isDark ? AppPalette.dark : AppPalette.light);
  }
}

class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final dark = ThemeController.instance.isDark;
        return Tooltip(
          message: dark ? 'Thème clair' : 'Thème sombre',
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              onTap: ThemeController.instance.toggle,
              borderRadius: BorderRadius.circular(11),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 16,
                  color: AppColors.brandInk,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
