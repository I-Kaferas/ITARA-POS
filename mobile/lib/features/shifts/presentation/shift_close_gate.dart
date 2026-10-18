import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../sync/sync_engine.dart';
import '../../pos/domain/pos_models.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import '../data/local_shifts_store.dart';
import '../domain/shift_models.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Syncs, then lists open and unpaid orders. The close-shift form opens only after this step.
Future<bool> showShiftCloseGate(
  BuildContext context, {
  required List<ShiftInvoice> unpaid,
  required List<Map<String, dynamic>> holds,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ShiftCloseGate(unpaid: unpaid, holds: holds),
  ).then((value) => value ?? false);
}

class _ShiftCloseGate extends StatefulWidget {
  const _ShiftCloseGate({required this.unpaid, required this.holds});

  final List<ShiftInvoice> unpaid;
  final List<Map<String, dynamic>> holds;

  @override
  State<_ShiftCloseGate> createState() => _ShiftCloseGateState();
}

class _ShiftCloseGateState extends State<_ShiftCloseGate> {
  bool _syncing = true;
  String _syncMessage = 'Synchronisation…';
  bool _syncOk = true;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  Future<void> _sync() async {
    try {
      final report = await SyncEngine.instance.syncNow();
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _syncOk = report.ok;
        _syncMessage = report.message.trim().isEmpty
            ? (report.ok ? 'Synchronisation terminée' : 'La synchronisation n’a pas abouti')
            : report.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _syncOk = false;
        _syncMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openHold(Map<String, dynamic> hold) async {
    PosHeldSale? sale;
    try {
      sale = PosHeldSale.fromLocalJson(hold);
    } catch (_) {}
    if (!mounted) return;
    final lines = sale?.lines ?? const <PosCartLine>[];
    await showDialog<void>(
      context: context,
      builder: (context) => _OrderDetailDialog(
        title: sale?.label.trim().isNotEmpty == true ? sale!.label : _holdLabel(hold),
        subtitle: [
          if ((sale?.customer?.displayLabel ?? '').isNotEmpty) sale!.customer!.displayLabel,
          if ((sale?.tableLabel ?? '').isNotEmpty) sale!.tableLabel!,
          if ((sale?.note ?? '').trim().isNotEmpty) sale!.note!.trim(),
        ].join(' · '),
        total: sale?.total ?? _holdTotal(hold),
        lines: [
          for (final line in lines)
            (name: line.displayName, quantity: line.quantity, unitPrice: line.unitPrice),
        ],
      ),
    );
  }

  Future<void> _openInvoice(ShiftInvoice invoice) async {
    final lines = await LocalShiftsStore.instance.linesForReference(invoice.reference);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _OrderDetailDialog(
        title: invoice.reference.isEmpty ? tr('Vente') : invoice.reference,
        subtitle: [
          if ((invoice.customerName ?? '').trim().isNotEmpty) invoice.customerName!.trim(),
          if ((invoice.method ?? '').trim().isNotEmpty) tr(invoice.method!),
          trf('Reste {0}', [MoneyFormatter.format(invoice.outstanding > 0 ? invoice.outstanding : invoice.total)]),
        ].join(' · '),
        total: invoice.outstanding > 0 ? invoice.outstanding : invoice.total,
        lines: lines,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.holds.length + widget.unpaid.length;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PosUi.radiusXl)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('Synchronisation avant clôture'),
                style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                tr('Les commandes encore ouvertes ou non payées. Touchez une ligne pour le détail.'),
                style: GoogleFonts.ibmPlexSans(fontSize: 12.5, color: AppColors.textSecondary, height: 1.35),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (_syncing ? AppColors.info : (_syncOk ? AppColors.success : AppColors.warning)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_syncing ? AppColors.info : (_syncOk ? AppColors.success : AppColors.warning)).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    if (_syncing)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        _syncOk ? Icons.cloud_done_rounded : Icons.sync_problem_rounded,
                        size: 18,
                        color: _syncOk ? AppColors.success : AppColors.warning,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr(_syncMessage),
                        style: GoogleFonts.ibmPlexSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                trf('Commandes en attente ({0})', [count]),
                style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: count == 0
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          tr('Aucune commande en attente.'),
                          style: GoogleFonts.ibmPlexSans(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      )
                    : ListView(
                        children: [
                          for (final hold in widget.holds)
                            _OrderTile(
                              title: _holdLabel(hold),
                              subtitle: tr('Encaissement en attente'),
                              amount: _holdTotal(hold),
                              onTap: () => _openHold(hold),
                            ),
                          for (final invoice in widget.unpaid)
                            _OrderTile(
                              title: invoice.reference.isEmpty ? tr('Vente') : invoice.reference,
                              subtitle: invoice.customerName?.trim().isNotEmpty == true
                                  ? invoice.customerName!.trim()
                                  : tr(invoice.method ?? 'impayée'),
                              amount: invoice.outstanding > 0 ? invoice.outstanding : invoice.total,
                              onTap: () => _openInvoice(invoice),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(tr('Annuler')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: PosUi.ctaHeight - 4,
                      child: FilledButton(
                        onPressed: _syncing ? null : () => Navigator.pop(context, true),
                        child: Text(tr('Continuer vers Fermer le shift')),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  MoneyFormatter.format(amount),
                  style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderDetailDialog extends StatelessWidget {
  const _OrderDetailDialog({
    required this.title,
    required this.subtitle,
    required this.total,
    required this.lines,
  });

  final String title;
  final String subtitle;
  final int total;
  final List<({String name, int quantity, int unitPrice})> lines;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PosUi.radiusXl)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: GoogleFonts.ibmPlexSans(fontSize: 17, fontWeight: FontWeight.w700)),
              if (subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.ibmPlexSans(fontSize: 12.5, color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 14),
              Expanded(
                child: lines.isEmpty
                    ? Text(
                        tr('Aucun article (commande distante sans détail local).'),
                        style: GoogleFonts.ibmPlexSans(fontSize: 13, color: AppColors.textSecondary),
                      )
                    : ListView(
                        children: [
                          for (final line in lines)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          line.name,
                                          style: GoogleFonts.ibmPlexSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          trf('{0} × {1}', [line.quantity, MoneyFormatter.format(line.unitPrice)]),
                                          style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    MoneyFormatter.format(line.unitPrice * line.quantity),
                                    style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('Total'),
                      style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    MoneyFormatter.format(total),
                    style: GoogleFonts.ibmPlexSans(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('Fermer'))),
            ],
          ),
        ),
      ),
    );
  }
}

String _holdLabel(Map<String, dynamic> hold) {
  final label = hold['label']?.toString().trim() ?? '';
  if (label.isNotEmpty) return label;
  final table = hold['table_label']?.toString().trim() ?? '';
  if (table.isNotEmpty) return table;
  final customer = hold['customer'];
  if (customer is Map) {
    final name = customer['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
  }
  return tr('Commande ouverte');
}

int _holdTotal(Map<String, dynamic> hold) {
  try {
    return PosHeldSale.fromLocalJson(hold).total;
  } catch (_) {
    return 0;
  }
}
