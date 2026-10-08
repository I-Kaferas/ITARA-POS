import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class PosSearchBar extends StatelessWidget {
  const PosSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onScanTap,
    this.focusNode,
    this.showDesktopHint = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onScanTap;
  final bool showDesktopHint;

  @override
  Widget build(BuildContext context) {
    final desk = MediaQuery.sizeOf(context).width >= 900;
    return Padding(
      padding: EdgeInsets.fromLTRB(desk ? 16 : 12, desk ? 14 : 12, desk ? 16 : 12, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.elevationSm,
        ),
        child: SizedBox(
          height: desk ? 52 : 46,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(Icons.search_rounded, color: AppColors.textMuted, size: desk ? 22 : 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: showDesktopHint || desk
                        ? 'Produit / SKU / code-barres  ·  F1'
                        : 'Produit / SKU / code-barres',
                    hintStyle: AppTypography.subtitle(color: AppColors.textMuted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: desk ? 14 : 12),
                  ),
                  style: AppTypography.body(weight: FontWeight.w500),
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  textInputAction: TextInputAction.search,
                ),
              ),
              if (desk)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    'Clavier · souris · scanner HID',
                    style: AppTypography.caption(color: AppColors.textMuted),
                  ),
                ),
              Text(
                'Scan',
                style: AppTypography.caption(color: AppColors.textMuted),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Scanner (HID / Enter)',
                onPressed: onScanTap,
                icon: Icon(Icons.qr_code_scanner_rounded, color: AppColors.brand600, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
