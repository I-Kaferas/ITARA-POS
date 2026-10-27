import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/pos_models.dart';
import '../../services/pos_favorites_store.dart';
import 'pos_ui.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Phone catalog chrome: category menu, search, grid and list.
class PosPhoneCatalogBar extends StatelessWidget {
  const PosPhoneCatalogBar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    required this.searchOpen,
    required this.onToggleSearch,
    required this.listMode,
    required this.onListMode,
  });

  final List<PosCategory> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final bool searchOpen;
  final VoidCallback onToggleSearch;
  final bool listMode;
  final ValueChanged<bool> onListMode;

  @override
  Widget build(BuildContext context) {
    final label = _label();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PosUi.deskCard,
        border: Border(bottom: BorderSide(color: PosUi.deskLine)),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Expanded(
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == '__all__') {
                    onCategorySelected(null);
                  } else {
                    onCategorySelected(value);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: '__all__', child: Text(tr('Tous les produits'))),
                  PopupMenuItem(
                    value: PosFavoritesStore.favoritesCategoryId,
                    child: Text(tr('Favoris')),
                  ),
                  for (final category in categories)
                    PopupMenuItem(value: category.id, child: Text(tr(category.name))),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.plex(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
            _ToolButton(
              icon: Icons.search_rounded,
              selected: searchOpen,
              tooltip: tr('Rechercher'),
              onTap: onToggleSearch,
            ),
            _ToolButton(
              icon: Icons.grid_view_rounded,
              selected: !listMode,
              tooltip: tr('Grille'),
              onTap: () => onListMode(false),
            ),
            _ToolButton(
              icon: Icons.view_list_rounded,
              selected: listMode,
              tooltip: tr('Liste'),
              onTap: () => onListMode(true),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  String _label() {
    if (selectedCategoryId == null) return tr('Tous les produits');
    if (selectedCategoryId == PosFavoritesStore.favoritesCategoryId) return tr('Favoris');
    for (final category in categories) {
      if (category.id == selectedCategoryId) return tr(category.name);
    }
    return tr('Tous les produits');
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 22,
          color: selected ? AppColors.brand700 : AppColors.textSecondary,
        ),
      ),
    );
  }
}
