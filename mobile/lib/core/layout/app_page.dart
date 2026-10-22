import 'package:flutter/material.dart';

import 'android_form_factor.dart';

/// Shared page chrome: SafeArea, horizontal padding, optional max width.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
    this.safe = true,
    this.scrollable = false,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;
  final bool safe;
  final bool scrollable;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? AndroidLayout.pagePadding(context);
    final cap = maxWidth ?? AndroidLayout.contentMaxWidth(context);

    Widget body = Padding(
      padding: pad,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: cap),
          child: scrollable
              ? SingleChildScrollView(child: child)
              : child,
        ),
      ),
    );

    if (safe) {
      body = SafeArea(child: body);
    }

    if (backgroundColor != null) {
      body = ColoredBox(color: backgroundColor!, child: body);
    }

    return body;
  }
}
