import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../sync/discovery/master_beacon.dart';

/// Panneau Slave §7 — liste des Masters découverts + CONNECT.
class DiscoveredMastersPanel extends StatelessWidget {
  const DiscoveredMastersPanel({
    super.key,
    required this.masters,
    required this.searching,
    required this.statusMessage,
    required this.onConnect,
    this.onRefresh,
  });

  final List<DiscoveredMaster> masters;
  final bool searching;
  final String statusMessage;
  final ValueChanged<DiscoveredMaster> onConnect;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    if (masters.isEmpty) {
      return Row(
        children: [
          if (searching) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              statusMessage,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          if (onRefresh != null)
            TextButton(
              onPressed: onRefresh,
              child: const Text('Relancer'),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Masters found',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...masters.map(
          (master) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MasterCard(
              master: master,
              onConnect: () => onConnect(master),
            ),
          ),
        ),
      ],
    );
  }
}

class _MasterCard extends StatelessWidget {
  const _MasterCard({
    required this.master,
    required this.onConnect,
  });

  final DiscoveredMaster master;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final online = master.isOnline;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  master.name,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  master.displayHost,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: online ? AppColors.success : AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      online ? 'Online' : 'Offline',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: online ? AppColors.success : AppColors.textMuted,
                      ),
                    ),
                    if (master.version.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        'v${master.version}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: online ? onConnect : null,
            child: const Text('CONNECT'),
          ),
        ],
      ),
    );
  }
}
