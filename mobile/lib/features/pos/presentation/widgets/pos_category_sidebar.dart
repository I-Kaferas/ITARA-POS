import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../domain/pos_models.dart';
import 'pos_ui.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Category pills matching the web POS: "Name (count)", selected in solid blue.
class PosCategorySidebar extends StatelessWidget {
  const PosCategorySidebar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    this.counts = const {},
    this.totalCount = 0,
  });

  final List<PosCategory> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final Map<String, int> counts;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final dark = PosUi.isDarkDesk;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        children: [
          _CategoryPill(
            label: '${tr('Tous')} ($totalCount)',
            selected: selectedCategoryId == null,
            dark: dark,
            onTap: () => onCategorySelected(null),
          ),
          for (final category in categories)
            _CategoryPill(
              label: '${tr(category.name)} (${counts[category.id] ?? 0})',
              selected: selectedCategoryId == category.id,
              dark: dark,
              onTap: () => onCategorySelected(category.id),
            ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  static const _selected = Color(0xFF2F6BFF);
  static const _idle = Color(0xFFE7EDF4);
  static const _idleText = Color(0xFF3C4A5C);

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? _selected
        : (dark ? Colors.white.withValues(alpha: 0.08) : _idle);
    final foreground = selected
        ? Colors.white
        : (dark ? const Color(0xFFCBD5E1) : _idleText);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              maxLines: 1,
              style: AppTypography.plex(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: foreground,
                height: 1.2,
                letterSpacing: -0.15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
