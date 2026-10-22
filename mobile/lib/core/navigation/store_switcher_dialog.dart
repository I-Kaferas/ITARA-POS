import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/shifts/data/local_shifts_store.dart';
import '../config/terminal_config_repository.dart';
import '../config/terminal_stores.dart';
import '../i18n/app_locale.dart';
import '../layout/android_form_factor.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_dialogs.dart';
import 'app_routes.dart';
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

  // Shifts are per cashier + store: rebind or clear the active session.
  final open = await LocalShiftsStore.instance.syncTerminalShiftForStore(picked.id);
  if (!context.mounted) return;

  messenger?.showSnackBar(SnackBar(
    content: Text(trf('Magasin actif : {0}', [picked.name])),
  ));

  final config = TerminalConfigRepository.instance.config;
  if (open != null || !config.canOpenShift) return;

  final openNow = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.brand900.withValues(alpha: 0.55),
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        tr('Open a shift'),
        style: AppTypography.text(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      ),
      content: Text(
        trf(
          'No open shift for {0}. Open a shift for this store to keep selling.',
          [picked.name],
        ),
        style: AppTypography.text(fontSize: 14, height: 1.35, color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(tr('Later')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.brand600),
          child: Text(tr('Open shift')),
        ),
      ],
    ),
  );

  if (openNow == true && context.mounted) {
    context.go(AppRoutes.shifts);
  }
}

/// Phone → bottom sheet. Tablet / desk → sidebar panel.
Future<TerminalStoreOption?> showStoreSwitcherDialog(
  BuildContext context, {
  required List<TerminalStoreOption> stores,
}) {
  final desk = !AndroidLayout.of(context).isPhone;
  if (desk) {
    return _showStoreSwitcherSidebar(context, stores: stores);
  }
  return showAppSheet<TerminalStoreOption>(
    context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => StoreSwitcherDialog(stores: stores),
  );
}

Future<TerminalStoreOption?> _showStoreSwitcherSidebar(
  BuildContext context, {
  required List<TerminalStoreOption> stores,
}) {
  return showGeneralDialog<TerminalStoreOption>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: AppColors.brand900.withValues(alpha: 0.45),
    transitionDuration: AppMotion.resolve(context, AppMotion.modal),
    pageBuilder: (context, animation, secondary) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 380,
            height: double.infinity,
            child: StoreSwitcherDialog(stores: stores, asSidebar: true),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondary, child) {
      if (AppMotion.reduceMotion(context)) return child;
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.standard);
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
        child: child,
      );
    },
  );
}

class StoreSwitcherDialog extends StatelessWidget {
  const StoreSwitcherDialog({
    super.key,
    required this.stores,
    this.asSidebar = false,
  });

  final List<TerminalStoreOption> stores;
  final bool asSidebar;

  @override
  Widget build(BuildContext context) {
    final currentId = TerminalConfigRepository.instance.config.storeId;
    final current = stores.where((store) => store.id == currentId).firstOrNull;
    final brand = TerminalConfigRepository.instance.config.brandName.trim();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final maxHeight = asSidebar ? double.infinity : MediaQuery.sizeOf(context).height * 0.86;

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: asSidebar
            ? const BorderRadius.horizontal(left: Radius.circular(18))
            : null,
        border: asSidebar
            ? Border(left: BorderSide(color: AppColors.border))
            : null,
        boxShadow: asSidebar ? AppColors.elevationMd : null,
      ),
      child: ClipRRect(
        borderRadius: asSidebar
            ? const BorderRadius.horizontal(left: Radius.circular(18))
            : BorderRadius.zero,
        child: Column(
          mainAxisSize: asSidebar ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, asSidebar ? 20 : 10, 20, 16),
              color: AppColors.brand600,
              child: Column(
                children: [
                  if (!asSidebar) ...[
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (asSidebar)
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: AppCopy.get('cancel'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ),
                  Container(
                    width: asSidebar ? 64 : 72,
                    height: asSidebar ? 64 : 72,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      size: asSidebar ? 30 : 34,
                      color: AppColors.brand900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('Changer de magasin'),
                    textAlign: TextAlign.center,
                    style: AppTypography.text(
                      color: Colors.white,
                      fontSize: asSidebar ? 18 : 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (brand.isNotEmpty) ...[
                    const SizedBox(height: 6),
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
                shrinkWrap: !asSidebar,
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
              padding: EdgeInsets.fromLTRB(18, 8, 18, 12 + (asSidebar ? safeBottom : safeBottom)),
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
    );

    if (asSidebar) {
      return SafeArea(
        left: false,
        child: panel,
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: panel,
        ),
      ),
    );
  }
}
