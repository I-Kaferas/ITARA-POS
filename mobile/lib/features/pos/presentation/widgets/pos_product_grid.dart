import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/config/terminal_config_repository.dart';
import '../../../../core/theme/app_colors.dart';
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
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const _EmptyProducts()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = width >= 520 ? 3 : 2;
                      final extent = width >= 520 ? 210.0 : 196.0;

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisExtent: extent,
                          crossAxisSpacing: 11,
                          mainAxisSpacing: 11,
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
              borderRadius: BorderRadius.circular(18),
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
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: available ? const Color(0xFFE2E8F0) : AppColors.danger.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 100,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
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
                                    ? const Color(0xFFB91C1C)
                                    : const Color(0xFF1C2830).withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                stock,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
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
                    padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: available ? const Color(0xFF1C2830) : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(product.sku, style: PosUi.caption(color: const Color(0xFF94A3B8))),
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
                                  color: available ? const Color(0xFFE39B2B) : AppColors.danger,
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
      color: const Color(0xFFF3F6F8),
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
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE7EEF3),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          initial,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: available ? AppColors.brand600 : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
