import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../sync/pairing_models.dart';
import '../bloc/master_pairing_bloc.dart';

/// Panneau Master §8 — code + QR + demandes ACCEPT / REJECT.
class PairingApprovalPanel extends StatelessWidget {
  const PairingApprovalPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MasterPairingBloc, MasterPairingState>(
      builder: (context, state) {
        final code = state.masterCode;
        final qr = state.qrPayload;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code == null
                            ? 'Code d\'appairage : —'
                            : 'Code: $code',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Discovery → Handshake → Auth → Pairing → Authorization',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => context
                            .read<MasterPairingBloc>()
                            .add(const MasterPairingCodeRefreshRequested()),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Nouveau code'),
                      ),
                    ],
                  ),
                ),
                if (qr != null) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: BarcodeWidget(
                      barcode: Barcode.qrCode(),
                      data: qr.encode(),
                      width: 96,
                      height: 96,
                      drawText: false,
                    ),
                  ),
                ],
              ],
            ),
            if (state.pendingRequests.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Demandes d\'appairage',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...state.pendingRequests.map(
                (req) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PendingPairCard(request: req),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'En attente d\'un Slave. Affichez le code ou le QR.',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PendingPairCard extends StatelessWidget {
  const _PendingPairCard({required this.request});

  final PairingRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.wantsToConnectLabel,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Code: ${request.code}'
            '${request.os.isEmpty ? '' : ' · ${request.os}'}'
            '${request.ip.isEmpty ? '' : ' · ${request.ip}'}',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                onPressed: () => context.read<MasterPairingBloc>().add(
                      MasterPairingAcceptRequested(request.id),
                    ),
                child: const Text('ACCEPT'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => context.read<MasterPairingBloc>().add(
                      MasterPairingRejectRequested(request.id),
                    ),
                child: const Text('REJECT'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

