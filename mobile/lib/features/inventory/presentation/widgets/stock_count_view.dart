import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/i18n/tr.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../pos/presentation/widgets/pos_ui.dart';
import '../../domain/stock_count.dart';
import '../bloc/stock_count_bloc.dart';

/// Inventaire complet, comptage cyclique et vérification (§29).
class StockCountView extends StatelessWidget {
  const StockCountView({super.key, required this.canPost});

  final bool canPost;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StockCountBloc, StockCountState>(
      listenWhen: (a, b) => a.message != b.message || a.errorMessage != b.errorMessage,
      listener: (context, state) {
        final text = state.errorMessage ?? state.message;
        if (text == null) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(text))));
      },
      builder: (context, state) {
        if (state.isLoading) return const Center(child: CircularProgressIndicator());
        final active = state.active;
        if (active != null) return _CountSheet(sheet: active, busy: state.submitting, canPost: canPost);
        return _CountList(state: state, canPost: canPost);
      },
    );
  }
}

class _CountList extends StatelessWidget {
  const _CountList({required this.state, required this.canPost});

  final StockCountState state;
  final bool canPost;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<StockCountBloc>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        if (canPost)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in StockCountKind.values)
                AppButton.secondary(
                  label: tr(kind.label),
                  icon: switch (kind) {
                    StockCountKind.full => Icons.inventory_2_outlined,
                    StockCountKind.cycle => Icons.autorenew,
                    StockCountKind.verification => Icons.fact_check_outlined,
                  },
                  loading: state.submitting,
                  onPressed: state.submitting ? null : () => bloc.add(StockCountCreated(kind)),
                ),
            ],
          )
        else
          Text(
            tr('Les inventaires demandent la permission inventory.adjust.'),
            style: PosUi.caption(),
          ),
        const SizedBox(height: 16),
        if (state.counts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(tr('Aucun inventaire sur ce terminal.'), style: PosUi.body(color: AppColors.textSecondary)),
            ),
          ),
        for (final sheet in state.counts)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(sheet.isPosted ? Icons.check_circle : Icons.pending_actions,
                  color: sheet.isPosted ? AppColors.success : AppColors.accent),
              title: Text(tr(sheet.kind.label)),
              subtitle: Text(trf('{0} · {1}/{2} comptés · {3} écart(s)', [
                _date(sheet.createdAt),
                sheet.countedLines,
                sheet.lines.length,
                sheet.varianceLines,
              ])),
              trailing: Text(tr(_statusLabel(sheet.status)), style: PosUi.caption()),
              onTap: () => bloc.add(StockCountOpened(sheet.id)),
            ),
          ),
      ],
    );
  }
}

class _CountSheet extends StatefulWidget {
  const _CountSheet({required this.sheet, required this.busy, required this.canPost});

  final StockCountSheet sheet;
  final bool busy;
  final bool canPost;

  @override
  State<_CountSheet> createState() => _CountSheetState();
}

class _CountSheetState extends State<_CountSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<StockCountBloc>();
    final sheet = widget.sheet;
    final q = _query.trim().toLowerCase();
    final lines = q.isEmpty ? sheet.lines : sheet.lines.where((l) => l.name.toLowerCase().contains(q)).toList();
    final editable = !sheet.isPosted && widget.canPost;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 14, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: tr('Retour'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => bloc.add(const StockCountClosed()),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(sheet.kind.label), style: PosUi.cardTitle()),
                    Text(
                      trf('{0}/{1} comptés · {2} écart(s) · {3}', [
                        sheet.countedLines,
                        sheet.lines.length,
                        sheet.varianceLines,
                        tr(_statusLabel(sheet.status)),
                      ]),
                      style: PosUi.caption(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: tr('Rechercher un produit…'),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            itemCount: lines.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) => _CountLineTile(
              key: ValueKey('${sheet.id}:${lines[index].productId}'),
              line: lines[index],
              editable: editable,
              onCounted: (value) => bloc.add(StockCountLineCounted(lines[index].productId, value)),
            ),
          ),
        ),
        if (editable)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Row(
                children: [
                  if (sheet.kind == StockCountKind.verification) ...[
                    Expanded(
                      child: AppButton.secondary(
                        label: tr('Vérifier'),
                        icon: Icons.fact_check_outlined,
                        expanded: true,
                        loading: widget.busy,
                        onPressed: widget.busy ? null : () => bloc.add(const StockCountPosted(applyAdjustments: false)),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: AppButton.primary(
                      label: tr('Valider les écarts'),
                      icon: Icons.check,
                      expanded: true,
                      loading: widget.busy,
                      onPressed: widget.busy
                          ? null
                          : () async {
                              final ok = await AppDialogs.confirm(
                                context: context,
                                title: tr('Valider l’inventaire ?'),
                                message: trf(
                                  '{0} écart(s) seront écrits dans le stock. Cette action ne peut pas être annulée.',
                                  [sheet.varianceLines],
                                ),
                                confirmLabel: tr('Valider'),
                              );
                              if (ok) bloc.add(const StockCountPosted());
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CountLineTile extends StatefulWidget {
  const _CountLineTile({super.key, required this.line, required this.editable, required this.onCounted});

  final StockCountLine line;
  final bool editable;
  final ValueChanged<int?> onCounted;

  @override
  State<_CountLineTile> createState() => _CountLineTileState();
}

class _CountLineTileState extends State<_CountLineTile> {
  late final _controller = TextEditingController(text: widget.line.countedQty?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final text = _controller.text.trim();
    final value = text.isEmpty ? null : int.tryParse(text);
    if (value != widget.line.countedQty) widget.onCounted(value);
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.line.variance;
    final gapColor = gap == null || gap == 0 ? AppColors.textSecondary : (gap > 0 ? AppColors.success : AppColors.danger);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.line.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: PosUi.body(weight: FontWeight.w600)),
                Text(
                  gap == null
                      ? trf('Attendu {0}', [widget.line.expectedQty])
                      : trf('Attendu {0} · écart {1}', [widget.line.expectedQty, gap > 0 ? '+$gap' : '$gap']),
                  style: PosUi.caption(color: gapColor),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 96,
            child: Focus(
              onFocusChange: (focused) {
                if (!focused) _commit();
              },
              child: TextField(
                controller: _controller,
                enabled: widget.editable,
                textAlign: TextAlign.end,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(hintText: tr('Compté'), isDense: true),
                onSubmitted: (_) => _commit(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(String status) => switch (status) {
      StockCountStatusWire.posted => 'Validé',
      StockCountStatusWire.variance => 'Écarts relevés',
      StockCountStatusWire.verified => 'Conforme',
      _ => 'En cours',
    };

String _date(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)} ${two(value.hour)}:${two(value.minute)}';
}
