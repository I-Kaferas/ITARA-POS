import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../domain/pos_models.dart';
import '../../services/pos_cart_engine.dart';
import 'pos_product_grid.dart';
import 'pos_ui.dart';

class PosCartPanel extends StatelessWidget {
  const PosCartPanel({
    super.key,
    required this.cart,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final PosCartEngine cart;
  final ValueChanged<String> onIncrement;
  final ValueChanged<String> onDecrement;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PosUi.cartCanvas,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Panier',
                        style: AppTypography.sectionTitle(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${cart.itemCount} article${cart.itemCount == 1 ? '' : 's'}',
                        style: PosUi.caption(),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 28),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brand100,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${cart.lines.length}',
                    textAlign: TextAlign.center,
                    style: AppTypography.plex(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand700,
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
                      );
                    },
                  ),
          ),
        ],
      ),
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
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brand100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brand600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Aucun article', style: PosUi.cardTitle(color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text(
              'Touchez un produit pour l’ajouter.',
              textAlign: TextAlign.center,
              style: PosUi.caption(),
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
  });

  final PosCartLine line;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final unit = line.product.unit?.trim();
    final imageUrl = resolvePosImageUrl(line.product.primaryImageUrl);
    final initial = line.product.name.trim().isEmpty
        ? '?'
        : line.product.name.trim()[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(PosUi.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.elevationSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CartThumb(url: imageUrl, initial: initial),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: PosUi.cardTitle(),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            line.product.sku,
                            style: PosUi.caption(color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: onRemove,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    'P.U. ${MoneyFormatter.format(line.unitPrice, currencyCode: AppConfig.currencyCode)}',
                    if (unit != null && unit.isNotEmpty) unit,
                  ].join(' · '),
                  style: PosUi.caption(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QtyButton(icon: Icons.remove_rounded, onPressed: onDecrement),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${line.quantity}',
                        style: GoogleFonts.ibmPlexSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _QtyButton(icon: Icons.add_rounded, onPressed: onIncrement),
                    const Spacer(),
                    Text(
                      MoneyFormatter.format(
                        line.lineSubtotal,
                        currencyCode: AppConfig.currencyCode,
                      ),
                      style: PosUi.money(size: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartThumb extends StatelessWidget {
  const _CartThumb({required this.url, required this.initial});

  final String? url;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: SizedBox(
        width: 50,
        height: 50,
        child: ColoredBox(
          color: AppColors.brand100,
          child: url == null
              ? Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.ibmPlexSans(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand700,
                    ),
                  ),
                )
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand700,
                      ),
                    ),
                  ),
                ),
        ),
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
          side: BorderSide(color: AppColors.borderStrong),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PosUi.radiusSm)),
          foregroundColor: AppColors.brandInk,
          backgroundColor: AppColors.fieldFill,
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}
