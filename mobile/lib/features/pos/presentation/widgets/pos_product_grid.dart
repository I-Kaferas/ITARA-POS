import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/config/terminal_config_repository.dart';
import '../../../../core/layout/android_form_factor.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../domain/pos_models.dart';
import 'pos_ui.dart';

class PosCatalogSkeleton extends StatelessWidget {
  const PosCatalogSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PosUi.deskNight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = AndroidLayout.productColumns(MediaQuery.sizeOf(context).width);
          final extent = width >= 520 ? 228.0 : 214.0;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: extent,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: columns * 3,
            itemBuilder: (_, _) => const _CatalogCardSkeleton(),
          );
        },
      ),
    );
  }
}

class _CatalogCardSkeleton extends StatelessWidget {
  const _CatalogCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PosUi.deskCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: const SizedBox.expand(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSkeleton(height: 108, borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: AppSkeleton(width: 120, height: 14),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: AppSkeleton(width: 72, height: 16),
          ),
          Spacer(),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: AppSkeleton(width: double.infinity, height: 12),
          ),
        ],
        ),
      ),
    );
  }
}

class PosProductGrid extends StatelessWidget {
  const PosProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    this.favoriteIds = const {},
    this.onToggleFavorite,
    this.quantityOf,
    this.menuTitle,
  });

  final List<PosProduct> products;
  final ValueChanged<PosProduct> onProductTap;
  final Set<String> favoriteIds;
  final ValueChanged<PosProduct>? onToggleFavorite;
  final int Function(PosProduct product)? quantityOf;
  final String? menuTitle;

  @override
  Widget build(BuildContext context) {
    assert(menuTitle == null || menuTitle is String);
    return ColoredBox(
      color: PosUi.deskNight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: products.isEmpty
                ? const _EmptyProducts()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = AndroidLayout.productColumns(MediaQuery.sizeOf(context).width);
                      final extent = width >= 520 ? 236.0 : 220.0;

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                        cacheExtent: 480,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisExtent: extent,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return _ProductCard(
                            product: product,
                            quantity: quantityOf?.call(product) ?? 0,
                            favorite: favoriteIds.contains(product.productId),
                            onTap: () => onProductTap(product),
                            onToggleFavorite: onToggleFavorite == null
                                ? null
                                : () => onToggleFavorite!(product),
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
              color: PosUi.deskCard,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: PosUi.deskLine),
            ),
            child: Icon(Icons.inventory_2_outlined, size: 28, color: PosUi.deskMuted),
          ),
          const SizedBox(height: 12),
          Text('Aucun produit', style: PosUi.cardTitle(color: PosUi.deskText)),
          const SizedBox(height: 4),
          Text('Modifiez la recherche ou la catégorie.', style: PosUi.caption(color: PosUi.deskMuted)),
        ],
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    this.quantity = 0,
    this.favorite = false,
    this.onToggleFavorite,
  });

  final PosProduct product;
  final VoidCallback onTap;
  final int quantity;
  final bool favorite;
  final VoidCallback? onToggleFavorite;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final available = product.isAvailable;
    final price = MoneyFormatter.format(product.price, currencyCode: AppConfig.currencyCode);
    final imageUrl = resolvePosImageUrl(product.primaryImageUrl);
    final category = product.categoryName?.trim();
    final onHand = product.quantityOnHand;
    final unit = (product.unit ?? '').trim();

    return AnimatedScale(
      scale: _pressed ? 0.975 : 1,
      duration: AppMotion.resolve(context, AppMotion.micro),
      curve: AppMotion.standard,
      child: Material(
        color: PosUi.deskCard,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: available ? widget.onTap : null,
          onLongPress: widget.onToggleFavorite,
          onTapDown: available ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(16),
            child: Ink(
            decoration: BoxDecoration(
              color: PosUi.deskCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.quantity > 0
                    ? PosUi.deskAccent
                    : (!available ? AppColors.danger.withValues(alpha: 0.45) : PosUi.deskLine),
                width: widget.quantity > 0 ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 112,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _ProductPhoto(url: imageUrl, available: available),
                        if (widget.favorite)
                          const Positioned(
                            left: 8,
                            top: 8,
                            child: Icon(Icons.star_rounded, size: 16, color: PosUi.deskAccent),
                          ),
                        if (widget.quantity > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: _QtyBadge(quantity: widget.quantity),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PosUi.cardTitle(
                            color: available ? PosUi.deskText : PosUi.deskMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                price,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PosUi.money(
                                  size: 14,
                                  weight: FontWeight.w800,
                                  color: available ? PosUi.deskAccent : PosUi.deskMuted,
                                ),
                              ),
                            ),
                            if (unit.isNotEmpty)
                              Text('/$unit', style: PosUi.caption(color: PosUi.deskMuted)),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                (category != null && category.isNotEmpty) ? category : product.sku,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PosUi.caption(color: PosUi.deskMuted),
                              ),
                            ),
                            if (onHand != null)
                              Text(
                                '$onHand available',
                                style: AppTypography.plex(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: PosUi.deskStock,
                                ),
                              ),
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

class _QtyBadge extends StatelessWidget {
  const _QtyBadge({required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: PosUi.deskAccent,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$quantity',
        style: AppTypography.plex(fontSize: 12, fontWeight: FontWeight.w800, color: PosUi.deskInk),
      ),
    );
  }
}

class _ProductPhoto extends StatelessWidget {
  const _ProductPhoto({
    required this.url,
    required this.available,
  });

  final String? url;
  final bool available;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PosUi.deskPhoto,
      child: url == null
          ? _fallback()
          : Image.network(
              url!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _fallback(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const AppSkeleton(
                  height: 108,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                );
              },
            ),
    );
  }

  Widget _fallback() {
    return Center(
      child: Icon(
        Icons.landscape_outlined,
        size: 42,
        color: available
            ? (PosUi.isDarkDesk ? const Color(0xFFB7C3D1) : const Color(0xFF8A97A6))
            : PosUi.deskMuted,
      ),
    );
  }
}
