import 'package:flutter/material.dart';

/// Hides SnackBar chrome via theme so action success/refusal toasts stay invisible.
class SilentScaffoldMessenger extends StatelessWidget {
  const SilentScaffoldMessenger({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SnackBarTheme(
      data: SnackBarThemeData(
        backgroundColor: const Color(0x00000000),
        elevation: 0,
        contentTextStyle: const TextStyle(fontSize: 0.1, height: 0.01, color: Color(0x00000000)),
        behavior: SnackBarBehavior.floating,
        insetPadding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(),
        dismissDirection: DismissDirection.none,
        actionTextColor: const Color(0x00000000),
        disabledActionTextColor: const Color(0x00000000),
      ),
      child: child,
    );
  }
}
