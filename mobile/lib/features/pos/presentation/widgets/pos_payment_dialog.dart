import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../domain/pos_models.dart';
import 'pos_ui.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

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
    useRootNavigator: true,
    barrierDismissible: true,
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

  InputDecoration _sheetFieldDecoration({String? hint, bool large = false}) {
    return InputDecoration(
      filled: true,
      fillColor: PosUi.deskField,
      hintText: hint,
      hintStyle: AppTypography.text(
        fontSize: large ? 28 : 16,
        fontWeight: FontWeight.w700,
        color: PosUi.deskMuted,
      ),
      contentPadding: EdgeInsets.symmetric(vertical: large ? 14 : 12, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: PosUi.deskLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: PosUi.deskLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PosUi.deskAccent, width: 1.4),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      tr(text),
      style: AppTypography.text(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: PosUi.deskMuted,
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

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: Material(
          color: PosUi.deskPanel,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: size.width,
              maxHeight: size.height * 0.92,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: PosUi.deskLine,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                _ProcessHeader(
                  onClose: () => Navigator.pop(context),
                  customer: widget.customer,
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TotalCard(
                          subtotalLabel: widget.money(widget.subtotal),
                          totalLabel: widget.money(widget.total),
                          customerBalance: widget.customerBalance == null
                              ? null
                              : widget.money(widget.customerBalance!.balance),
                        ),
                        const SizedBox(height: 16),
                        _sectionLabel('Payment Type'),
                        const SizedBox(height: 8),
                        _ProcessModeTabs(
                          mode: _mode,
                          creditEnabled: widget.customer != null,
                          onChanged: (value) => setState(() {
                            if ((value == 'credit' || value == 'house') &&
                                widget.customer == null) {
                              _error =
                                  'Select a customer on this order to use Credit or House offer.';
                              return;
                            }
                            _mode = value;
                            _error = null;
                            if (value == 'credit') {
                              final account = accounts
                                      .where((method) => method.value == _selected)
                                      .firstOrNull ??
                                  accounts.firstOrNull;
                              if (account != null) _selected = account.value;
                            } else if (value == 'single') {
                              final tender = tenders
                                      .where((method) => method.value == _selected)
                                      .firstOrNull ??
                                  tenders.firstOrNull;
                              if (tender != null) _selected = tender.value;
                            }
                          }),
                        ),
                        if (widget.customer == null && (_mode == 'credit' || _mode == 'house')) ...[
                          const SizedBox(height: 12),
                          const _CustomerNotice(),
                        ],
                        if (_mode == 'single') ...[
                          const SizedBox(height: 16),
                          _sectionLabel('Payment Method'),
                          const SizedBox(height: 8),
                          if (tenders.isEmpty)
                            Text(
                              tr('No payment method'),
                              style: AppTypography.text(fontSize: 12, color: PosUi.deskMuted),
                            )
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
                          const SizedBox(height: 16),
                          _sectionLabel('Amount Received'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _tenderedCtrl,
                            onChanged: (_) => setState(() {}),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            cursorColor: PosUi.deskAccent,
                            style: AppTypography.text(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: PosUi.deskText,
                            ),
                            decoration: _sheetFieldDecoration(
                              hint: widget.major(widget.total),
                              large: true,
                            ),
                          ),
                          if (change > 0) ...[
                            const SizedBox(height: 8),
                            _ChangeBanner(value: widget.money(change)),
                          ],
                        ] else if (_mode == 'credit') ...[
                          if (widget.customer != null && accounts.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _sectionLabel('Payment Method'),
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
                            const SizedBox(height: 16),
                            Text(
                              tr('The full amount is recorded as a house offer.'),
                              style: AppTypography.text(
                                fontSize: 13,
                                height: 1.35,
                                color: PosUi.deskMuted,
                              ),
                            ),
                          ],
                        ] else ...[
                          const SizedBox(height: 14),
                          _RemainingBanner(value: widget.money(widget.total - _committedPaid)),
                          if (_committed.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            for (var index = 0; index < _committed.length; index++)
                              _CommittedLine(
                                label: _metaOf(_committed[index].method)?.label ??
                                    _committed[index].method,
                                amount: widget.money(
                                  widget.parseMajor(_committed[index].amount.text),
                                ),
                                onRemove: () => setState(() {
                                  _committed.removeAt(index).dispose();
                                  _draftAmountCtrl.text =
                                      widget.major(widget.total - _committedPaid);
                                }),
                              ),
                          ],
                          const SizedBox(height: 16),
                          _sectionLabel('Payment Method'),
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
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  cursorColor: PosUi.deskAccent,
                                  style: AppTypography.text(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: PosUi.deskText,
                                  ),
                                  decoration: _sheetFieldDecoration(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton(
                                onPressed:
                                    tenders.isEmpty ? null : () => _addCommittedLine(tenders),
                                style: FilledButton.styleFrom(
                                  backgroundColor: PosUi.deskAccent,
                                  disabledBackgroundColor:
                                      PosUi.deskAccent.withValues(alpha: 0.35),
                                  foregroundColor: PosUi.deskInk,
                                  minimumSize: const Size(72, 52),
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  tr('Add'),
                                  style: AppTypography.text(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
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
                  enabled: ((_mode != 'credit' && _mode != 'house') ||
                          widget.customer != null) &&
                      (_mode != 'mixed' ||
                          ((widget.total - _committedPaid) == 0 && _committed.length >= 2)),
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
      backgroundColor: Colors.transparent,
      child: Material(
        color: PosUi.deskPanel,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compact ? size.width : 480,
            maxHeight: size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProcessHeader(
                onClose: () => Navigator.pop(context),
                customer: widget.customer,
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TotalCard(
                        subtotalLabel: widget.money(widget.subtotal),
                        totalLabel: widget.money(widget.total),
                        customerBalance: widget.customerBalance == null
                            ? null
                            : widget.money(widget.customerBalance!.balance),
                      ),
                      const SizedBox(height: 14),
                      _sectionLabel('Payment Type'),
                      const SizedBox(height: 8),
                      _ModeTabs(
                        mode: _mode,
                        creditEnabled: widget.customer != null,
                        onChanged: (value) => setState(() {
                          if (value == 'credit' && widget.customer == null) {
                            _error = 'Select a customer on this order to use Credit or House offer.';
                            return;
                          }
                          _mode = value;
                          _error = null;
                          if (value == 'credit') {
                            final account = _accountMethods
                                    .where((method) => method.value == _selected)
                                    .firstOrNull ??
                                _accountMethods.firstOrNull;
                            _selected = account?.value ?? 'credit';
                          } else if (value == 'single') {
                            final tender = _tenderMethods
                                    .where((method) => method.value == _selected)
                                    .firstOrNull ??
                                _tenderMethods.firstOrNull;
                            if (tender != null) _selected = tender.value;
                          }
                        }),
                      ),
                      if (widget.customer == null && _mode == 'credit') ...[
                        const SizedBox(height: 12),
                        const _CustomerNotice(),
                      ],
                      const SizedBox(height: 14),
                      if (_mode == 'single') ...[
                        _sectionLabel('Payment Method'),
                        const SizedBox(height: 8),
                        if (_tenderMethods.isEmpty)
                          Text(
                            tr('Aucun mode de paiement configuré'),
                            style: AppTypography.text(fontSize: 12, color: PosUi.deskMuted),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 360 ? 2 : 1;
                              final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final method in _tenderMethods)
                                    SizedBox(
                                      width: width,
                                      child: _MethodTile(
                                        label: method.displayLabel,
                                        icon: widget.paymentIcon(method.value),
                                        selected: _selected == method.value,
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
                          const SizedBox(height: 14),
                          _sectionLabel('Amount Received'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _tenderedCtrl,
                            onChanged: (_) => setState(() {}),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            cursorColor: PosUi.deskAccent,
                            style: AppTypography.text(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: PosUi.deskText,
                            ),
                            decoration: _sheetFieldDecoration(hint: widget.major(widget.total), large: true),
                          ),
                          if (change > 0) ...[
                            const SizedBox(height: 8),
                            _ChangeBanner(value: widget.money(change)),
                          ],
                        ],
                      ] else if (_mode == 'credit') ...[
                        if (widget.customer != null) ...[
                          Text(
                            tr('Le montant total est enregistré à crédit sur le compte client.'),
                            style: AppTypography.text(
                              fontSize: 13,
                              height: 1.35,
                              color: PosUi.deskMuted,
                            ),
                          ),
                          if (_accountMethods.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _sectionLabel('Payment Method'),
                            const SizedBox(height: 8),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 360 ? 2 : 1;
                                final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final method in _accountMethods)
                                      SizedBox(
                                        width: width,
                                        child: _MethodTile(
                                          label: method.displayLabel,
                                          icon: widget.paymentIcon(method.value),
                                          selected: _selected == method.value,
                                          hint: tr('Client requis'),
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
                          ],
                        ],
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: _MixStat(
                                label: tr('Payé'),
                                value: widget.money(paid),
                                ok: remaining == 0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MixStat(
                                label: tr('Reste'),
                                value: widget.money(remaining),
                                ok: remaining == 0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (var index = 0; index < _mixed.length; index++)
                          _MixedLineCard(
                            key: ValueKey('mix-$index-${_mixed[index].method}'),
                            line: _mixed[index],
                            available: _tenderMethods,
                            supportsChange:
                                _metaOf(_mixed[index].method)?.supportsChange == true,
                            canRemove: _mixed.length > 2,
                            onFillRemaining: () => setState(() {
                              final others = _mixed.fold<int>(0, (sum, row) {
                                if (identical(row, _mixed[index])) return sum;
                                return sum + widget.parseMajor(row.amount.text);
                              });
                              _mixed[index].amount.text = widget.major(
                                (widget.total - others).clamp(0, widget.total),
                              );
                            }),
                            onRemove: () => setState(() => _mixed.removeAt(index)),
                            onChanged: () => setState(() {}),
                          ),
                        OutlinedButton.icon(
                          onPressed: _tenderMethods.isEmpty
                              ? null
                              : () => setState(() {
                                    final used = _mixed.map((line) => line.method).toSet();
                                    final next =
                                        _tenderMethods.where((method) => !used.contains(method.value));
                                    _mixed.add(_MixControllers(
                                      method: next.isEmpty
                                          ? _tenderMethods.first.value
                                          : next.first.value,
                                      amount: '0',
                                    ));
                                  }),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PosUi.deskText,
                            side: BorderSide(color: PosUi.deskLine),
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(tr('Ajouter un mode')),
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
                enabled: _mode != 'credit' || widget.customer != null,
              ),
            ],
          ),
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

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.totalLabel,
    this.subtotalLabel,
    this.customerBalance,
  });

  final String totalLabel;
  final String? subtotalLabel;
  final String? customerBalance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: PosUi.deskField,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: Column(
        children: [
          if (subtotalLabel != null) ...[
            _SheetAmountRow(label: tr('Subtotal'), value: subtotalLabel!),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: PosUi.deskLine),
            ),
          ],
          _SheetAmountRow(label: tr('Amount Due'), value: totalLabel, emphasize: true),
          if (customerBalance != null) ...[
            const SizedBox(height: 8),
            Text(
              trf('Solde client {0}', [customerBalance]),
              style: AppTypography.text(fontSize: 12, color: PosUi.deskMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({
    required this.mode,
    required this.onChanged,
    this.creditEnabled = true,
  });

  final String mode;
  final ValueChanged<String> onChanged;
  final bool creditEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PosUi.deskCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: Row(
        children: [
          for (final entry in const [
            ('single', 'Simple'),
            ('mixed', 'Mixte'),
            ('credit', 'Crédit'),
          ])
            Expanded(
              child: Builder(
                builder: (context) {
                  final isCredit = entry.$1 == 'credit';
                  final enabled = !isCredit || creditEnabled;
                  final selected = mode == entry.$1;
                  return Opacity(
                    opacity: enabled ? 1 : 0.45,
                    child: Material(
                      color: selected ? PosUi.deskAccent : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      child: InkWell(
                        onTap: enabled ? () => onChanged(entry.$1) : null,
                        borderRadius: BorderRadius.circular(9),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            tr(entry.$2),
                            textAlign: TextAlign.center,
                            style: AppTypography.text(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: selected ? PosUi.deskInk : PosUi.deskMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
      color: selected ? PosUi.deskRaised : PosUi.deskField,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? PosUi.deskAccent.withValues(alpha: 0.55)
                  : PosUi.deskLine,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? PosUi.deskAccent : PosUi.deskMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(label),
                      style: AppTypography.text(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: PosUi.deskText,
                      ),
                    ),
                    if (hint != null)
                      Text(
                        tr(hint!),
                        style: AppTypography.text(fontSize: 10, color: AppColors.warning),
                      ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, size: 16, color: PosUi.deskAccent),
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
          Text(tr(label), style: AppTypography.text(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            tr(value),
            style: AppTypography.text(fontSize: 13, fontWeight: FontWeight.w800, color: color),
          ),
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

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosUi.deskCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 5,
                child: DropdownButtonFormField<String>(
                  initialValue: available.any((method) => method.value == line.method)
                      ? line.method
                      : available.firstOrNull?.value,
                  isExpanded: true,
                  dropdownColor: PosUi.deskCard,
                  decoration: InputDecoration(
                    labelText: tr('Mode'),
                    isDense: true,
                    filled: true,
                    fillColor: PosUi.deskField,
                    labelStyle: AppTypography.text(fontSize: 12, color: PosUi.deskMuted),
                    border: _border(PosUi.deskLine),
                    enabledBorder: _border(PosUi.deskLine),
                    focusedBorder: _border(PosUi.deskAccent),
                  ),
                  style: AppTypography.text(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PosUi.deskText,
                  ),
                  items: available
                      .map(
                        (method) => DropdownMenuItem(
                          value: method.value,
                          child: Text(tr(method.displayLabel), overflow: TextOverflow.ellipsis),
                        ),
                      )
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
                  cursorColor: PosUi.deskAccent,
                  style: AppTypography.text(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PosUi.deskText,
                  ),
                  decoration: InputDecoration(
                    labelText: tr('Montant'),
                    isDense: true,
                    filled: true,
                    fillColor: PosUi.deskField,
                    labelStyle: AppTypography.text(fontSize: 12, color: PosUi.deskMuted),
                    border: _border(PosUi.deskLine),
                    enabledBorder: _border(PosUi.deskLine),
                    focusedBorder: _border(PosUi.deskAccent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(
                onPressed: onFillRemaining,
                style: TextButton.styleFrom(foregroundColor: PosUi.deskAccent),
                child: Text(tr('= Reste')),
              ),
              const Spacer(),
              IconButton(
                tooltip: tr('Retirer'),
                onPressed: canRemove ? onRemove : null,
                icon: Icon(Icons.delete_outline, size: 18, color: PosUi.deskMuted),
              ),
            ],
          ),
          if (supportsChange)
            TextField(
              controller: line.tendered,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              cursorColor: PosUi.deskAccent,
              style: AppTypography.text(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: PosUi.deskText,
              ),
              decoration: InputDecoration(
                labelText: tr('Montant reçu'),
                isDense: true,
                filled: true,
                fillColor: PosUi.deskField,
                labelStyle: AppTypography.text(fontSize: 12, color: PosUi.deskMuted),
                border: _border(PosUi.deskLine),
                enabledBorder: _border(PosUi.deskLine),
                focusedBorder: _border(PosUi.deskAccent),
              ),
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
          Text(tr('Monnaie'), style: AppTypography.text(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(
            tr(value),
            style: AppTypography.text(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.success),
          ),
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
                tr(message),
                style: AppTypography.text(
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


class _ProcessHeader extends StatelessWidget {
  const _ProcessHeader({required this.onClose, this.customer});

  final VoidCallback onClose;
  final PosCustomer? customer;

  @override
  Widget build(BuildContext context) {
    final subtitle = customer == null
        ? tr('Choose a method or split the total')
        : customer!.displayLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PosUi.deskPay.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.payments_outlined, color: PosUi.deskPay, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Process Payment'),
                  style: AppTypography.text(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: PosUi.deskText,
                  ),
                ),
                Text(
                  tr(subtitle),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.text(fontSize: 13, color: PosUi.deskMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: tr('Fermer'),
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: PosUi.deskMuted),
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
          tr(label),
          style: AppTypography.text(
            fontSize: emphasize ? 15 : 13.5,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
            color: emphasize ? PosUi.deskText : PosUi.deskMuted,
          ),
        ),
        const Spacer(),
        Text(
          tr(value),
          style: AppTypography.text(
            fontSize: emphasize ? 22 : 15,
            fontWeight: FontWeight.w800,
            color: emphasize ? PosUi.deskAccent : PosUi.deskText,
          ),
        ),
      ],
    );
  }
}

class _ProcessModeTabs extends StatelessWidget {
  const _ProcessModeTabs({
    required this.mode,
    required this.onChanged,
    this.creditEnabled = true,
  });

  final String mode;
  final ValueChanged<String> onChanged;
  final bool creditEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PosUi.deskCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: Row(
        children: [
          for (final entry in const [
            ('single', 'Single'),
            ('mixed', 'Mixed'),
            ('credit', 'Credit'),
            ('house', 'H. Offer'),
          ])
            Expanded(
              child: Builder(
                builder: (context) {
                  final needsCustomer = entry.$1 == 'credit' || entry.$1 == 'house';
                  final enabled = !needsCustomer || creditEnabled;
                  final selected = mode == entry.$1;
                  return Opacity(
                    opacity: enabled ? 1 : 0.45,
                    child: Material(
                      color: selected ? PosUi.deskAccent : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      child: InkWell(
                        onTap: enabled ? () => onChanged(entry.$1) : null,
                        borderRadius: BorderRadius.circular(9),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                          child: Text(
                            tr(entry.$2),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.text(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected ? PosUi.deskInk : PosUi.deskMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr('Select a customer on this order to use Credit or House offer.'),
              style: AppTypography.text(fontSize: 12, height: 1.35, color: AppColors.warning),
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
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Text(
            tr('Remaining'),
            style: AppTypography.text(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.warning,
            ),
          ),
          const Spacer(),
          Text(
            tr(value),
            style: AppTypography.text(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.warning,
            ),
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
        color: PosUi.deskField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          hint: Text(
            tr('Select method'),
            style: AppTypography.text(fontSize: 14, color: PosUi.deskMuted),
          ),
          dropdownColor: PosUi.deskCard,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: PosUi.deskMuted),
          style: AppTypography.text(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: PosUi.deskText,
          ),
          items: [
            for (final method in methods)
              DropdownMenuItem(value: method.value, child: Text(tr(method.label))),
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
        color: PosUi.deskCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr(label),
              style: AppTypography.text(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PosUi.deskText,
              ),
            ),
          ),
          Text(
            tr(amount),
            style: AppTypography.text(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: PosUi.deskAccent,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.close, size: 16, color: PosUi.deskMuted),
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
      color: selected ? PosUi.deskRaised : PosUi.deskField,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? PosUi.deskAccent.withValues(alpha: 0.55)
                  : PosUi.deskLine,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? PosUi.deskAccent : PosUi.deskMuted,
              ),
              const SizedBox(width: 6),
              Text(
                tr(label),
                style: AppTypography.text(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? PosUi.deskText : PosUi.deskMuted,
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: PosUi.deskSoft,
        border: Border(top: BorderSide(color: PosUi.deskLine)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: PosUi.deskText,
                  side: BorderSide(color: PosUi.deskLine),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(tr('Cancel')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: enabled ? onConfirm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: PosUi.deskPay,
                  disabledBackgroundColor: PosUi.deskPay.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  tr('Encaisser'),
                  style: AppTypography.text(fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
