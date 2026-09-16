import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/pos_models.dart';

class PaymentDialogResult {
  const PaymentDialogResult({
    required this.mode,
    required this.selected,
    required this.tendered,
    required this.mixed,
  });

  final String mode;
  final String selected;
  final int tendered;
  final List<PaymentMixDraft> mixed;
}

class PaymentMixDraft {
  const PaymentMixDraft({
    required this.method,
    required this.amount,
    required this.tendered,
  });

  final String method;
  final int amount;
  final int tendered;
}

Future<PaymentDialogResult?> showPosPaymentDialog({
  required BuildContext context,
  required int total,
  required String currencyCode,
  required List<PosPaymentMethod> methods,
  PosCustomer? customer,
  PosCustomerBalance? customerBalance,
  required String Function(int amount) money,
  required String Function(int amount) major,
  required int Function(String value) parseMajor,
  required IconData Function(String value) paymentIcon,
}) {
  return showDialog<PaymentDialogResult>(
    context: context,
    barrierColor: const Color(0x660F172A),
    builder: (context) => _PaymentDialog(
      total: total,
      currencyCode: currencyCode,
      methods: methods,
      customer: customer,
      customerBalance: customerBalance,
      money: money,
      major: major,
      parseMajor: parseMajor,
      paymentIcon: paymentIcon,
    ),
  );
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.total,
    required this.currencyCode,
    required this.methods,
    required this.customer,
    required this.customerBalance,
    required this.money,
    required this.major,
    required this.parseMajor,
    required this.paymentIcon,
  });

  final int total;
  final String currencyCode;
  final List<PosPaymentMethod> methods;
  final PosCustomer? customer;
  final PosCustomerBalance? customerBalance;
  final String Function(int amount) money;
  final String Function(int amount) major;
  final int Function(String value) parseMajor;
  final IconData Function(String value) paymentIcon;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late String _mode;
  late String _selected;
  late final TextEditingController _tenderedCtrl;
  late final List<_MixControllers> _mixed;
  String? _error;

  List<PosPaymentMethod> get _available =>
      widget.methods.where((method) => !method.requiresCustomer || widget.customer != null).toList();

  @override
  void initState() {
    super.initState();
    final available = _available;
    _mode = 'single';
    _selected = available.isEmpty ? 'cash' : available.first.value;
    _tenderedCtrl = TextEditingController(text: widget.major(widget.total));
    _mixed = [
      _MixControllers(
        method: available.isEmpty ? 'cash' : available.first.value,
        amount: widget.major(widget.total),
      ),
      _MixControllers(
        method: available.length > 1 ? available[1].value : (available.isEmpty ? 'card' : available.first.value),
        amount: '0',
      ),
    ];
  }

  @override
  void dispose() {
    _tenderedCtrl.dispose();
    for (final line in _mixed) {
      line.dispose();
    }
    super.dispose();
  }

  PosPaymentMethod? _metaOf(String value) {
    for (final method in widget.methods) {
      if (method.value == value) return method;
    }
    return null;
  }

  void _confirm() {
    if (_mode == 'single') {
      final meta = _metaOf(_selected);
      if (meta?.requiresCustomer == true && widget.customer == null) {
        setState(() => _error = 'Client requis pour ce mode');
        return;
      }
      if (meta?.supportsChange == true || _selected == 'cash') {
        if (widget.parseMajor(_tenderedCtrl.text) < widget.total) {
          setState(() => _error = 'Montant reçu insuffisant');
          return;
        }
      }
    } else {
      final paid = _mixed.fold<int>(0, (sum, line) => sum + widget.parseMajor(line.amount.text));
      final remaining = widget.total - paid;
      if (_mixed.length < 2) {
        setState(() => _error = 'Ajoutez au moins deux modes');
        return;
      }
      if (remaining != 0) {
        setState(() => _error = 'Le total des lignes doit égaler le montant dû');
        return;
      }
      for (final line in _mixed) {
        if (widget.parseMajor(line.amount.text) < 1) {
          setState(() => _error = 'Chaque ligne doit avoir un montant');
          return;
        }
        final meta = _metaOf(line.method);
        if (meta?.supportsChange == true &&
            widget.parseMajor(line.tendered.text.isEmpty ? line.amount.text : line.tendered.text) <
                widget.parseMajor(line.amount.text)) {
          setState(() => _error = 'Montant reçu insuffisant');
          return;
        }
      }
    }

    Navigator.pop(
      context,
      PaymentDialogResult(
        mode: _mode,
        selected: _selected,
        tendered: widget.parseMajor(_tenderedCtrl.text),
        mixed: _mixed
            .map(
              (line) => PaymentMixDraft(
                method: line.method,
                amount: widget.parseMajor(line.amount.text),
                tendered: widget.parseMajor(line.tendered.text.isEmpty ? line.amount.text : line.tendered.text),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final compact = size.width < 520;
    final available = _available;
    final paid = _mixed.fold<int>(0, (sum, line) => sum + widget.parseMajor(line.amount.text));
    final remaining = widget.total - paid;
    final selectedMeta = _metaOf(_selected);
    final supportsChange = selectedMeta?.supportsChange == true || _selected == 'cash';
    final tendered = widget.parseMajor(_tenderedCtrl.text);
    final change = supportsChange && tendered >= widget.total ? tendered - widget.total : 0;

    return Dialog(
      insetPadding: EdgeInsets.fromLTRB(compact ? 14 : 28, 24, compact ? 14 : 28, 24 + inset),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? size.width : 480, maxHeight: size.height * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(customer: widget.customer, onClose: () => Navigator.pop(context)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TotalCard(
                      totalLabel: widget.money(widget.total),
                      customerBalance: widget.customerBalance == null ? null : widget.money(widget.customerBalance!.balance),
                    ),
                    const SizedBox(height: 12),
                    _ModeTabs(
                      mode: _mode,
                      onChanged: (value) => setState(() {
                        _mode = value;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: 14),
                    if (_mode == 'single') ...[
                      if (available.isEmpty)
                        Text('Aucun mode de paiement configuré', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textMuted))
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 360 ? 2 : 1;
                            final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final method in available)
                                  SizedBox(
                                    width: width,
                                    child: _MethodTile(
                                      label: method.displayLabel,
                                      icon: widget.paymentIcon(method.value),
                                      selected: _selected == method.value,
                                      hint: method.requiresCustomer ? 'Client requis' : null,
                                      onTap: () => setState(() {
                                        _selected = method.value;
                                        _error = null;
                                      }),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      if (supportsChange) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _tenderedCtrl,
                          onChanged: (_) => setState(() {}),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Montant reçu',
                            hintText: widget.major(widget.total),
                            prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                            isDense: true,
                          ),
                        ),
                        if (change > 0) ...[
                          const SizedBox(height: 8),
                          _ChangeBanner(value: widget.money(change)),
                        ],
                      ],
                    ] else ...[
                      Row(
                        children: [
                          Expanded(child: _MixStat(label: 'Payé', value: widget.money(paid), ok: remaining == 0)),
                          const SizedBox(width: 8),
                          Expanded(child: _MixStat(label: 'Reste', value: widget.money(remaining), ok: remaining == 0)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (var index = 0; index < _mixed.length; index++)
                        _MixedLineCard(
                          key: ValueKey('mix-$index-${_mixed[index].method}'),
                          line: _mixed[index],
                          available: available,
                          supportsChange: _metaOf(_mixed[index].method)?.supportsChange == true,
                          canRemove: _mixed.length > 2,
                          onFillRemaining: () => setState(() {
                            final others = _mixed.fold<int>(0, (sum, row) {
                              if (identical(row, _mixed[index])) return sum;
                              return sum + widget.parseMajor(row.amount.text);
                            });
                            _mixed[index].amount.text = widget.major((widget.total - others).clamp(0, widget.total));
                          }),
                          onRemove: () => setState(() => _mixed.removeAt(index)),
                          onChanged: () => setState(() {}),
                        ),
                      OutlinedButton.icon(
                        onPressed: available.isEmpty
                            ? null
                            : () => setState(() {
                                  final used = _mixed.map((line) => line.method).toSet();
                                  final next = available.where((method) => !used.contains(method.value));
                                  _mixed.add(_MixControllers(
                                    method: next.isEmpty ? available.first.value : next.first.value,
                                    amount: '0',
                                  ));
                                }),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Ajouter un mode'),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      _ErrorBanner(message: _error!),
                    ],
                  ],
                ),
              ),
            ),
            _Footer(onCancel: () => Navigator.pop(context), onConfirm: _confirm),
          ],
        ),
      ),
    );
  }
}

