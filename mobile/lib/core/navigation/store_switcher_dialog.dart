import 'package:flutter/material.dart';

import '../config/terminal_config_repository.dart';
import '../config/terminal_stores.dart';
import '../i18n/app_locale.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../widgets/app_buttons.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

/// Loads the stores the signed-in account can use, lets the user pick one
/// and makes it the terminal's active store.
Future<void> openStoreSwitcher(
  BuildContext context, {
  List<TerminalStoreOption> stores = const [],
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var options = stores;
  if (options.isEmpty) {
    try {
      options = await loadTerminalStores();
    } catch (_) {
      options = const [];
    }
  }
  if (!context.mounted) return;
  if (options.isEmpty) {
    messenger?.showSnackBar(SnackBar(
      content: Text(tr('Impossible de charger les magasins. Vérifiez la connexion au serveur.')),
    ));
    return;
  }

  final picked = await showStoreSwitcherDialog(context, stores: options);
  if (picked == null) return;
  if (picked.id == TerminalConfigRepository.instance.config.storeId) return;
  await selectTerminalStore(picked);
  messenger?.showSnackBar(SnackBar(
    content: Text(trf('Magasin actif : {0}', [picked.name])),
  ));
}

/// Store picker chrome aligned with [LogoutProfileDialog].
Future<TerminalStoreOption?> showStoreSwitcherDialog(
  BuildContext context, {
  required List<TerminalStoreOption> stores,
}) {
  return showDialog<TerminalStoreOption>(
    context: context,
    barrierColor: AppColors.brand900.withValues(alpha: 0.55),
    builder: (context) => StoreSwitcherDialog(stores: stores),
  );
}

class StoreSwitcherDialog extends StatelessWidget {
  const StoreSwitcherDialog({super.key, required this.stores});

  final List<TerminalStoreOption> stores;

  @override
  Widget build(BuildContext context) {
    final currentId = TerminalConfigRepository.instance.config.storeId;
    final current = stores.where((store) => store.id == currentId).firstOrNull;
    final brand = TerminalConfigRepository.instance.config.brandName.trim();
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: size.height * 0.86),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.borderXl,
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.elevationMd,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.borderXl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
                  decoration: const BoxDecoration(color: AppColors.brand600),
                  child: Column(
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent,
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          size: 40,
                          color: AppColors.brand900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        tr('Magasins'),
                        textAlign: TextAlign.center,
                        style: AppTypography.text(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (brand.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          tr(brand),
                          textAlign: TextAlign.center,
                          style: AppTypography.text(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (current != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: AppRadius.borderPill,
                          ),
                          child: Text(
                            tr(current.name),
                            style: AppTypography.text(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                    itemCount: stores.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final store = stores[index];
                      final selected = store.id == currentId;
                      return Material(
                        color: selected
                            ? AppColors.brand600.withValues(alpha: 0.08)
                            : AppColors.fieldFill,
                        borderRadius: AppRadius.borderLg,
                        child: InkWell(
                          borderRadius: AppRadius.borderLg,
                          onTap: () => Navigator.pop(context, store),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.borderLg,
                              border: Border.all(
                                color: selected ? AppColors.brand600 : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                      ? Icons.check_circle_rounded
                                      : Icons.storefront_outlined,
                                  size: 22,
                                  color: selected
                                      ? AppColors.brand700
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tr(store.name),
                                        style: AppTypography.text(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (store.code.trim().isNotEmpty)
                                        Text(
                                          tr(store.code),
                                          style: AppTypography.text(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success,
                                      borderRadius: AppRadius.borderPill,
                                    ),
                                    child: Text(
                                      tr('Actuel'),
                                      style: AppTypography.text(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (stores.length == 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
                    child: Text(
                      tr('Votre compte n’a accès qu’à ce magasin.'),
                      textAlign: TextAlign.center,
                      style: AppTypography.text(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                  child: SizedBox(
                    width: double.infinity,
                    child: AppButton.secondary(
                      label: AppCopy.get('cancel'),
                      expanded: true,
                      onPressed: () => Navigator.pop(context),
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
