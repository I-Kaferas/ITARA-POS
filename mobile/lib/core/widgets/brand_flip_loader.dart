import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Full-screen white flip used while the app signs in, matching the web loader.
class BrandFlipLoader extends StatefulWidget {
  const BrandFlipLoader({super.key, this.label});

  final String? label;

  @override
  State<BrandFlipLoader> createState() => _BrandFlipLoaderState();
}

class _BrandFlipLoaderState extends State<BrandFlipLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final front = tr('ITARA');
    final back = widget.label ?? tr('Chargement');
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final turning = (_controller.value % 1) < 0.5;
            final local = turning ? _controller.value / 0.5 : 1;
            final angle = local * math.pi;
            final showBack = angle > math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(showBack ? angle - math.pi : angle),
              child: Text(
                showBack ? back : front,
                style: AppTypography.text(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
