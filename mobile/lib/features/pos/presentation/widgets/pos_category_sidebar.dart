import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/pos_models.dart';
import 'pos_ui.dart';

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
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(right: BorderSide(color: Color(0xFFE7EDF3))),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
            child: Text('CATÉGORIES', style: PosUi.sectionLabel(color: const Color(0xFF94A3B8))),
          ),
          _CategoryTile(
            label: 'Tous',
            count: totalCount,
            depth: 0,
            selected: selectedCategoryId == null,
            onTap: () => onCategorySelected(null),
          ),
          for (final category in categories)
            _CategoryTile(
              label: category.name,
              count: counts[category.id] ?? 0,
              depth: category.depth,
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
    required this.depth,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final int depth;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.brand600 : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        elevation: selected ? 2 : 0,
        shadowColor: AppColors.brand600.withValues(alpha: 0.28),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          hoverColor: selected ? null : Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: PosUi.touchMin),
            child: Padding(
              padding: EdgeInsets.fromLTRB(10 + depth * 11.0, 10, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppColors.textPrimary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.textSecondary,
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
