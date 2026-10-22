import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Draws the whole app a little smaller while still filling the window.
///
/// Layout runs on a larger canvas, then that canvas is fitted back into the
/// real window. Text, buttons and spacing all shrink together.
///
/// Applied on **desktop** only (Windows / macOS / Linux). On Android / iOS the
/// real device metrics are used so breakpoints and touch targets stay accurate.
class AppViewportScale extends StatelessWidget {
  const AppViewportScale({required this.child, super.key});

  static const scale = 0.84;

  final Widget child;

  static bool get enabled {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  EdgeInsets _divide(EdgeInsets insets) {
    return EdgeInsets.fromLTRB(
      insets.left / scale,
      insets.top / scale,
      insets.right / scale,
      insets.bottom / scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final media = MediaQuery.of(context);
    final width = media.size.width / scale;
    final height = media.size.height / scale;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: width,
          height: height,
          child: MediaQuery(
            data: media.copyWith(
              size: Size(width, height),
              padding: _divide(media.padding),
              viewPadding: _divide(media.viewPadding),
              viewInsets: _divide(media.viewInsets),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
