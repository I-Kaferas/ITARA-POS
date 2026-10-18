import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import 'master_setup_wizard.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

/// Premier lancement §47 — Welcome / CREATE MASTER / CONNECT TO MASTER.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

enum _SetupPath { welcome, createMaster }

class _SetupScreenState extends State<SetupScreen> {
  _SetupPath _path = _SetupPath.welcome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: switch (_path) {
              _SetupPath.welcome => _WelcomePane(
                  onCreateMaster: () =>
                      setState(() => _path = _SetupPath.createMaster),
                  onConnectMaster: () => context.go(AppRoutes.slaveSetup),
                ),
              _SetupPath.createMaster => MasterSetupWizard(
                  onBackToWelcome: () =>
                      setState(() => _path = _SetupPath.welcome),
                ),
            },
          ),
        ),
      ),
    );
  }
}

class _WelcomePane extends StatelessWidget {
  const _WelcomePane({
    required this.onCreateMaster,
    required this.onConnectMaster,
  });

  final VoidCallback onCreateMaster;
  final VoidCallback onConnectMaster;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerRight,
            child: ThemeModeButton(),
          ),
          const SizedBox(height: 12),
          const LanguagePicker(),
          const Spacer(),
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brand50,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.point_of_sale, color: AppColors.brandInk, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            AppCopy.get('welcomeTitle'),
            style: AppTypography.text(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppCopy.get('welcomeBody'),
            style: AppTypography.text(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: onCreateMaster,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(AppCopy.get('createMaster')),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onConnectMaster,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(AppCopy.get('connectMaster')),
          ),
          const Spacer(flex: 2),
          Text(
            AppCopy.get('welcomeFoot'),
            textAlign: TextAlign.center,
            style: AppTypography.text(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
