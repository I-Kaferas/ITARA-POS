import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/config/terminal_config_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../domain/pos_models.dart';
import 'pos_ui.dart';

class PosProductGrid extends StatelessWidget {
  const PosProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
  });

  final List<PosProduct> products;
  final ValueChanged<PosProduct> onProductTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PosUi.productsCanvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              '${products.length} article${products.length == 1 ? '' : 's'}',
              style: PosUi.caption(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const _EmptyProducts()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = width >= 720
                          ? 4
                          : width >= 520
                              ? 3
                              : 2;
                      final extent = width >= 520 ? 198.0 : 188.0;

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisExtent: extent,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return _ProductCard(
                            product: product,
                            onTap: () => onProductTap(product),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.brand50,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(Icons.inventory_2_outlined, size: 28, color: AppColors.brand600),
          ),
          const SizedBox(height: 12),
          Text('Aucun produit', style: PosUi.cardTitle()),
          const SizedBox(height: 4),
          Text('Modifiez la recherche ou la catégorie.', style: PosUi.caption()),
        ],
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({required this.product, required this.onTap});

  final PosProduct product;
  final VoidCallback onTap;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final trimmed = product.name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    final available = product.isAvailable;
    final price = MoneyFormatter.format(product.price, currencyCode: AppConfig.currencyCode);
    final imageUrl = resolvePosImageUrl(product.primaryImageUrl);
    final unit = product.unit?.trim();
    final stock = product.stockDisplay?.trim().isNotEmpty == true
        ? product.stockDisplay!.trim()
        : (product.quantityOnHand != null ? '${product.quantityOnHand}' : null);

    return AnimatedScale(
      scale: _pressed ? 0.975 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(PosUi.radiusMd),
        elevation: 0,
        child: InkWell(
          onTap: available
              ? () {
                  setState(() => _pressed = true);
                  Future<void>.delayed(const Duration(milliseconds: 120), () {
                    if (mounted) setState(() => _pressed = false);
                  });
                  widget.onTap();
                }
              : null,
          onTapDown: available ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(PosUi.radiusMd),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PosUi.radiusMd),
              border: Border.all(
                color: available ? AppColors.border : AppColors.danger.withValues(alpha: 0.35),
              ),
              boxShadow: AppColors.elevationSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 92,
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(PosUi.radiusMd - 1)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _ProductPhoto(url: imageUrl, initial: initial, available: available),
                        if (!available)
                          const Positioned(
                            left: 8,
                            top: 8,
                            child: PosBadge(label: 'Rupture', tone: PosBadgeTone.danger, compact: true),
                          ),
                        if (available && stock != null)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 88),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (product.quantityOnHand ?? 1) <= 0
                                    ? AppColors.danger
                                    : AppColors.textPrimary.withValues(alpha: 0.78),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                stock,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.plex(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PosUi.cardTitle(
                            color: available ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(product.sku, style: PosUi.caption()),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                available ? price : 'Rupture',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PosUi.money(
                                  size: 13,
                                  color: available ? AppColors.accent : AppColors.danger,
                                ),
                              ),
                            ),
                            if (product.hasOptions)
                              const PosBadge(label: 'Option', compact: true)
                            else if (unit != null && unit.isNotEmpty)
                              PosBadge(label: unit, tone: PosBadgeTone.neutral, compact: true),
                          ],
                        ),
                      ],
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

String? resolvePosImageUrl(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();
  if (value.startsWith('http://') || value.startsWith('https://')) return value;

  final api = TerminalConfigRepository.instance.config.apiBaseUrl;
  final uri = Uri.tryParse(api);
  if (uri == null || uri.host.isEmpty) return value;
  final origin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  return value.startsWith('/') ? '$origin$value' : '$origin/$value';
}

class _ProductPhoto extends StatelessWidget {
  const _ProductPhoto({
    required this.url,
    required this.initial,
    required this.available,
  });

  final String? url;
  final String initial;
  final bool available;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.brand50,
      child: url == null
          ? _fallback()
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _fallback();
              },
            ),
    );
  }

  Widget _fallback() {
    return Center(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brand100,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          initial,
          style: AppTypography.plex(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: available ? AppColors.brand600 : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
