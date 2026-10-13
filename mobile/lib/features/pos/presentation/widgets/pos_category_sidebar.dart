import 'package:flutter/material.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/pos_models.dart';
import '../../services/pos_favorites_store.dart';
import 'pos_ui.dart';

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
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 6),
        children: [
          _CategoryChip(
            label: 'All',
            count: totalCount,
            selected: selectedCategoryId == null,
            onTap: () => onCategorySelected(null),
          ),
          _CategoryChip(
            label: 'Favorites',
            count: favoritesCount,
            selected: selectedCategoryId == PosFavoritesStore.favoritesCategoryId,
            onTap: () => onCategorySelected(PosFavoritesStore.favoritesCategoryId),
            icon: Icons.star_rounded,
          ),
          for (final category in categories)
            _CategoryChip(
              label: category.name,
              count: counts[category.id] ?? 0,
              selected: selectedCategoryId == category.id,
              onTap: () => onCategorySelected(category.id),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? PosUi.deskInk : PosUi.deskText;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: AppMotion.resolve(context, AppMotion.micro),
            curve: AppMotion.standard,
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? PosUi.deskAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? PosUi.deskAccent : PosUi.deskLine,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  '$label ($count)',
                  style: AppTypography.plex(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fg,
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
