import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../domain/pos_models.dart';
import 'pos_ui.dart';

class PosQuickProductsBar extends StatelessWidget {
  const PosQuickProductsBar({
    super.key,
    required this.products,
    required this.onProductTap,
  });

  final List<PosProduct> products;
  final ValueChanged<PosProduct> onProductTap;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text('PRODUITS RAPIDES', style: PosUi.sectionLabel()),
          ),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final product = products[index];
                return _QuickChip(
                  product: product,
                  onTap: () => onProductTap(product),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.product, required this.onTap});

  final PosProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = product.isAvailable;
    return Material(
      color: available ? AppColors.brand50 : AppColors.fieldFill,
      borderRadius: BorderRadius.circular(PosUi.radiusSm),
      child: InkWell(
        onTap: available ? onTap : null,
        borderRadius: BorderRadius.circular(PosUi.radiusSm),
        child: Container(
          width: 148,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosUi.radiusSm),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PosUi.cardTitle(
                  color: available ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                MoneyFormatter.format(product.price, currencyCode: AppConfig.currencyCode),
                style: PosUi.caption(color: AppColors.brand700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
