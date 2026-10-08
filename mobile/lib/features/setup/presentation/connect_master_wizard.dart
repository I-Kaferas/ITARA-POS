import 'package:flutter/material.dart';

import 'slave_setup_wizard.dart';

/// Backward-compatible alias — Slave Setup Wizard (mobile.md §48).
class ConnectMasterWizard extends StatelessWidget {
  const ConnectMasterWizard({super.key, this.onBackToWelcome});

  final VoidCallback? onBackToWelcome;

  @override
  Widget build(BuildContext context) => const SlaveSetupWizard();
}
