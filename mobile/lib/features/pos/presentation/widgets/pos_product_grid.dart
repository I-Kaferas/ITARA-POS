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
import 'package:pos_mobile/core/i18n/tr.dart';

const double _cardBodyHeight = 98;
const BorderRadius _cardRadius = BorderRadius.all(Radius.circular(18));
const BorderRadius _photoRadius = BorderRadius.all(Radius.circular(13));

double _cardExtent(double width) => width >= 520 ? 248 : 232;

class PosCatalogSkeleton extends StatelessWidget {
  const PosCatalogSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PosUi.deskNight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = AndroidLayout.productColumns(constraints.maxWidth);
          final extent = _cardExtent(constraints.maxWidth);
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
        borderRadius: _cardRadius,
        border: Border.all(color: PosUi.deskLine),
      ),
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: AppSkeleton(height: double.infinity, borderRadius: _photoRadius)),
            SizedBox(
              height: _cardBodyHeight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(6, 10, 4, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton(width: 130, height: 14),
                    SizedBox(height: 6),
                    AppSkeleton(width: 70, height: 10),
                    Spacer(),
                    Row(
                      children: [
                        AppSkeleton(width: 84, height: 18),
                        Spacer(),
                        AppSkeleton(
                          width: 34,
                          height: 32,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
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
                      final crossAxisCount =
                          AndroidLayout.productColumns(constraints.maxWidth);
                      final extent = _cardExtent(constraints.maxWidth);

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
          Text(tr('Aucun produit'), style: PosUi.cardTitle(color: PosUi.deskText)),
          const SizedBox(height: 4),
          Text(tr('Modifiez la recherche ou la catégorie.'), style: PosUi.caption(color: PosUi.deskMuted)),
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
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final available = product.isAvailable;
    final price = MoneyFormatter.format(product.price, currencyCode: AppConfig.currencyCode);
    final imageUrl = resolvePosImageUrl(product.primaryImageUrl);
    final category = product.categoryName?.trim();
    final onHand = product.quantityOnHand;
    final remaining = onHand == null ? null : onHand - widget.quantity;
    final unit = (product.unit ?? '').trim();
    final stockColor = remaining == null
        ? PosUi.deskStock
        : remaining <= 0
            ? AppColors.danger
            : (product.lowStockThreshold != null &&
                    remaining <= product.lowStockThreshold!)
                ? AppColors.warning
                : PosUi.deskStock;

    final sku = product.sku.trim();
    final inCart = widget.quantity > 0;
    final motion = AppMotion.resolve(context, AppMotion.micro);
    final borderColor = inCart
        ? PosUi.deskAccent
        : !available
            ? AppColors.danger.withValues(alpha: 0.4)
            : _hovered
                ? PosUi.deskAccent.withValues(alpha: 0.5)
                : PosUi.deskLine;
    final shadow = inCart
        ? BoxShadow(
            color: PosUi.deskAccent.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 6),
          )
        : BoxShadow(
            color: Colors.black.withValues(
              alpha: PosUi.isDarkDesk ? 0.28 : (_hovered ? 0.10 : 0.05),
            ),
            blurRadius: _hovered ? 18 : 10,
            offset: Offset(0, _hovered ? 6 : 3),
          );

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: motion,
      curve: AppMotion.standard,
      child: AnimatedContainer(
        duration: motion,
        curve: AppMotion.standard,
        decoration: BoxDecoration(
          color: PosUi.deskCard,
          borderRadius: _cardRadius,
          border: Border.all(color: borderColor, width: inCart ? 2 : 1),
          boxShadow: [shadow],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: available ? widget.onTap : null,
            onLongPress: widget.onToggleFavorite,
            onHover: (value) => setState(() => _hovered = value),
            onTapDown: available ? (_) => setState(() => _pressed = true) : null,
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            borderRadius: _cardRadius,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: _photoRadius,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _ProductPhoto(url: imageUrl, available: available),
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 46,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0x00000000), Color(0x2E000000)],
                                ),
                              ),
                            ),
                          ),
                          if (category != null && category.isNotEmpty)
                            Positioned(
                              left: 7,
                              top: 7,
                              right: 42,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _GlassChip(label: tr(category)),
                              ),
                            ),
                          if (widget.onToggleFavorite != null || widget.favorite)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: _FavoriteButton(
                                active: widget.favorite,
                                onTap: widget.onToggleFavorite,
                              ),
                            ),
                          if (available && remaining != null)
                            Positioned(
                              left: 7,
                              bottom: 7,
                              child: _StockPill(remaining: remaining, color: stockColor),
                            ),
                          if (available && product.hasOptions)
                            const Positioned(
                              right: 7,
                              bottom: 7,
                              child: _OptionsChip(),
                            ),
                          if (!available) const _UnavailableVeil(),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: _cardBodyHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 9, 2, 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(product.name),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.plex(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              height: 1.22,
                              color: available ? PosUi.deskText : PosUi.deskMuted,
                            ),
                          ),
                          if (sku.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              sku,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.plex(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                                color: PosUi.deskMuted,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: price,
                                        style: PosUi.money(
                                          size: 16,
                                          weight: FontWeight.w800,
                                          color: available ? PosUi.deskText : PosUi.deskMuted,
                                        ),
                                      ),
                                      if (unit.isNotEmpty)
                                        TextSpan(
                                          text: ' /${tr(unit)}',
                                          style: PosUi.caption(color: PosUi.deskMuted),
                                        ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _AddButton(
                                quantity: widget.quantity,
                                enabled: available,
                                duration: motion,
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

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PosUi.deskInk.withValues(alpha: 0.62),
        borderRadius: AppRadius.borderPill,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.plex(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.active, this.onTap});

  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            active ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 17,
            color: active ? PosUi.deskAccent : PosUi.deskInk.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  const _StockPill({required this.remaining, required this.color});

  final int remaining;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final out = remaining <= 0;
    final dotColor = color == PosUi.deskStock ? AppColors.success : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: out ? AppColors.danger : Colors.white.withValues(alpha: 0.94),
        borderRadius: AppRadius.borderPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!out) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            out ? tr('Rupture') : trf('{0} en stock', [remaining]),
            style: AppTypography.plex(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: out ? Colors.white : PosUi.deskInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionsChip extends StatelessWidget {
  const _OptionsChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: PosUi.deskInk.withValues(alpha: 0.62),
        borderRadius: AppRadius.borderPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.tune_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            tr('Options'),
            style: AppTypography.plex(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableVeil extends StatelessWidget {
  const _UnavailableVeil();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: PosUi.deskCard.withValues(alpha: 0.55),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: AppRadius.borderPill,
            ),
            child: Text(
              tr('Indisponible'),
              style: AppTypography.plex(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.quantity,
    required this.enabled,
    required this.duration,
  });

  final int quantity;
  final bool enabled;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final inCart = quantity > 0;
    final background = !enabled
        ? PosUi.deskLine
        : inCart
            ? PosUi.deskAccent
            : PosUi.deskAccent.withValues(alpha: 0.14);
    final foreground = !enabled
        ? PosUi.deskMuted
        : inCart
            ? PosUi.deskInk
            : PosUi.deskAccent;

    return AnimatedContainer(
      duration: duration,
      curve: AppMotion.standard,
      height: 32,
      constraints: const BoxConstraints(minWidth: 34),
      padding: EdgeInsets.symmetric(horizontal: inCart ? 9 : 0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: inCart
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_bag_rounded, size: 14, color: foreground),
                const SizedBox(width: 4),
                Text(
                  '$quantity',
                  style: AppTypography.plex(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
              ],
            )
          : Icon(
              enabled ? Icons.add_rounded : Icons.block_rounded,
              size: 18,
              color: foreground,
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
                return const AppSkeleton(height: double.infinity, borderRadius: _photoRadius);
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
