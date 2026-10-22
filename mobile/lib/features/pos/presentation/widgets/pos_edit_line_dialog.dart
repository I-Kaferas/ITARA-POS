import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/pos_models.dart';
import 'pos_ui.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

class EditLineDialogResult {
  const EditLineDialogResult({
    required this.quantity,
    required this.unitPrice,
  });

  final int quantity;
  final int unitPrice;
}

bool _useMobileSheet(BuildContext context) {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    return true;
  }
  return !PosUi.isWindowsDesk(context);
}

Future<EditLineDialogResult?> showPosEditLineDialog({
  required BuildContext context,
  required PosCartLine line,
  required String Function(int amount) money,
  required String Function(int amount) major,
  required int Function(String value) parseMajor,
}) {
  final mobileSheet = _useMobileSheet(context);
  return showDialog<EditLineDialogResult>(
    context: context,
    useRootNavigator: true,
    barrierColor: mobileSheet ? const Color(0xCC070B14) : const Color(0x660F172A),
    builder: (context) => _EditLineDialog(
      line: line,
      money: money,
      major: major,
      parseMajor: parseMajor,
      mobileSheet: mobileSheet,
    ),
  );
}

class _EditLineDialog extends StatefulWidget {
  const _EditLineDialog({
    required this.line,
    required this.money,
    required this.major,
    required this.parseMajor,
    required this.mobileSheet,
  });

  final PosCartLine line;
  final String Function(int amount) money;
  final String Function(int amount) major;
  final int Function(String value) parseMajor;
  final bool mobileSheet;

  @override
  State<_EditLineDialog> createState() => _EditLineDialogState();
}

class _EditLineDialogState extends State<_EditLineDialog> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '${widget.line.quantity}');
    _priceCtrl = TextEditingController(text: widget.major(widget.line.unitPrice));
    _qtyCtrl.addListener(_onChanged);
    _priceCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _qtyCtrl.removeListener(_onChanged);
    _priceCtrl.removeListener(_onChanged);
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() => _error = null);
  }

  int get _quantity {
    final raw = int.tryParse(_qtyCtrl.text.trim());
    return raw ?? 0;
  }

  int get _unitPrice => widget.parseMajor(_priceCtrl.text);

  int get _lineTotal => (_quantity.clamp(0, 1 << 31) * _unitPrice).clamp(0, 1 << 31);

  void _bumpQty(int delta) {
    final next = (_quantity <= 0 ? widget.line.quantity : _quantity) + delta;
    if (next < 1) return;
    _qtyCtrl.text = '$next';
    _qtyCtrl.selection = TextSelection.collapsed(offset: _qtyCtrl.text.length);
  }

  void _save() {
    final qty = _quantity;
    if (qty < 1) {
      setState(() => _error = tr('Enter a quantity of at least 1'));
      return;
    }
    if (_unitPrice < 0) {
      setState(() => _error = tr('Enter a valid unit price'));
      return;
    }
    Navigator.pop(
      context,
      EditLineDialogResult(quantity: qty, unitPrice: _unitPrice),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final unit = widget.line.product.unit?.trim();

    final panel = Material(
      color: PosUi.deskPanel,
      borderRadius: widget.mobileSheet
          ? const BorderRadius.vertical(top: Radius.circular(28))
          : BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.mobileSheet ? size.width : 440,
          maxHeight: widget.mobileSheet ? size.height * 0.92 : 640,
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: widget.mobileSheet ? inset : 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.mobileSheet)
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
              Padding(
                padding: EdgeInsets.fromLTRB(20, widget.mobileSheet ? 8 : 20, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: PosUi.deskAccent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.edit_outlined, color: PosUi.deskAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('Edit line'),
                            style: AppTypography.text(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: PosUi.deskText,
                            ),
                          ),
                          Text(
                            tr('Price & quantity'),
                            style: AppTypography.text(fontSize: 13, color: PosUi.deskMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tr('Fermer'),
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: PosUi.deskMuted),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SummaryCard(
                        name: widget.line.displayName,
                        unit: unit == null || unit.isEmpty ? null : unit,
                        qty: _quantity < 1 ? widget.line.quantity : _quantity,
                        unitPrice: widget.money(_unitPrice),
                        total: widget.money(_lineTotal),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr('Quantity'),
                        style: AppTypography.text(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: PosUi.deskMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _QtyChip(
                            icon: Icons.remove_rounded,
                            onTap: () => _bumpQty(-1),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: PosUi.deskField,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: PosUi.deskLine),
                              ),
                              child: TextField(
                                controller: _qtyCtrl,
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                cursorColor: PosUi.deskAccent,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: AppTypography.text(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: PosUi.deskText,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _QtyChip(
                            icon: Icons.add_rounded,
                            onTap: () => _bumpQty(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        tr('Unit price'),
                        style: AppTypography.text(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: PosUi.deskMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: PosUi.deskField,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: PosUi.deskLine),
                        ),
                        child: TextField(
                          controller: _priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          cursorColor: PosUi.deskAccent,
                          style: AppTypography.text(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: PosUi.deskText,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            suffixText: AppConfig.currencyCode,
                            suffixStyle: AppTypography.text(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: PosUi.deskMuted,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.dangerBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            _error!,
                            style: AppTypography.text(fontSize: 12, color: AppColors.danger),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
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
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PosUi.deskText,
                            side: BorderSide(color: PosUi.deskLine),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(tr('Annuler')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: PosUi.deskAccent,
                            foregroundColor: PosUi.deskInk,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            tr('Save'),
                            style: AppTypography.text(
                              fontWeight: FontWeight.w800,
                              color: PosUi.deskInk,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!widget.mobileSheet) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: panel,
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: panel,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.total,
    this.unit,
  });

  final String name;
  final String? unit;
  final int qty;
  final String unitPrice;
  final String total;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.text(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: PosUi.deskText,
            ),
          ),
          if (unit != null) ...[
            const SizedBox(height: 2),
            Text(
              unit!,
              style: AppTypography.text(fontSize: 12, color: PosUi.deskMuted),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: PosUi.deskLine),
          ),
          Row(
            children: [
              Text(
                trf('{0} × {1}', ['$qty', unitPrice]),
                style: AppTypography.text(fontSize: 13, color: PosUi.deskMuted),
              ),
              const Spacer(),
              Text(
                total,
                style: AppTypography.text(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: PosUi.deskAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyChip extends StatelessWidget {
  const _QtyChip({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosUi.deskField,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PosUi.deskLine),
          ),
          child: Icon(icon, size: 20, color: PosUi.deskText),
        ),
      ),
    );
  }
}
