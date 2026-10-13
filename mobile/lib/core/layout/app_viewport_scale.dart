import 'package:flutter/material.dart';

/// Draws the whole app 10% smaller while still filling the window.
///
/// Layout runs on a canvas 1/0.9 times larger, then that canvas is fitted
/// back into the real window. Text, buttons and spacing all shrink together.
class AppViewportScale extends StatelessWidget {
  const AppViewportScale({required this.child, super.key});

  static const scale = 0.9;

  final Widget child;

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
