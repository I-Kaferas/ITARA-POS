import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'pos_ui.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Phone catalog chrome: search, grid and list. Categories are the shared pills.
class PosPhoneCatalogBar extends StatelessWidget {
  const PosPhoneCatalogBar({
    super.key,
    required this.searchOpen,
    required this.onToggleSearch,
    required this.listMode,
    required this.onListMode,
  });

  final bool searchOpen;
  final VoidCallback onToggleSearch;
  final bool listMode;
  final ValueChanged<bool> onListMode;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PosUi.deskCard,
        border: Border(bottom: BorderSide(color: PosUi.deskLine)),
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
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
