import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/pos_models.dart';
import '../../services/pos_favorites_store.dart';
import 'pos_ui.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Compact category tiles, matching the web POS: icon, name, count.
class PosCategorySidebar extends StatelessWidget {
  const PosCategorySidebar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    this.counts = const {},
    this.totalCount = 0,
    this.favoritesCount = 0,
  });

  final List<PosCategory> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final Map<String, int> counts;
  final int totalCount;
  final int favoritesCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        children: [
          _CategoryTile(
            label: tr('All'),
            count: totalCount,
            icon: Icons.grid_view_rounded,
            selected: selectedCategoryId == null,
            onTap: () => onCategorySelected(null),
          ),
          _CategoryTile(
            label: tr('Favorites'),
            count: favoritesCount,
            icon: Icons.star_rounded,
            selected: selectedCategoryId == PosFavoritesStore.favoritesCategoryId,
            onTap: () => onCategorySelected(PosFavoritesStore.favoritesCategoryId),
          ),
          for (final category in categories)
            _CategoryTile(
              label: category.name,
              count: counts[category.id] ?? 0,
              icon: Icons.category_outlined,
              selected: selectedCategoryId == category.id,
              onTap: () => onCategorySelected(category.id),
            ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : PosUi.deskText;
    final muted = selected ? Colors.white.withValues(alpha: 0.78) : PosUi.deskMuted;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: AppMotion.resolve(context, AppMotion.micro),
            curve: AppMotion.standard,
            width: 68,
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 5),
            decoration: BoxDecoration(
              color: selected ? AppColors.brand600 : PosUi.deskCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? AppColors.brand600 : PosUi.deskLine),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.plex(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                Text(
                  '$count',
                  style: AppTypography.plex(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: muted,
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