class _MixControllers {
  _MixControllers({required this.method, required String amount})
      : amount = TextEditingController(text: amount),
        tendered = TextEditingController(text: amount);

  String method;
  final TextEditingController amount;
  final TextEditingController tendered;

  void dispose() {
    amount.dispose();
    tendered.dispose();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.customer, required this.onClose});

  final PosCustomer? customer;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.brand50,
        border: Border(top: BorderSide(color: AppColors.brand600, width: 3)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(Icons.payments_outlined, size: 18, color: AppColors.brand700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Paiement', style: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (customer != null)
                  Text(
                    customer!.displayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close, size: 18)),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.totalLabel, this.customerBalance});

  final String totalLabel;
  final String? customerBalance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text('Montant dû', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(totalLabel, style: GoogleFonts.ibmPlexMono(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.brand700)),
          if (customerBalance != null) ...[
            const SizedBox(height: 4),
            Text('Solde client $customerBalance', style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.mode, required this.onChanged});

  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final entry in const [('single', 'Simple'), ('mixed', 'Mixte')])
            Expanded(
              child: Material(
                color: mode == entry.$1 ? AppColors.brand900 : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => onChanged(entry.$1),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Text(
                      entry.$2,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: mode == entry.$1 ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.hint,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brand50 : AppColors.fieldFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.brand600 : AppColors.border, width: selected ? 1.4 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: selected ? AppColors.brand700 : AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    if (hint != null)
                      Text(hint!, style: GoogleFonts.ibmPlexSans(fontSize: 10, color: AppColors.warning)),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, size: 16, color: AppColors.brand600),
            ],
          ),
        ),
      ),
    );
  }
}

