import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../services/pos_cart_engine.dart';
import 'pos_ui.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

enum DiscountDialogResult { applied, cleared, cancelled }

bool _useMobileDiscountSheet(BuildContext context) {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    return true;
  }
  return !PosUi.isWindowsDesk(context);
}

Future<DiscountDialogResult?> showPosDiscountDialog({
  required BuildContext context,
  required PosCartEngine cart,
  required String Function(int amount) money,
  required String Function(int amount) major,
  required int Function(String value) parseMajor,
}) {
  final mobileSheet = _useMobileDiscountSheet(context);
  return showDialog<DiscountDialogResult>(
    context: context,
    barrierColor: mobileSheet ? const Color(0xCC070B14) : const Color(0x660F172A),
    builder: (context) => _DiscountDialog(
      cart: cart,
      money: money,
      major: major,
      parseMajor: parseMajor,
      mobileSheet: mobileSheet,
    ),
  );
}

class _DiscountDialog extends StatefulWidget {
  const _DiscountDialog({
    required this.cart,
    required this.money,
    required this.major,
    required this.parseMajor,
    required this.mobileSheet,
  });

  final PosCartEngine cart;
  final String Function(int amount) money;
  final String Function(int amount) major;
  final int Function(String value) parseMajor;
  final bool mobileSheet;

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  static const _quickPercents = [5.0, 10.0, 15.0, 20.0];

  late bool _percentMode;
  late final TextEditingController _valueCtrl;
  String? _error;

  int get _subtotal => widget.cart.subtotal;

