import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../domain/pos_models.dart';
import '../../services/pos_cart_engine.dart';
import '../customer_display_launcher.dart';
import 'pos_ui.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

class PosCartPanel extends StatelessWidget {
  const PosCartPanel({
    super.key,
    required this.cart,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    this.onEditLine,
    this.onSearchCustomer,
    this.onSelectTable,
    this.showCheckout = false,
    this.onHold,
    this.onClear,
    this.onPay,
    this.onDiscount,
    this.onCustomerDisplay,
  });

  final PosCartEngine cart;
  final ValueChanged<String> onIncrement;
  final ValueChanged<String> onDecrement;
  final ValueChanged<String> onRemove;
  final void Function(String lineId)? onEditLine;
  final VoidCallback? onSearchCustomer;

  /// Restaurant mode only; null hides the table selector.
  final VoidCallback? onSelectTable;
  final bool showCheckout;
  final VoidCallback? onHold;
  final VoidCallback? onClear;
  final VoidCallback? onPay;
  final VoidCallback? onDiscount;
  final VoidCallback? onCustomerDisplay;

  Widget _customerField() {
    return Material(
      color: PosUi.deskField,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onSearchCustomer,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PosUi.deskLine),
          ),
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: PosUi.deskMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(cart.customer?.displayLabel ?? 'Search a customer...'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.plex(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cart.customer == null ? PosUi.deskMuted : PosUi.deskText,
                  ),
                ),
              ),
              if (cart.customer != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => cart.setCustomer(null),
                  icon: Icon(Icons.close, size: 16, color: PosUi.deskMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PosUi.deskPanel,
        border: Border(left: BorderSide(color: PosUi.deskLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              color: PosUi.deskPanel,
              border: Border(bottom: BorderSide(color: PosUi.deskLine)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 46,
                  child: Row(
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 18, color: PosUi.deskText),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          cart.hasTable ? 'Table ${cart.tableDisplay}' : tr('Current Order'),
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.plex(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: PosUi.deskText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: PosUi.deskAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${cart.lines.length}',
                          style: AppTypography.plex(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: PosUi.deskInk,
                          ),
                        ),
                      ),
                      const Spacer(),
                      ValueListenableBuilder<bool>(
                        valueListenable: CustomerDisplayLauncher.busy,
                        builder: (context, busy, _) {
                          return IconButton(
                            tooltip: tr('Preview Customer display'),
                            onPressed: busy ? null : onCustomerDisplay,
                            icon: Icon(Icons.monitor_outlined, size: 18, color: PosUi.deskMuted),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _customerField()),
                    if (onSelectTable != null) ...[
                      const SizedBox(width: 8),
                      _TableButton(label: cart.tableDisplay, onTap: onSelectTable!),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (cart.isEditingHold)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(PosUi.radiusSm),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.edit_note_rounded, size: 18, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trf('Modification — {0}\nAjoutez des articles puis Enregistrer (Attente)', [cart.activeHoldLabel ?? 'commande en attente']),
                        style: AppTypography.text(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: cart.lines.isEmpty
                ? const _EmptyCart()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: cart.lines.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final line = cart.lines[index];
                      return _CartLineTile(
                        line: line,
                        onIncrement: () => onIncrement(line.lineId),
                        onDecrement: () => onDecrement(line.lineId),
                        onRemove: () => onRemove(line.lineId),
                        onEdit: onEditLine == null || line.isAccompaniment
                            ? null
                            : () => onEditLine!(line.lineId),
                      );
                    },
                  ),
          ),
          if (showCheckout) _OrderCheckout(
            cart: cart,
            onHold: onHold,
            onClear: onClear,
            onPay: onPay,
            onDiscount: onDiscount,
          ),
        ],
      ),
    );
  }
}

class _OrderCheckout extends StatelessWidget {
  const _OrderCheckout({
    required this.cart,
    this.onHold,
    this.onClear,
    this.onPay,
    this.onDiscount,
  });

  final PosCartEngine cart;
  final VoidCallback? onHold;
  final VoidCallback? onClear;
  final VoidCallback? onPay;
  final VoidCallback? onDiscount;

  String _money(int amount) => MoneyFormatter.format(amount, currencyCode: AppConfig.currencyCode);

