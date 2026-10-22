import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import 'pos_ui.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

class PosSearchBar extends StatelessWidget {
  const PosSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onScanTap,
    this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    final desk = PosUi.isDesk(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(desk ? 16 : 12, 12, 8, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PosUi.deskField,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: PosUi.deskLine),
        ),
        child: SizedBox(
          height: 46,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(Icons.search_rounded, color: PosUi.deskMuted, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: tr('Search products...'),
                    hintStyle: AppTypography.subtitle(color: PosUi.deskMuted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: AppTypography.body(weight: FontWeight.w500, color: PosUi.deskText),
                  cursorColor: PosUi.deskAccent,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  textInputAction: TextInputAction.search,
                ),
              ),
              IconButton(
                tooltip: tr('Scanner (HID / Enter)'),
                onPressed: onScanTap,
                icon: const Icon(Icons.qr_code_scanner_rounded, color: PosUi.deskAccent, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
