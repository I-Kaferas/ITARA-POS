import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../sync/sync_engine.dart';
import '../../../sync/sync_models.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

/// Guided period close: upload, verify, back up, then clean local data.
Future<SyncReport?> showClosePeriodDialog(BuildContext context, {required bool toMaster}) {
  return showDialog<SyncReport>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ClosePeriodDialog(toMaster: toMaster),
  );
}

enum _StepState { waiting, running, done, failed }

class _ClosePeriodDialog extends StatefulWidget {
  const _ClosePeriodDialog({required this.toMaster});

  final bool toMaster;

  @override
  State<_ClosePeriodDialog> createState() => _ClosePeriodDialogState();
}

class _ClosePeriodDialogState extends State<_ClosePeriodDialog> {
  bool _understood = false;
  bool _running = false;
  ClosePeriodStep? _current;
  SyncReport? _report;

  String get _target => widget.toMaster ? 'le Master' : 'le cloud';

  List<(ClosePeriodStep, IconData, Color, String)> get _steps => [
        (ClosePeriodStep.upload, Icons.cloud_upload_rounded, AppColors.brandInk, 'Envoi des mouvements en attente…'),
        (ClosePeriodStep.verify, Icons.verified_rounded, AppColors.info, 'Vérification de la réception par $_target…'),
        (ClosePeriodStep.backup, Icons.save_rounded, AppColors.success, 'Sauvegarde locale…'),
        (ClosePeriodStep.clean, Icons.cleaning_services_rounded, AppColors.warning, 'Nettoyage des données locales…'),
      ];

  _StepState _stateOf(ClosePeriodStep step) {
    final current = _current;
    if (current == null) return _StepState.waiting;
    if (step.index < current.index) return _StepState.done;
    if (step.index > current.index) return _StepState.waiting;
    final report = _report;
    if (report == null) return _StepState.running;
    return report.ok ? _StepState.done : _StepState.failed;
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _report = null;
      _current = null;
    });
    final report = await SyncEngine.instance.closePeriod(
      onStep: (step) {
        if (mounted) setState(() => _current = step);
      },
    );
    if (!mounted) return;
    setState(() {
      _running = false;
      _report = report;
      _current ??= ClosePeriodStep.upload;
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final finished = report != null;
    return PopScope(
      canPop: !_running,
      child: Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.storefront_rounded, size: 34, color: AppColors.danger),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        tr('Clôturer la période'),
                        textAlign: TextAlign.center,
                        style: AppTypography.text(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (final step in _steps)
                        _StepRow(
                          icon: step.$2,
                          color: step.$3,
                          label: step.$4,
                          state: _stateOf(step.$1),
                        ),
                      const SizedBox(height: 8),
                      if (finished)
                        _Notice(
                          icon: report.ok ? Icons.check_circle_rounded : Icons.error_rounded,
                          color: report.ok ? AppColors.success : AppColors.danger,
                          text: report.message.isNotEmpty
                              ? report.message
                              : (report.ok ? 'Période clôturée.' : 'La période n’a pas été clôturée.'),
                        )
                      else
                        _Notice(
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.warning,
                          text: trf('Après vérification que tout est bien enregistré par {0}, cette ''action supprime définitivement de cet appareil les opérations ''synchronisées, les mouvements de stock des ventes confirmées et ''l’historique de synchro. Une sauvegarde locale est créée avant. ''Les ventes, les reçus et les quantités en stock restent intacts.', [_target]),
                        ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!finished)
                        InkWell(
                          onTap: _running ? null : () => setState(() => _understood = !_understood),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _understood,
                                  onChanged: _running ? null : (value) => setState(() => _understood = value ?? false),
                                  activeColor: AppColors.danger,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    tr('Je comprends que cette action est irréversible'),
                                    style: AppTypography.text(fontSize: 14, color: AppColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (finished)
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(report),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              tr('Fermer'),
                              style: AppTypography.text(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: _running ? null : () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                    side: BorderSide(color: AppColors.border),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: Text(
                                    tr('Annuler'),
                                    style: AppTypography.text(fontWeight: FontWeight.w600, fontSize: 15),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: FilledButton.icon(
                                  onPressed: _understood && !_running ? _start : null,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.danger,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: AppColors.surfaceVariant,
                                    disabledForegroundColor: AppColors.textMuted,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  icon: _running
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.textMuted,
                                          ),
                                        )
                                      : const Icon(Icons.storefront_rounded, size: 18),
                                  label: Text(
                                    tr(_running ? 'Clôture…' : 'Clôturer'),
                                    style: AppTypography.text(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.state,
  });

  final IconData icon;
  final Color color;
  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final trailing = switch (state) {
      _StepState.waiting => const SizedBox.shrink(),
      _StepState.running => SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
      _StepState.done => const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.success),
      _StepState.failed => const Icon(Icons.cancel_rounded, size: 20, color: AppColors.danger),
    };
    final active = state != _StepState.waiting;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              tr(label),
              style: AppTypography.text(
                fontSize: 15,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(text),
              style: AppTypography.text(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
