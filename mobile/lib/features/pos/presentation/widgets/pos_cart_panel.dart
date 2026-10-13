import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../domain/pos_models.dart';
import '../../services/pos_cart_engine.dart';
import 'pos_ui.dart';

class PosCartPanel extends StatelessWidget {
  const PosCartPanel({
    super.key,
    required this.cart,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    this.onLineDiscount,
    this.onSearchCustomer,
    this.showCheckout = false,
    this.onHold,
    this.onClear,
    this.onPay,
    this.onDiscount,
    this.onNewSale,
    this.onRetrieve,
    this.onCustomerDisplay,
    this.onNote,
    this.onLoyalty,
    this.onSplit,
  });

  final PosCartEngine cart;
  final ValueChanged<String> onIncrement;
  final ValueChanged<String> onDecrement;
  final ValueChanged<String> onRemove;
  final void Function(String lineId)? onLineDiscount;
  final VoidCallback? onSearchCustomer;
  final bool showCheckout;
  final VoidCallback? onHold;
  final VoidCallback? onClear;
  final VoidCallback? onPay;
  final VoidCallback? onDiscount;
  final VoidCallback? onNewSale;
  final VoidCallback? onRetrieve;
  final VoidCallback? onCustomerDisplay;
  final VoidCallback? onNote;
  final VoidCallback? onLoyalty;
  final VoidCallback? onSplit;

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
                          cart.tableId == null || cart.tableId!.isEmpty
                              ? 'Current Order'
                              : 'Table ${cart.tableId}',
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
                      IconButton(
                        tooltip: 'Preview Customer display',
                        onPressed: onCustomerDisplay,
                        icon: Icon(Icons.monitor_outlined, size: 18, color: PosUi.deskMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Material(
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
                              cart.customer?.displayLabel ?? 'Search a customer...',
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
                        'Modification — ${cart.activeHoldLabel ?? 'commande en attente'}\nAjoutez des articles puis Enregistrer (Attente)',
                        style: GoogleFonts.ibmPlexSans(
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
                        onDiscount: onLineDiscount == null || line.isAccompaniment
                            ? null
                            : () => onLineDiscount!(line.lineId),
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
            onNewSale: onNewSale,
            onRetrieve: onRetrieve,
            onNote: onNote,
            onLoyalty: onLoyalty,
            onSplit: onSplit,
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
    this.onNewSale,
    this.onRetrieve,
    this.onNote,
    this.onLoyalty,
    this.onSplit,
  });

  final PosCartEngine cart;
  final VoidCallback? onHold;
  final VoidCallback? onClear;
  final VoidCallback? onPay;
  final VoidCallback? onDiscount;
  final VoidCallback? onNewSale;
  final VoidCallback? onRetrieve;
  final VoidCallback? onNote;
  final VoidCallback? onLoyalty;
  final VoidCallback? onSplit;

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
                        discountLabel,
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
          _TotalRow(label: 'Subtotal', value: _money(cart.subtotal)),
          const SizedBox(height: 4),
          _TotalRow(label: 'Tax', value: _money(cart.taxTotal)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Total', style: AppTypography.plex(fontSize: 16, fontWeight: FontWeight.w800, color: PosUi.deskText)),
              const Spacer(),
              AppValueFade(
                value: cart.total,
                child: Text(
                  _money(cart.total),
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
            label: const Text('Pay & Close', style: TextStyle(fontWeight: FontWeight.w800)),
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
                  label: const Text('Hold'),
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
                  label: const Text('Clear Cart'),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (value) {
                  switch (value) {
                    case 'pay':
                      onPay?.call();
                    case 'new':
                      onNewSale?.call();
                    case 'retrieve':
                      onRetrieve?.call();
                    case 'note':
                      onNote?.call();
                    case 'loyalty':
                      onLoyalty?.call();
                    case 'split':
                      onSplit?.call();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'pay', child: Text('Pay')),
                  const PopupMenuItem(value: 'new', child: Text('New sale')),
                  const PopupMenuItem(value: 'retrieve', child: Text('Held orders')),
                  const PopupMenuItem(value: 'split', child: Text('Split')),
                  const PopupMenuItem(value: 'note', child: Text('Note')),
                  const PopupMenuItem(value: 'loyalty', child: Text('Loyalty')),
                ],
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: PosUi.deskField,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PosUi.deskLine),
                  ),
                  child: Icon(Icons.apps_rounded, color: PosUi.deskText, size: 18),
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
        Text(label, style: AppTypography.plex(fontSize: 13, color: PosUi.deskMuted)),
        const Spacer(),
        Text(value, style: AppTypography.plex(fontSize: 13, fontWeight: FontWeight.w600, color: PosUi.deskText)),
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
            Text('Cart is empty', style: PosUi.cardTitle(color: PosUi.deskText)),
            const SizedBox(height: 4),
            Text(
              'Tap on products to add them',
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
    this.onDiscount,
  });

  final PosCartLine line;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback? onDiscount;

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
                  unit == null || unit.isEmpty ? line.displayName : '${line.displayName} ($unit)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PosUi.cardTitle(color: PosUi.deskText),
                ),
              ),
              if (onDiscount != null)
                InkWell(
                  onTap: onDiscount,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.edit_outlined, size: 16, color: PosUi.deskAccent),
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
                  money,
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
                    style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w800, fontSize: 14, color: PosUi.deskText),
                  ),
                ),
              ),
              _QtyButton(icon: Icons.add, onPressed: onIncrement),
              const Spacer(),
              Text(
                MoneyFormatter.format(net, currencyCode: AppConfig.currencyCode),
                style: PosUi.money(size: 13, weight: FontWeight.w800, color: PosUi.deskText),
              ),
            ],
          ),
          if (onHand != null) ...[
            const SizedBox(height: 2),
            Text(
              '$onHand ${unit == null || unit.isEmpty ? 'pcs' : unit} available',
              style: AppTypography.plex(fontSize: 11, fontWeight: FontWeight.w600, color: PosUi.deskStock),
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
