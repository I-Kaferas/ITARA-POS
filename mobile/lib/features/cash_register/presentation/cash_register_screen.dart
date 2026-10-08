import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_error_view.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import '../domain/cash_register_models.dart';
import 'bloc/cash_register_bloc.dart';

class CashRegisterScreen extends StatelessWidget {
  const CashRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CashRegisterBloc()..add(const CashRegisterStarted()),
      child: const _CashRegisterView(),
    );
  }
}

class _CashRegisterView extends StatelessWidget {
  const _CashRegisterView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CashRegisterBloc, CashRegisterState>(
      listenWhen: (prev, next) =>
          prev.message != next.message || prev.errorMessage != next.errorMessage,
      listener: (context, state) {
        final text = state.errorMessage ?? state.message;
        if (text == null || text.isEmpty) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      },
      builder: (context, state) {
        final register = state.selectedRegister;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              openCount: state.registers.where((r) => r.hasOpenSession).length,
              onRefresh: () => context.read<CashRegisterBloc>().add(const CashRegisterRefreshed()),
            ),
            Expanded(
              child: ColoredBox(
                color: AppColors.canvas,
                child: state.isLoading && state.registers.isEmpty
                    ? const LoadingView(message: 'Chargement des caisses...')
                    : state.status == CashRegisterStatus.failure && state.registers.isEmpty
                        ? ErrorView(
                            message: state.errorMessage ?? 'Erreur',
                            onRetry: () => context
                                .read<CashRegisterBloc>()
                                .add(const CashRegisterStarted()),
                          )
                        : state.registers.isEmpty
                            ? const EmptyState(
                                icon: Icons.point_of_sale_outlined,
                                title: 'Aucune caisse',
                                subtitle: 'Créez une caisse depuis l’ERP ou le module Shifts.',
                              )
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                                children: [
                                  _RegisterPicker(
                                    registers: state.registers,
                                    selectedId: state.selectedRegisterId,
                                    onChanged: (id) {
                                      if (id != null) {
                                        context
                                            .read<CashRegisterBloc>()
                                            .add(CashRegisterSelected(id));
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  if (register != null) ...[
                                    _ReconciliationCard(
                                      register: register,
                                      summary: state.summary,
                                      reconciliation: state.reconciliation,
                                    ),
                                    const SizedBox(height: 14),
                                    _ActionsGrid(
                                      register: register,
                                      busy: state.busy,
                                      expectedCash: state.reconciliation?.expectedCash ??
                                          state.summary?.expectedCash ??
                                          register.openSession?.expectedCash ??
                                          0,
                                    ),
                                  ],
                                ],
                              ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.openCount, required this.onRefresh});

  final int openCount;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brand50,
              borderRadius: BorderRadius.circular(PosUi.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(Icons.point_of_sale, color: AppColors.brandInk, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Caisse',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                PosBadge(
                  label: openCount > 0
                      ? '$openCount ouverte${openCount > 1 ? 's' : ''}'
                      : 'Aucune ouverte',
                  tone: openCount > 0 ? PosBadgeTone.success : PosBadgeTone.neutral,
                  compact: true,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
    );
  }
}

class _RegisterPicker extends StatelessWidget {
  const _RegisterPicker({
    required this.registers,
    required this.selectedId,
    required this.onChanged,
  });

  final List<CashRegister> registers;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(PosUi.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId,
          isExpanded: true,
          hint: const Text('Choisir une caisse'),
          items: registers
              .map(
                (r) => DropdownMenuItem(
                  value: r.id,
                  child: Text('${r.name} · ${r.code}${r.hasOpenSession ? ' · Ouverte' : ''}'),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ReconciliationCard extends StatelessWidget {
  const _ReconciliationCard({
    required this.register,
    this.summary,
    this.reconciliation,
  });

  final CashRegister register;
  final RegisterSummary? summary;
  final Reconciliation? reconciliation;

  @override
  Widget build(BuildContext context) {
    final expected = reconciliation?.expectedCash ??
        summary?.expectedCash ??
        register.openSession?.expectedCash ??
        0;
    final actual = reconciliation?.actualCash ?? summary?.actualCash;
    final difference = reconciliation?.difference ??
        summary?.difference ??
        (actual != null ? actual - expected : null);

    Color differenceColor = AppColors.textPrimary;
    if (difference != null && difference != 0) {
      differenceColor = difference > 0 ? AppColors.success : AppColors.danger;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(PosUi.radiusXl),
        border: Border.all(
          color: register.hasOpenSession
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  register.name,
                  style: GoogleFonts.ibmPlexSans(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              PosBadge(
                label: register.hasOpenSession ? 'Ouverte' : 'Fermée',
                tone: register.hasOpenSession ? PosBadgeTone.success : PosBadgeTone.neutral,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(register.code, style: PosUi.caption()),
          const SizedBox(height: 16),
          Text('RÉCONCILIATION', style: PosUi.totalCaption()),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(
                label: 'Expected Cash',
                value: MoneyFormatter.format(expected),
              ),
              _Metric(
                label: 'Actual Cash',
                value: actual != null ? MoneyFormatter.format(actual) : '—',
              ),
              _Metric(
                label: 'Difference',
                value: difference != null ? MoneyFormatter.format(difference) : '—',
                valueColor: differenceColor,
              ),
            ],
          ),
          if (summary != null && register.hasOpenSession) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _Chip(label: 'Ouverture', value: MoneyFormatter.format(summary!.openingBalance)),
                _Chip(label: 'Ventes', value: MoneyFormatter.format(summary!.salesTotal)),
                _Chip(label: 'Cash In', value: MoneyFormatter.format(summary!.cashInTotal)),
                _Chip(label: 'Cash Out', value: MoneyFormatter.format(summary!.cashOutTotal)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(PosUi.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: PosUi.caption()),
            const SizedBox(height: 6),
            Text(
              value,
              style: PosUi.money(size: 13, color: valueColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(PosUi.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Text('$label · $value', style: PosUi.caption()),
    );
  }
}

class _ActionsGrid extends StatelessWidget {
  const _ActionsGrid({
    required this.register,
    required this.busy,
    required this.expectedCash,
  });

  final CashRegister register;
  final bool busy;
  final int expectedCash;

  @override
  Widget build(BuildContext context) {
    final open = register.hasOpenSession;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Fonctions',
          style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionButton(
              label: 'Open Register',
              icon: Icons.lock_open_rounded,
              enabled: !open && !busy,
              onTap: () => _open(context),
            ),
            _ActionButton(
              label: 'Close Register',
              icon: Icons.lock_rounded,
              enabled: open && !busy,
              danger: true,
              onTap: () => _close(context),
            ),
            _ActionButton(
              label: 'Cash In',
              icon: Icons.add_circle_outline,
              enabled: open && !busy,
              onTap: () => _amountAction(
                context,
                title: 'Cash In',
                onSubmit: (amount, note) {
                  context.read<CashRegisterBloc>().add(CashRegisterCashIn(
                        registerId: register.id,
                        amount: amount,
                        description: note,
                      ));
                },
              ),
            ),
            _ActionButton(
              label: 'Cash Out',
              icon: Icons.remove_circle_outline,
              enabled: open && !busy,
              onTap: () => _amountAction(
                context,
                title: 'Cash Out',
                onSubmit: (amount, note) {
                  context.read<CashRegisterBloc>().add(CashRegisterCashOut(
                        registerId: register.id,
                        amount: amount,
                        description: note,
                      ));
                },
              ),
            ),
            _ActionButton(
              label: 'Cash Adjustment',
              icon: Icons.tune,
              enabled: open && !busy,
              onTap: () => _adjust(context),
            ),
            _ActionButton(
              label: 'Cash Count',
              icon: Icons.calculate_outlined,
              enabled: open && !busy,
              onTap: () => _count(context),
            ),
            _ActionButton(
              label: 'Reconciliation',
              icon: Icons.balance_outlined,
              enabled: open && !busy,
              onTap: () {
                context
                    .read<CashRegisterBloc>()
                    .add(CashRegisterReconcileRequested(register.id));
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context) async {
    final balanceCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AmountDialog(
        title: 'Open Register',
        amountLabel: 'Fonds initial (${AppConfig.currencyCode})',
        amountController: balanceCtrl,
        notesController: notesCtrl,
        confirmLabel: 'Ouvrir',
      ),
    );
    if (ok != true || !context.mounted) return;
    context.read<CashRegisterBloc>().add(CashRegisterOpened(
          registerId: register.id,
          openingBalance: _parseMoney(balanceCtrl.text),
          notes: notesCtrl.text.trim(),
        ));
  }

  Future<void> _close(BuildContext context) async {
    final actualCtrl = TextEditingController(text: (expectedCash / 100).toStringAsFixed(2));
    final notesCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Register'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Expected: ${MoneyFormatter.format(expectedCash)}'),
            const SizedBox(height: 12),
            TextField(
              controller: actualCtrl,
              decoration: InputDecoration(
                labelText: 'Actual Cash (${AppConfig.currencyCode})',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Motif d’écart'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Fermer')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    context.read<CashRegisterBloc>().add(CashRegisterClosed(
          registerId: register.id,
          actualCash: _parseMoney(actualCtrl.text),
          notes: notesCtrl.text.trim(),
          varianceReason: reasonCtrl.text.trim(),
        ));
  }

  Future<void> _count(BuildContext context) async {
    final actualCtrl = TextEditingController(text: (expectedCash / 100).toStringAsFixed(2));
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AmountDialog(
        title: 'Cash Count',
        amountLabel: 'Actual Cash (${AppConfig.currencyCode})',
        amountController: actualCtrl,
        notesController: notesCtrl,
        confirmLabel: 'Comptabiliser',
        header: Text('Expected: ${MoneyFormatter.format(expectedCash)}'),
      ),
    );
    if (ok != true || !context.mounted) return;
    context.read<CashRegisterBloc>().add(CashRegisterCounted(
          registerId: register.id,
          actualCash: _parseMoney(actualCtrl.text),
          notes: notesCtrl.text.trim(),
        ));
  }

  Future<void> _adjust(BuildContext context) async {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var direction = 'in';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Cash Adjustment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'in', label: Text('+ In')),
                  ButtonSegment(value: 'out', label: Text('− Out')),
                ],
                selected: {direction},
                onSelectionChanged: (v) => setLocal(() => direction = v.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                decoration: InputDecoration(labelText: 'Montant (${AppConfig.currencyCode})'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
              ),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final amount = _parseMoney(amountCtrl.text);
    if (amount < 1) return;
    context.read<CashRegisterBloc>().add(CashRegisterAdjusted(
          registerId: register.id,
          amount: amount,
          direction: direction,
          description: notesCtrl.text.trim(),
        ));
  }

  Future<void> _amountAction(
    BuildContext context, {
    required String title,
    required void Function(int amount, String? note) onSubmit,
  }) async {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AmountDialog(
        title: title,
        amountLabel: 'Montant (${AppConfig.currencyCode})',
        amountController: amountCtrl,
        notesController: notesCtrl,
        confirmLabel: 'Enregistrer',
      ),
    );
    if (ok != true || !context.mounted) return;
    final amount = _parseMoney(amountCtrl.text);
    if (amount < 1) return;
    onSubmit(amount, notesCtrl.text.trim());
  }

  int _parseMoney(String input) {
    final cleaned = input.replaceAll(',', '.').trim();
    final value = double.tryParse(cleaned) ?? 0;
    return (value * 100).round();
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      height: 44,
      child: danger
          ? FilledButton.icon(
              onPressed: enabled ? onTap : null,
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              icon: Icon(icon, size: 18),
              label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            )
          : OutlinedButton.icon(
              onPressed: enabled ? onTap : null,
              icon: Icon(icon, size: 18),
              label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
    );
  }
}

class _AmountDialog extends StatelessWidget {
  const _AmountDialog({
    required this.title,
    required this.amountLabel,
    required this.amountController,
    required this.notesController,
    required this.confirmLabel,
    this.header,
  });

  final String title;
  final String amountLabel;
  final TextEditingController amountController;
  final TextEditingController notesController;
  final String confirmLabel;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null) ...[
            header!,
            const SizedBox(height: 12),
          ],
          TextField(
            controller: amountController,
            decoration: InputDecoration(labelText: amountLabel),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesController,
            decoration: const InputDecoration(labelText: 'Notes (optionnel)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmLabel)),
      ],
    );
  }
}
