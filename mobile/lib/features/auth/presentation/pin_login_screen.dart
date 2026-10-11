import 'package:flutter/material.dart';

import 'auth_gate_screen.dart';

class PinLoginScreen extends StatelessWidget {
  const PinLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthGateScreen(initialMode: AuthGateMode.staff);
  }
}
