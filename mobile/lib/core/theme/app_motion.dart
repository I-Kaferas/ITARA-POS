import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared motion tokens. POS stays snappy: motion never blocks a sale.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration micro = Duration(milliseconds: 140);
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration content = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration navigation = Duration(milliseconds: 260);
  static const Duration modal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 360);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
  static const Curve decelerate = Curves.decelerate;

  /// Horizontal travel for hierarchical screens. Kept short so the cashier is not waiting.
  static const double slideFraction = 0.045;

  static bool reduceMotion(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context);
  }

  static Duration resolve(BuildContext context, Duration duration) {
    return reduceMotion(context) ? Duration.zero : duration;
  }

  static final Set<Object> _entrances = <Object>{};
  static final List<Object> _entranceOrder = <Object>[];

  /// True only the first time [id] appears. Refresh and navigation do not replay it.
  static bool claimEntrance(Object id) {
    if (!_entrances.add(id)) return false;
    _entranceOrder.add(id);
    if (_entranceOrder.length > 600) {
      _entrances.remove(_entranceOrder.removeAt(0));
    }
    return true;
  }

  static void resetEntrances() {
    _entrances.clear();
    _entranceOrder.clear();
  }
}

/// Fade plus a short horizontal slide. Honors the system reduce-motion setting.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduceMotion(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(AppMotion.slideFraction, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Swaps to the real next value. Does not count through fake intermediate amounts.
class AppValueFade extends StatelessWidget {
  const AppValueFade({
    super.key,
    required this.value,
    required this.child,
  });

  final Object value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.resolve(context, AppMotion.micro),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      child: KeyedSubtree(
        key: ValueKey<Object>(value),
        child: child,
      ),
    );
  }
}

/// System haptics. Skipped when the device asks to reduce motion.
/// A vibration never means a sale succeeded.
abstract final class AppHaptics {
  static void selection(BuildContext context) {
    if (AppMotion.reduceMotion(context)) return;
    HapticFeedback.selectionClick();
  }

  static void warning(BuildContext context) {
    if (AppMotion.reduceMotion(context)) return;
    HapticFeedback.lightImpact();
  }
}

/// Plays [AppFadeIn] once per [id]. Later rebuilds stay still.
class AppOnce extends StatefulWidget {
  const AppOnce({super.key, required this.id, required this.child});

  final Object id;
  final Widget child;

  @override
  State<AppOnce> createState() => _AppOnceState();
}

class _AppOnceState extends State<AppOnce> {
  late final bool _play = AppMotion.claimEntrance(widget.id);

  @override
  Widget build(BuildContext context) {
    if (!_play || AppMotion.reduceMotion(context)) return widget.child;
    return AppFadeIn(duration: AppMotion.content, child: widget.child);
  }
}

/// Subtle press scale for tactile POS controls.
class AppTapScale extends StatefulWidget {
  const AppTapScale({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.scale = 0.97,
    this.haptic = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double scale;
  final bool haptic;

  @override
  State<AppTapScale> createState() => _AppTapScaleState();
}

class _AppTapScaleState extends State<AppTapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduceMotion(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: !reduce && widget.enabled && widget.onTap != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.enabled
          ? () {
              if (widget.haptic) AppHaptics.selection(context);
              widget.onTap?.call();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: AppMotion.resolve(context, AppMotion.micro),
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}

/// Counts an integer up. The first run lasts 1.2s from zero.
/// Later changes ease from the current value in at most 400ms.
class AppCountUp extends StatefulWidget {
  const AppCountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
  });

  final int value;
  final String Function(int value) format;
  final TextStyle? style;

  @override
  State<AppCountUp> createState() => _AppCountUpState();
}

class _AppCountUpState extends State<AppCountUp> with SingleTickerProviderStateMixin {
  late int _shown = 0;
  bool _first = true;
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _animateTo(widget.value, first: true));
  }

  @override
  void didUpdateWidget(covariant AppCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _animateTo(widget.value, first: false);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _animateTo(int next, {required bool first}) {
    if (!mounted) return;
    if (AppMotion.reduceMotion(context)) {
      setState(() => _shown = next);
      _first = false;
      return;
    }
    final from = first || _first ? 0 : _shown;
    _first = false;
    _controller?.dispose();
    final duration = first ? const Duration(milliseconds: 1200) : const Duration(milliseconds: 400);
    final controller = AnimationController(vsync: this, duration: AppMotion.resolve(context, duration));
    _controller = controller;
    controller.addListener(() {
      if (!mounted) return;
      final t = AppMotion.standard.transform(controller.value);
      setState(() => _shown = from + ((next - from) * t).round());
    });
    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Text(widget.format(_shown), style: widget.style);
  }
}

/// Raises a card 4px on pointer hover. Touch presses stay still.
class AppHoverLift extends StatefulWidget {
  const AppHoverLift({super.key, required this.child});

  final Widget child;

  @override
  State<AppHoverLift> createState() => _AppHoverLiftState();
}

class _AppHoverLiftState extends State<AppHoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final lift = _hover && !AppMotion.reduceMotion(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: AppMotion.resolve(context, AppMotion.fast),
        curve: AppMotion.standard,
        transform: Matrix4.translationValues(0, lift ? -4 : 0, 0),
        child: widget.child,
      ),
    );
  }
}

/// Lightweight fade+slide entrance for lists and sheets.
class AppFadeIn extends StatelessWidget {
  const AppFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.normal,
    this.offset = const Offset(0, 0.04),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(
        delay.inMilliseconds / (duration + delay).inMilliseconds,
        1,
        curve: AppMotion.standard,
      ),
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12 * offset.dy / 0.04),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
