import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../onboarding_gate.dart';
import 'onboarding_frame.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

class OnboardingFinishScreen extends StatelessWidget {
  const OnboardingFinishScreen({
    super.key,
    this.canConfigure,
    this.canContinueOffline,
    this.onSignIn,
    this.onConfigure,
    this.onOffline,
  });

  /// Owner already signed in, terminal not configured yet.
  final bool? canConfigure;

  /// A configured terminal can reopen the existing PIN, including its offline path.
  final bool? canContinueOffline;

  final VoidCallback? onSignIn;
  final VoidCallback? onConfigure;
  final VoidCallback? onOffline;

  bool get _canConfigure {
    if (canConfigure != null) return canConfigure!;
    final config = TerminalConfigRepository.instance.config;
    return config.isSignedIn && !config.isConfigured;
  }

  bool get _canOffline {
    if (canContinueOffline != null) return canContinueOffline!;
    return TerminalConfigRepository.instance.isConfigured;
  }

  Future<void> _leave(
    BuildContext context,
    VoidCallback? override,
    String route,
  ) async {
    await OnboardingGate.instance.complete();
    if (!context.mounted) return;
    if (override != null) {
      override();
      return;
    }
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final configured = _canOffline;
    final signInRoute = configured ? AppRoutes.pin : AppRoutes.adminLogin;
    return OnboardingFrame(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: OnboardingPanel(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: OnboardingMark(compact: true)),
                const SizedBox(height: 22),
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: AppColors.success,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  tr('Prêt à ouvrir la caisse'),
                  textAlign: TextAlign.center,
                  style: AppTypography.text(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  tr('La connexion et les droits restent ceux déjà en place. Aucun compte n’est créé ici.'),
                  textAlign: TextAlign.center,
                  style: AppTypography.text(
                    fontSize: 15,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                OnboardingButton(
                  label: tr('Se connecter'),
                  primary: true,
                  onPressed: () => _leave(context, onSignIn, signInRoute),
                ),
                if (_canConfigure) ...[
                  const SizedBox(height: 10),
                  OnboardingButton(
                    label: tr('Configurer mon entreprise'),
                    onPressed: () =>
                        _leave(context, onConfigure, AppRoutes.configuration),
                  ),
                ],
                if (_canOffline) ...[
                  const SizedBox(height: 10),
                  OnboardingButton(
                    label: tr('Continuer hors ligne'),
                    onPressed: () => _leave(context, onOffline, AppRoutes.pin),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
