import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../domain/pos_models.dart';
import 'pos_ui.dart';

bool _useMobilePaymentSheet(BuildContext context) {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    return true;
  }
  return !PosUi.isWindowsDesk(context);
}

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
  int? subtotal,
  required String currencyCode,
  required List<PosPaymentMethod> methods,
  PosCustomer? customer,
  PosCustomerBalance? customerBalance,
  required String Function(int amount) money,
  required String Function(int amount) major,
  required int Function(String value) parseMajor,
  required IconData Function(String value) paymentIcon,
}) {
  final mobileSheet = _useMobilePaymentSheet(context);
  return showDialog<PaymentDialogResult>(
    context: context,
    barrierColor: mobileSheet ? const Color(0xCC070B14) : const Color(0x660F172A),
    builder: (context) => _PaymentDialog(
      total: total,
      subtotal: subtotal ?? total,
      currencyCode: currencyCode,
      methods: methods,
      customer: customer,
      customerBalance: customerBalance,
      money: money,
      major: major,
      parseMajor: parseMajor,
      paymentIcon: paymentIcon,
      mobileSheet: mobileSheet,
    ),
  );
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.total,
    required this.subtotal,
    required this.currencyCode,
    required this.methods,
    required this.customer,
    required this.customerBalance,
    required this.money,
    required this.major,
    required this.parseMajor,
    required this.paymentIcon,
    required this.mobileSheet,
  });

  final int total;
  final int subtotal;
  final String currencyCode;
  final List<PosPaymentMethod> methods;
  final PosCustomer? customer;
  final PosCustomerBalance? customerBalance;
  final String Function(int amount) money;
  final String Function(int amount) major;
  final int Function(String value) parseMajor;
  final IconData Function(String value) paymentIcon;
  final bool mobileSheet;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late String _mode;
  late String _selected;
  late final TextEditingController _tenderedCtrl;
  late final TextEditingController _draftAmountCtrl;
  late final List<_MixControllers> _mixed;
  final List<_MixControllers> _committed = [];
  String? _draftMethod;
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
    _draftAmountCtrl = TextEditingController(text: widget.major(widget.total));
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
    _draftAmountCtrl.dispose();
    for (final line in _mixed) {
      line.dispose();
    }
    for (final line in _committed) {
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

  bool _isAccountMethod(PosPaymentMethod method) {
    const accounts = {'credit', 'wallet', 'house', 'house_offer', 'on_account'};
    return accounts.contains(method.value) || method.requiresCustomer;
  }

  List<PosPaymentMethod> get _accountMethods =>
      widget.methods.where(_isAccountMethod).toList();

  List<PosPaymentMethod> get _tenderMethods =>
      _available.where((method) => !_isAccountMethod(method)).toList();

  int get _committedPaid =>
      _committed.fold<int>(0, (sum, line) => sum + widget.parseMajor(line.amount.text));

  void _addCommittedLine(List<PosPaymentMethod> methods) {
    final method = _draftMethod;
    final amount = widget.parseMajor(_draftAmountCtrl.text);
    final remaining = widget.total - _committedPaid;
    if (method == null || methods.every((item) => item.value != method)) {
      setState(() => _error = 'Choose a payment method');
      return;
    }
    if (amount < 1) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    if (amount > remaining) {
      setState(() => _error = 'Amount exceeds the remaining balance');
      return;
    }
    setState(() {
      _committed.add(_MixControllers(method: method, amount: widget.major(amount)));
      _draftMethod = null;
      _draftAmountCtrl.text = widget.major(remaining - amount);
      _error = null;
    });
  }

  void _confirm() {
    if (_mode == 'credit') {
      if (widget.customer == null) {
        setState(() => _error = 'Select a customer on this order to use Credit or House offer.');
        return;
      }
      final account = _accountMethods.where((method) => method.value == _selected).firstOrNull ??
          _accountMethods.firstOrNull;
      Navigator.pop(
        context,
        PaymentDialogResult(
          mode: 'single',
          selected: account?.value ?? 'credit',
          tendered: widget.total,
          mixed: const [],
        ),
      );
      return;
    }
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
    } else if (_mode == 'house') {
      if (widget.customer == null) {
        setState(() => _error = 'Select a customer on this order to use Credit or House offer.');
        return;
      }
      Navigator.pop(
        context,
        PaymentDialogResult(
          mode: 'single',
          selected: 'house_offer',
          tendered: widget.total,
          mixed: const [],
        ),
      );
      return;
    } else {
      final lines = widget.mobileSheet ? _committed : _mixed;
      final paid = lines.fold<int>(0, (sum, line) => sum + widget.parseMajor(line.amount.text));
      final remaining = widget.total - paid;
      if (lines.length < 2) {
        setState(() => _error = 'Ajoutez au moins deux modes');
        return;
      }
      if (remaining != 0) {
        setState(() => _error = 'Le total des lignes doit égaler le montant dû');
        return;
      }
      for (final line in lines) {
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
        mixed: (widget.mobileSheet && _mode == 'mixed' ? _committed : _mixed)
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

  Widget _buildMobileSheet({
    required Size size,
    required double inset,
    required bool supportsChange,
    required int change,
  }) {
    final tenders = _tenderMethods.isEmpty ? _available : _tenderMethods;
    final accounts = _accountMethods;
    const labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE8EEF6));

    return Dialog(
      insetPadding: EdgeInsets.fromLTRB(14, 20, 14, 20 + inset),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 460, maxHeight: size.height * 0.92),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Material(
            color: const Color(0xFF1A2233),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProcessHeader(onClose: () => Navigator.pop(context)),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121A28),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF2C3A50)),
                          ),
                          child: Column(
                            children: [
                              _SheetAmountRow(label: 'Subtotal', value: widget.money(widget.subtotal)),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(height: 1, color: Color(0xFF2C3A50)),
                              ),
                              _SheetAmountRow(label: 'Amount Due', value: widget.money(widget.total), emphasize: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text('Payment Type', style: GoogleFonts.ibmPlexSans(textStyle: labelStyle)),
                        const SizedBox(height: 8),
                        _ProcessModeTabs(
                          mode: _mode,
                          onChanged: (value) => setState(() {
                            _mode = value;
                            _error = null;
                            if (value == 'credit') {
                              final account = accounts.where((method) => method.value == _selected).firstOrNull ?? accounts.firstOrNull;
                              if (account != null) _selected = account.value;
                            } else if (value == 'single') {
                              final tender = tenders.where((method) => method.value == _selected).firstOrNull ?? tenders.firstOrNull;
                              if (tender != null) _selected = tender.value;
                            }
                          }),
                        ),
                        if (widget.customer == null && (_mode == 'credit' || _mode == 'house')) ...[
                          const SizedBox(height: 12),
                          const _CustomerNotice(),
                        ],
                        if (_mode == 'single') ...[
                          const SizedBox(height: 18),
                          Text('Payment Method', style: GoogleFonts.ibmPlexSans(textStyle: labelStyle)),
                          const SizedBox(height: 8),
                          if (tenders.isEmpty)
                            Text('No payment method', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: const Color(0xFF9AABBE)))
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final method in tenders)
                                  _MethodPill(
                                    label: method.label,
                                    icon: widget.paymentIcon(method.value),
                                    selected: _selected == method.value,
                                    onTap: () => setState(() {
                                      _selected = method.value;
                                      _error = null;
                                    }),
                                  ),
                              ],
                            ),
                          const SizedBox(height: 18),
                          Text('Amount Received', style: GoogleFonts.ibmPlexSans(textStyle: labelStyle)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _tenderedCtrl,
                              onChanged: (_) => setState(() {}),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.ibmPlexSans(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF101828),
                                hintText: widget.major(widget.total),
                                hintStyle: GoogleFonts.ibmPlexSans(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF6E7C90)),
                                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFF2C3A50)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFF8B6CFF)),
                                ),
                              ),
                            ),
                            if (change > 0) ...[
                              const SizedBox(height: 8),
                              _ChangeBanner(value: widget.money(change)),
                            ],
                        ] else if (_mode == 'credit') ...[
                          if (widget.customer != null && accounts.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Text('Payment Method', style: GoogleFonts.ibmPlexSans(textStyle: labelStyle)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final method in accounts)
                                  _MethodPill(
                                    label: method.label,
                                    icon: widget.paymentIcon(method.value),
                                    selected: _selected == method.value,
                                    onTap: () => setState(() {
                                      _selected = method.value;
                                      _error = null;
                                    }),
                                  ),
                              ],
                            ),
                          ],
                        ] else if (_mode == 'house') ...[
                          if (widget.customer != null) ...[
                            const SizedBox(height: 18),
                            Text(
                              'The full amount is recorded as a house offer.',
                              style: GoogleFonts.ibmPlexSans(fontSize: 13, height: 1.35, color: const Color(0xFF9AABBE)),
                            ),
                          ],
                        ] else ...[
                          const SizedBox(height: 14),
                          _RemainingBanner(value: widget.money(widget.total - _committedPaid)),
                          if (_committed.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            for (var index = 0; index < _committed.length; index++)
                              _CommittedLine(
                                label: _metaOf(_committed[index].method)?.label ?? _committed[index].method,
                                amount: widget.money(widget.parseMajor(_committed[index].amount.text)),
                                onRemove: () => setState(() {
                                  _committed.removeAt(index).dispose();
                                  _draftAmountCtrl.text = widget.major(widget.total - _committedPaid);
                                }),
                              ),
                          ],
                          const SizedBox(height: 16),
                          Text('Payment Method', style: GoogleFonts.ibmPlexSans(textStyle: labelStyle)),
                          const SizedBox(height: 8),
                          _MixMethodField(
                            value: _draftMethod,
                            methods: tenders,
                            onChanged: (value) => setState(() {
                              _draftMethod = value;
                              _error = null;
                            }),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _draftAmountCtrl,
                                  onChanged: (_) => setState(() {}),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.ibmPlexSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFF121A28),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Color(0xFF3A4A62)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Color(0xFF8B6CFF)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton(
                                onPressed: tenders.isEmpty ? null : () => _addCommittedLine(tenders),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C5CFF),
                                  disabledBackgroundColor: const Color(0xFF7C5CFF).withValues(alpha: 0.35),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(72, 52),
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text('Add', style: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w800)),
                              ),
                            ],
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
                _ProcessFooter(
                  onCancel: () => Navigator.pop(context),
                  onConfirm: _confirm,
                  enabled: _mode != 'mixed' || ((widget.total - _committedPaid) == 0 && _committed.length >= 2),
                ),
              ],
            ),
          ),
        ),
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

    if (widget.mobileSheet) {
      return _buildMobileSheet(
        size: size,
        inset: inset,
        supportsChange: supportsChange,
        change: change,
      );
    }

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
            child: Icon(Icons.payments_outlined, size: 18, color: AppColors.brandInk),
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
          Text(totalLabel, style: GoogleFonts.ibmPlexMono(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.brandInk)),
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
              Icon(icon, size: 18, color: selected ? AppColors.brandInk : AppColors.textMuted),
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
              if (selected) Icon(Icons.check_circle, size: 16, color: AppColors.brandInk),
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
    return AppFadeIn(
      duration: AppMotion.micro,
      child: Container(
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
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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

class _ProcessHeader extends StatelessWidget {
  const _ProcessHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B6CFF), Color(0xFF6D4AFF)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF6D4AFF), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Process Payment',
                  style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  'Choose one payment method or split the total across multiple methods.',
                  style: GoogleFonts.ibmPlexSans(fontSize: 12, height: 1.35, color: Color(0xFFF3EEFF)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _SheetAmountRow extends StatelessWidget {
  const _SheetAmountRow({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: emphasize ? 16 : 14,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
            color: const Color(0xFFE8EEF6),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.ibmPlexSans(
            fontSize: emphasize ? 22 : 16,
            fontWeight: FontWeight.w800,
            color: emphasize ? const Color(0xFFC4B5FD) : const Color(0xFFF4F7FB),
          ),
        ),
      ],
    );
  }
}