  @override
  void initState() {
    super.initState();
    final cart = widget.cart;
    _percentMode = cart.discountPercent > 0 || cart.discountAmount <= 0;
    if (cart.discountPercent > 0) {
      _valueCtrl = TextEditingController(
        text: cart.discountPercent == cart.discountPercent.roundToDouble()
            ? '${cart.discountPercent.round()}'
            : cart.discountPercent.toStringAsFixed(2),
      );
    } else if (cart.discountAmount > 0) {
      _valueCtrl = TextEditingController(text: widget.major(cart.discountAmount));
    } else {
      _valueCtrl = TextEditingController();
    }
    _valueCtrl.addListener(() {
      if (mounted) setState(() => _error = null);
    });
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  int get _previewDiscount {
    if (_percentMode) {
      final percent = double.tryParse(_valueCtrl.text.trim().replaceAll(',', '.')) ?? 0;
      if (percent <= 0) return 0;
      return (_subtotal * percent.clamp(0, 100) / 100).round().clamp(0, _subtotal);
    }
    final amount = widget.parseMajor(_valueCtrl.text);
    return amount.clamp(0, _subtotal);
  }

  int get _previewTotal => (_subtotal - _previewDiscount).clamp(0, 1 << 31);

  void _setMode(bool percent) {
    if (_percentMode == percent) return;
    setState(() {
      _percentMode = percent;
      _valueCtrl.clear();
      _error = null;
    });
  }

  void _applyQuickPercent(double percent) {
    setState(() {
      _percentMode = true;
      _valueCtrl.text = percent == percent.roundToDouble() ? '${percent.round()}' : '$percent';
      _error = null;
    });
  }

  void _apply() {
    if (_percentMode) {
      final percent = double.tryParse(_valueCtrl.text.trim().replaceAll(',', '.'));
      if (percent == null || percent <= 0) {
        setState(() => _error = tr('Saisissez un pourcentage valide'));
        return;
      }
      if (percent > 100) {
        setState(() => _error = tr('La remise ne peut pas dépasser 100 %'));
        return;
      }
      widget.cart.setDiscountPercent(percent);
      Navigator.pop(context, DiscountDialogResult.applied);
      return;
    }

    final amount = widget.parseMajor(_valueCtrl.text);
    if (amount <= 0) {
      setState(() => _error = tr('Saisissez un montant valide'));
      return;
    }
    if (amount > _subtotal) {
      setState(() => _error = tr('La remise dépasse le sous-total'));
      return;
    }
    widget.cart.setDiscountAmount(amount);
    Navigator.pop(context, DiscountDialogResult.applied);
  }

  void _clear() {
    widget.cart.clearDiscount();
    Navigator.pop(context, DiscountDialogResult.cleared);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final hasDiscount = widget.cart.discountTotal > 0 ||
        widget.cart.discountPercent > 0 ||
        widget.cart.discountAmount > 0;

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
                      color: AppColors.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.discount_rounded, color: AppColors.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Remise'),
                          style: AppTypography.text(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: PosUi.deskText,
                          ),
                        ),
                        Text(
                          tr('Réduction sur le panier'),
                          style: AppTypography.text(fontSize: 13, color: PosUi.deskMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr('Fermer'),
                    onPressed: () => Navigator.pop(context, DiscountDialogResult.cancelled),
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
                      subtotal: widget.money(_subtotal),
                      discount: widget.money(_previewDiscount),
                      total: widget.money(_previewTotal),
                      active: _previewDiscount > 0,
                    ),
                    const SizedBox(height: 16),
                    _ModeToggle(
                      percentMode: _percentMode,
                      onChanged: _setMode,
                    ),
                    const SizedBox(height: 14),
                    if (_percentMode) ...[
                      Text(
                        tr('Raccourcis'),
                        style: AppTypography.text(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PosUi.deskMuted,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in _quickPercents)
                            _QuickChip(
                              label: '${p.round()} %',
                              selected: _percentMode &&
                                  (double.tryParse(_valueCtrl.text.trim().replaceAll(',', '.')) ?? -1) == p,
                              onTap: () => _applyQuickPercent(p),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    _ValueField(
                      controller: _valueCtrl,
                      percentMode: _percentMode,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          borderRadius: AppRadius.borderLg,
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          tr(_error!),
                          style: AppTypography.text(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, widget.mobileSheet ? 18 : 16),
              decoration: BoxDecoration(
                color: PosUi.deskSoft,
                border: Border(top: BorderSide(color: PosUi.deskLine)),
              ),
              child: Row(
                children: [
                  if (hasDiscount)
                    TextButton(
                      onPressed: _clear,
                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                      child: Text(
                        tr('Effacer'),
                        style: AppTypography.text(fontWeight: FontWeight.w700, color: AppColors.danger),
                      ),
                    ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, DiscountDialogResult.cancelled),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PosUi.deskText,
                      side: BorderSide(color: PosUi.deskLine),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(tr('Annuler')),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.brand900,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      tr('Appliquer'),
                      style: AppTypography.text(fontWeight: FontWeight.w800, color: AppColors.brand900),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.active,
  });

  final String subtotal;
  final String discount;
  final String total;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosUi.deskField,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: Column(
        children: [
          _SummaryLine(label: tr('Sous-total'), value: subtotal),
          const SizedBox(height: 8),
          _SummaryLine(
            label: tr('Remise'),
            value: active ? '- $discount' : '—',
            emphasize: active,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: PosUi.deskLine),
          ),
          Row(
            children: [
              Text(
                tr('Nouveau total'),
                style: AppTypography.text(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PosUi.deskText,
                ),
              ),
              const Spacer(),
              Text(
                total,
                style: AppTypography.text(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: active ? AppColors.accent : PosUi.deskText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: AppTypography.text(fontSize: 13.5, color: PosUi.deskMuted),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.text(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: emphasize ? AppColors.danger : PosUi.deskText,
          ),
        ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.percentMode, required this.onChanged});

  final bool percentMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PosUi.deskField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              label: tr('Pourcentage'),
              icon: Icons.percent_rounded,
              selected: percentMode,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _ModeChip(
              label: tr('Montant'),
              icon: Icons.payments_outlined,
              selected: !percentMode,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
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
      color: selected ? AppColors.brand600 : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : PosUi.deskMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.text(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : PosUi.deskMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent.withValues(alpha: 0.2) : PosUi.deskSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent.withValues(alpha: 0.55) : PosUi.deskLine,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.text(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.accent : PosUi.deskText,
            ),
          ),
        ),
      ),
    );
  }
}

class _ValueField extends StatelessWidget {
  const _ValueField({
    required this.controller,
    required this.percentMode,
  });

  final TextEditingController controller;
  final bool percentMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PosUi.deskField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: AppTypography.text(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: PosUi.deskText,
          letterSpacing: 0.4,
        ),
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          hintText: percentMode ? '0' : '0.00',
          hintStyle: AppTypography.text(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: PosUi.deskMuted.withValues(alpha: 0.55),
          ),
          suffixText: percentMode ? '%' : null,
          suffixStyle: AppTypography.text(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: PosUi.deskMuted,
          ),
        ),
      ),
    );
  }
}
