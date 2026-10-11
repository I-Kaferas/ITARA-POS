import 'package:flutter/material.dart';

import 'auth_gate_screen.dart';

class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthGateScreen(initialMode: AuthGateMode.root);
  }
}
