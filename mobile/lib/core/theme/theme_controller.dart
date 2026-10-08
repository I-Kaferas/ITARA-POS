import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';
import 'theme_cubit.dart';

class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final ThemeController instance = ThemeController._();
  static const _key = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  /// Resolved dark flag (honours System mode via platform brightness).
  bool get isDark {
    if (_mode == ThemeMode.dark) return true;
    if (_mode == ThemeMode.light) return false;
    return _platformBrightness == Brightness.dark;
  }

  Brightness get _platformBrightness =>
      SchedulerBinding.instance.platformDispatcher.platformBrightness;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    _mode = switch (stored) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.system,
    };
    _apply();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    _apply();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      switch (_mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      },
    );
  }

  /// Cycles Light → Dark → System → Light.
  Future<void> cycle() async {
    await setMode(switch (_mode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    });
  }

  /// Legacy toggle (Light ↔ Dark). Prefer [cycle] for System support.
  Future<void> toggle() async {
    await setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  /// Re-bind palette after terminal/branding config changes.
  void applyFromConfig() {
    _apply();
    notifyListeners();
  }

  @override
  void didChangePlatformBrightness() {
    if (_mode == ThemeMode.system) {
      _apply();
      notifyListeners();
    }
  }

  void _apply() {
    AppColors.bind(isDark ? AppPalette.dark : AppPalette.light);
  }
}

class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key, this.compact = true});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, state) {
        final (icon, label) = switch (state.mode) {
          ThemeMode.light => (Icons.light_mode_outlined, 'Clair'),
          ThemeMode.dark => (Icons.dark_mode_outlined, 'Sombre'),
          ThemeMode.system => (Icons.brightness_auto_outlined, 'Système'),
        };

        return Tooltip(
          message: 'Thème : $label (toucher pour changer)',
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              onTap: () => context.read<ThemeCubit>().cycle(),
              borderRadius: BorderRadius.circular(11),
              child: Container(
                width: compact ? 34 : null,
                height: 34,
                padding: compact
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: AppColors.brandInk),
                    if (!compact) ...[
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
