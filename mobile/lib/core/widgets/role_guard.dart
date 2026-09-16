import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/terminal_config_repository.dart';
import '../theme/app_colors.dart';

class SlaveModeBanner extends StatelessWidget {
  const SlaveModeBanner({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final config = TerminalConfigRepository.instance.config;
    if (!config.isSlave) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.violet500.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.devices_other, color: AppColors.violet500, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode Esclave',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.violet500,
                      ),
                ),
                Text(
                  message ??
                      'Accès limité — les opérations sont relayées au terminal Master.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (config.masterHost.isNotEmpty)
                  Text(
                    'Master: ${config.masterHost}',
                    style: GoogleFonts.ibmPlexMono(fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoleGuard extends StatelessWidget {
  const RoleGuard({
    super.key,
    required this.allowed,
    required this.child,
    this.fallbackMessage,
  });

  final bool allowed;
  final Widget child;
  final String? fallbackMessage;

  @override
  Widget build(BuildContext context) {
    if (allowed) return child;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              TerminalConfigRepository.instance.config.posRole.icon,
              size: 48,
              color: AppColors.violet500,
            ),
            const SizedBox(height: 16),
            Text(
              'Non disponible en mode ${TerminalConfigRepository.instance.config.posRole.label}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              fallbackMessage ??
                  'Cette fonctionnalité est réservée au terminal Master ou Autonome.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
