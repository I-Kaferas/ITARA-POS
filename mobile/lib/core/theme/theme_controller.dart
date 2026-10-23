import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final ThemeController instance = ThemeController._();
  static const _key = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;

  /// The mobile app stays on the light theme, same as the web vitrine.
  bool get isDark => false;

  Future<void> load() async {
    _mode = ThemeMode.light;
    _apply();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'light');
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = ThemeMode.light;
    _apply();
  }

  Future<void> cycle() async {
    await setMode(ThemeMode.light);
  }

  Future<void> toggle() async {
    await setMode(ThemeMode.light);
  }

  /// Re-bind palette after terminal/branding config changes.
  void applyFromConfig() {
    _apply();
    notifyListeners();
  }

  @override
  void didChangePlatformBrightness() {}

  void _apply() {
    AppColors.bind(isDark ? AppPalette.dark : AppPalette.light);
  }
}

class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key, this.compact = true});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(key: ValueKey<bool>(compact), width: 0, height: 0);
  }
}

/// Screens read [AppColors], the active language and the settings singletons
/// directly and stay mounted, so a change has to ask every element to build again.
class ThemeRefresh extends StatefulWidget {
  const ThemeRefresh({required this.child, this.sources = const [], super.key});

  final Widget child;

  /// Extra settings that must repaint the whole app when they change.
  final List<Listenable> sources;

  @override
  State<ThemeRefresh> createState() => _ThemeRefreshState();
}

class _ThemeRefreshState extends State<ThemeRefresh> {
  late Listenable _listenable;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _listenable = Listenable.merge([ThemeController.instance, ...widget.sources]);
    _listenable.addListener(_rebuildTree);
  }

  @override
  void didUpdateWidget(covariant ThemeRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (listEquals(oldWidget.sources, widget.sources)) return;
    _listenable.removeListener(_rebuildTree);
    _listenable = Listenable.merge([ThemeController.instance, ...widget.sources]);
    _listenable.addListener(_rebuildTree);
  }

  @override
  void dispose() {
    _listenable.removeListener(_rebuildTree);
    super.dispose();
  }

  void _rebuildTree() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      void visit(Element element) {
        element.markNeedsBuild();
        element.visitChildren(visit);
      }

      context.visitChildElements(visit);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