class _MixStat extends StatelessWidget {
  const _MixStat({required this.label, required this.value, required this.ok});

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: ok ? AppColors.successBg : AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.ibmPlexMono(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _MixedLineCard extends StatelessWidget {
  const _MixedLineCard({
    super.key,
    required this.line,
    required this.available,
    required this.supportsChange,
    required this.canRemove,
    required this.onFillRemaining,
    required this.onRemove,
    required this.onChanged,
  });

  final _MixControllers line;
  final List<PosPaymentMethod> available;
  final bool supportsChange;
  final bool canRemove;
  final VoidCallback onFillRemaining;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 5,
                child: DropdownButtonFormField<String>(
                  initialValue: available.any((method) => method.value == line.method) ? line.method : available.firstOrNull?.value,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Mode', isDense: true),
                  items: available
                      .map((method) => DropdownMenuItem(value: method.value, child: Text(method.displayLabel, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    line.method = value;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: line.amount,
                  onChanged: (_) => onChanged(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Montant', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(onPressed: onFillRemaining, child: const Text('= Reste')),
              const Spacer(),
              IconButton(
                tooltip: 'Retirer',
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          if (supportsChange)
            TextField(
              controller: line.tendered,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Montant reçu', isDense: true),
            ),
        ],
      ),
    );
  }
}

class _ChangeBanner extends StatelessWidget {
  const _ChangeBanner({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.currency_exchange, size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Text('Monnaie', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value, style: GoogleFonts.ibmPlexMono(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onCancel, required this.onConfirm});

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(child: OutlinedButton(onPressed: onCancel, child: const Text('Annuler'))),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Encaisser'),
            ),
          ),
        ],
      ),
    );
  }
}