class _ProcessModeTabs extends StatelessWidget {
  const _ProcessModeTabs({required this.mode, required this.onChanged});

  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF121A28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C3A50)),
      ),
      child: Row(
        children: [
          for (final entry in const [('single', 'Single'), ('mixed', 'Mixed'), ('credit', 'Credit'), ('house', 'H. Offer')])
            Expanded(
              child: Material(
                color: mode == entry.$1 ? const Color(0xFF3A455C) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => onChanged(entry.$1),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                    child: Text(
                      entry.$2,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: mode == entry.$1 ? Colors.white : const Color(0xFF9AABBE),
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

class _CustomerNotice extends StatelessWidget {
  const _CustomerNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2E14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC4A15A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 18, color: Color(0xFFE7C27A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Select a customer on this order to use Credit or House offer.',
              style: GoogleFonts.ibmPlexSans(fontSize: 12, height: 1.35, color: const Color(0xFFF3E2B8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemainingBanner extends StatelessWidget {
  const _RemainingBanner({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            'Remaining',
            style: GoogleFonts.ibmPlexSans(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFFE07A12)),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFFE07A12)),
          ),
        ],
      ),
    );
  }
}

class _MixMethodField extends StatelessWidget {
  const _MixMethodField({
    required this.value,
    required this.methods,
    required this.onChanged,
  });

  final String? value;
  final List<PosPaymentMethod> methods;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = methods.any((method) => method.value == value) ? value : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121A28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3A4A62)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          hint: const SizedBox.shrink(),
          dropdownColor: const Color(0xFF1A2233),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF9AABBE)),
          style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
          items: [
            for (final method in methods)
              DropdownMenuItem(value: method.value, child: Text(method.label)),
          ],
          onChanged: methods.isEmpty ? null : onChanged,
        ),
      ),
    );
  }
}

class _CommittedLine extends StatelessWidget {
  const _CommittedLine({
    required this.label,
    required this.amount,
    required this.onRemove,
  });

  final String label;
  final String amount;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121A28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C3A50)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          Text(amount, style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFC4B5FD))),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF9AABBE)),
          ),
        ],
      ),
    );
  }
}

class _MethodPill extends StatelessWidget {
  const _MethodPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF2A2150) : const Color(0xFF121A28),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? const Color(0xFF8B6CFF) : const Color(0xFF2C3A50)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? const Color(0xFFC4B5FD) : const Color(0xFF9AABBE)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFFE8EEF6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcessFooter extends StatelessWidget {
  const _ProcessFooter({required this.onCancel, required this.onConfirm, this.enabled = true});

  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1A2233),
        border: Border(top: BorderSide(color: Color(0xFF2C3A50))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE8EEF6),
                side: const BorderSide(color: Color(0xFF3A4A62)),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: enabled ? onConfirm : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2A3348),
                disabledBackgroundColor: const Color(0xFF2A3348),
                foregroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF8B97A8),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