  @override
  Widget build(BuildContext context) {
    final discountLabel = cart.discountTotal > 0 ? _money(cart.discountTotal) : 'Discount';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: PosUi.deskPanel,
        border: Border(top: BorderSide(color: PosUi.deskLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: PosUi.deskField,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onDiscount,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PosUi.deskLine),
                ),
                child: Row(
                  children: [
                    Text('%', style: AppTypography.plex(color: PosUi.deskMuted, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(discountLabel),
                        style: AppTypography.plex(
                          fontSize: 13,
                          color: cart.discountTotal > 0 ? PosUi.deskText : PosUi.deskMuted,
                        ),
                      ),
                    ),
                    Text('%', style: AppTypography.plex(color: PosUi.deskMuted, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _TotalRow(label: tr('Subtotal'), value: _money(cart.subtotal)),
          const SizedBox(height: 4),
          _TotalRow(label: tr('Tax'), value: _money(cart.taxTotal)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(tr('Total'), style: AppTypography.plex(fontSize: 16, fontWeight: FontWeight.w800, color: PosUi.deskText)),
              const Spacer(),
              AppValueFade(
                value: cart.total,
                child: Text(
                  tr(_money(cart.total)),
                  style: AppTypography.plex(fontSize: 22, fontWeight: FontWeight.w800, color: PosUi.deskAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: cart.isEmpty ? null : onPay,
            style: FilledButton.styleFrom(
              backgroundColor: PosUi.deskPay,
              disabledBackgroundColor: PosUi.deskPay.withValues(alpha: 0.35),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white70,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.lock_outline, size: 16),
            label: Text(tr('Pay & Close'), style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: cart.isEmpty ? null : onHold,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PosUi.deskText,
                    side: BorderSide(color: PosUi.deskLine),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.pause_rounded, size: 16),
                  label: Text(tr('Hold')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: cart.isEmpty ? null : onClear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.45)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(tr('Clear Cart')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(tr(label), style: AppTypography.plex(fontSize: 13, color: PosUi.deskMuted)),
        const Spacer(),
        Text(tr(value), style: AppTypography.plex(fontSize: 13, fontWeight: FontWeight.w600, color: PosUi.deskText)),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 56, color: PosUi.deskMuted.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(tr('Cart is empty'), style: PosUi.cardTitle(color: PosUi.deskText)),
            const SizedBox(height: 4),
            Text(
              tr('Tap on products to add them'),
              textAlign: TextAlign.center,
              style: PosUi.caption(color: PosUi.deskMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    this.onEdit,
  });

  final PosCartLine line;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final unit = line.product.unit?.trim();
    final net = (line.lineSubtotal - line.lineDiscountFixed).clamp(0, line.lineSubtotal);
    final onHand = line.product.quantityOnHand;
    final money = MoneyFormatter.format(line.unitPrice, currencyCode: AppConfig.currencyCode);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(unit == null || unit.isEmpty ? line.displayName : '${line.displayName} ($unit)'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PosUi.cardTitle(color: PosUi.deskText),
                ),
              ),
              if (onEdit != null)
                Tooltip(
                  message: tr('Edit price & quantity'),
                  child: InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined, size: 16, color: PosUi.deskAccent),
                    ),
                  ),
                ),
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(
                child: Text(
                  tr(money),
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.plex(fontSize: 12, fontWeight: FontWeight.w700, color: PosUi.deskAccent),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.check_rounded, size: 14, color: PosUi.deskStock),
              const SizedBox(width: 6),
              _QtyButton(icon: Icons.remove, onPressed: onDecrement),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AppValueFade(
                  value: line.quantity,
                  child: Text(
                    '${line.quantity}',
                    style: AppTypography.text(fontWeight: FontWeight.w800, fontSize: 14, color: PosUi.deskText),
                  ),
                ),
              ),
              _QtyButton(icon: Icons.add, onPressed: onIncrement),
              const Spacer(),
              Text(
                tr(MoneyFormatter.format(net, currencyCode: AppConfig.currencyCode)),
                style: PosUi.money(size: 13, weight: FontWeight.w800, color: PosUi.deskText),
              ),
            ],
          ),
          if (onHand != null) ...[
            const SizedBox(height: 2),
            Text(
              trf('{0} {1} available', [
                onHand - line.quantity,
                unit == null || unit.isEmpty ? 'pcs' : unit,
              ]),
              style: AppTypography.plex(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: onHand - line.quantity <= 0 ? AppColors.danger : PosUi.deskStock,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(34, 34),
          side: BorderSide(color: PosUi.deskLine),
          shape: const CircleBorder(),
          foregroundColor: PosUi.deskText,
          backgroundColor: PosUi.deskField,
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class _TableButton extends StatelessWidget {
  const _TableButton({required this.label, required this.onTap});

  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = label != null;
    return Tooltip(
      message: selected ? 'Changer de table' : 'Choisir une table',
      child: Material(
        color: selected ? PosUi.deskAccent.withValues(alpha: 0.16) : PosUi.deskField,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 42,
            constraints: const BoxConstraints(minWidth: 42, maxWidth: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? PosUi.deskAccent : PosUi.deskLine),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.table_restaurant_outlined,
                  size: 18,
                  color: selected ? PosUi.deskText : PosUi.deskMuted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label ?? 'Table',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.plex(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? PosUi.deskText : PosUi.deskMuted,
                    ),
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
