import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Soft shimmer placeholder for premium perceived performance.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius,
    this.margin,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;

  /// Convenience row of skeleton lines for list / card loading.
  static Widget list({int count = 4, double height = 64}) {
    return Column(
      children: List.generate(
        count,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i == count - 1 ? 0 : AppSpacing.sm),
          child: AppSkeleton(
            width: double.infinity,
            height: height,
            borderRadius: AppRadius.borderLg,
          ),
        ),
      ),
    );
  }

  static Widget card({double height = 120}) {
    return AppSkeleton(
      width: double.infinity,
      height: height,
      borderRadius: AppRadius.borderLg,
    );
  }

  static Widget text({double width = 120, double height = 12}) {
    return AppSkeleton(width: width, height: height);
  }

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppColors.brand50;
    final highlight = AppColors.brand100;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? AppRadius.borderSm,
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3 * _controller.value, 0),
              end: Alignment(-0.5 + 3 * _controller.value, 0),
              colors: [base, highlight, base],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}

/// Full-page skeleton shell for route transitions.
class AppSkeletonPage extends StatelessWidget {
  const AppSkeletonPage({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton.text(width: 180, height: 22),
          const SizedBox(height: AppSpacing.sm),
          AppSkeleton.text(width: 260, height: 12),
          const SizedBox(height: AppSpacing.xl),
          Expanded(child: AppSkeleton.list(count: rows, height: 72)),
        ],
      ),
    );
  }
}

/// Fade between skeleton and content once ready.
class AppSkeletonGate extends StatelessWidget {
  const AppSkeletonGate({
    super.key,
    required this.loading,
    required this.child,
    this.skeleton,
  });

  final bool loading;
  final Widget child;
  final Widget? skeleton;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.normal,
      switchInCurve: AppMotion.standard,
      switchOutCurve: AppMotion.decelerate,
      child: loading
          ? KeyedSubtree(
              key: const ValueKey('skeleton'),
              child: skeleton ?? const AppSkeletonPage(),
            )
          : KeyedSubtree(
              key: const ValueKey('content'),
              child: child,
            ),
    );
  }
}
