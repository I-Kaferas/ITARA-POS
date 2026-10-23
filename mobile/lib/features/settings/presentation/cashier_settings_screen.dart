import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/terminal_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../core/config/terminal_stores.dart';
import '../../../core/navigation/store_switcher_dialog.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/layout/android_form_factor.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../sync/offline_store.dart';
import '../../../sync/sync_engine.dart';
import '../../../sync/sync_models.dart';
import '../../auth/data/pin_auth_service.dart';
import '../../auth/presentation/logout_profile_dialog.dart';
import '../../pos/presentation/customer_display_launcher.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import '../../printers/presentation/printer_routing_screen.dart';
import '../../printers/services/printer_manager.dart';
import '../../receipt/domain/printer_models.dart';
import '../domain/cashier_preferences.dart';
import '../domain/screen_lock_controller.dart';
import 'close_period_dialog.dart';
import 'printer_setup_panel.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

Color get _brand => AppColors.accent;
Color get _onBrand => AppColors.brand900;

/// Cashier settings, opened from the top overflow menu and shown right
/// after an administrator signs in, before the technical configuration.
class CashierSettingsScreen extends StatelessWidget {
  const CashierSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        TerminalConfigRepository.instance,
        LocaleController.instance,
        CashierPreferences.instance,
      ]),
      builder: (context, _) {
        return BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, _) {
            final config = TerminalConfigRepository.instance.config;
            final prefs = CashierPreferences.instance;
            final theme = Theme.of(context);
            return Theme(
              data: theme.copyWith(
                colorScheme: theme.colorScheme.copyWith(
                  primary: AppColors.accent,
                  onPrimary: AppColors.brand900,
                  secondary: AppColors.accent,
                  onSecondary: AppColors.brand900,
                ),
                switchTheme: SwitchThemeData(
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return AppColors.textMuted.withValues(alpha: 0.45);
                    }
                    if (states.contains(WidgetState.selected)) return AppColors.brand900;
                    return AppColors.textMuted;
                  }),
                  trackColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return AppColors.accent;
                    return PosUi.deskField;
                  }),
                  trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return AppColors.accent;
                    return AppColors.border;
                  }),
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.brand900,
                  ),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PosUi.deskAccent,
                    side: const BorderSide(color: PosUi.deskAccent),
                  ),
                ),
              ),
              child: ColoredBox(
              color: PosUi.deskNight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= AndroidLayout.contentWide;
                  final page = _Page(
                    config: config,
                    prefs: prefs,
                    wide: wide,
                  );
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 28 : 16,
                      16,
                      wide ? 28 : 16,
                      28,
                    ),
                    child: page,
                  );
                },
              ),
            ),
            );
          },
        );
      },
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.config,
    required this.prefs,
    required this.wide,
  });

  final TerminalConfig config;
  final CashierPreferences prefs;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[
      _SectionLabel('Langue'),
      _LanguageCard(selected: LocaleController.instance.code),
      _SectionLabel('Visibilité du menu'),
      if (config.isMaster)
        _MenuVisibilityCard(prefs: prefs)
      else
        _RoleNotice(config: config),
      _SectionLabel('Impressions'),
      _PrintCard(config: config, prefs: prefs),
    ];

    final right = <Widget>[
      _SectionLabel('Magasin'),
      _StoreCard(storeId: config.storeId),
      _SectionLabel('Hub'),
      _HubCard(onTap: () => context.go(AppRoutes.hub)),
      _SectionLabel('Synchronisation'),
      _DataSyncCard(config: config),
      _SectionLabel('Général'),
      _GeneralCard(config: config, prefs: prefs),
      _SectionLabel('Notifications'),
      _NotificationsCard(prefs: prefs),
      _SectionLabel('Verrouillage'),
      _AutoLockCard(minutes: prefs.autoLockMinutes),
      _SectionLabel('À propos'),
      const _AboutCard(),
      _LogoutCard(
        onTap: () async {
          final ok = await showLogoutProfileDialog(context);
          if (ok) await PinAuthService.signOut();
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!AndroidLayout.of(context).isDesk) ...[
          const _TopActions(),
          const SizedBox(height: 16),
        ],
        _ProfileCard(config: config),
        const SizedBox(height: 16),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _stack(left)),
              const SizedBox(width: 22),
              Expanded(child: _stack(right)),
            ],
          )
        else
          _stack([...left, ...right]),
      ],
    );
  }

  Widget _stack(List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in children) ...[child, const SizedBox(height: 16)],
      ],
    );
  }
}

void _openConfig(BuildContext context, int section) {
  context.go('${AppRoutes.configuration}?section=$section');
}

class _TopActions extends StatelessWidget {
  const _TopActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        _PillButton(
          icon: Icons.grid_view_rounded,
          label: tr('Fonctions'),
          onTap: () {
            final ready = TerminalConfigRepository.instance.isCompanyConfigured;
            if (!ready) {
              _openConfig(context, 0);
              return;
            }
            context.go(AppRoutes.menu);
          },
        ),
        const SizedBox(width: 8),
        _PillButton(
          icon: Icons.logout_rounded,
          label: tr('Déconnexion'),
          danger: true,
          onTap: () async {
            final ok = await showLogoutProfileDialog(context);
            if (ok) await PinAuthService.signOut();
          },
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : _brand;
    return Material(
      color: danger ? AppColors.dangerBg : _brand.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                tr(label),
                style: AppTypography.text(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.config});

  final TerminalConfig config;

  @override
  Widget build(BuildContext context) {
    final name = config.cashierName.trim().isEmpty
        ? 'Administrateur'
        : config.cashierName.trim();
    final email = config.cashierEmail.trim();
    final company = config.brandName.trim().isNotEmpty
        ? config.brandName.trim()
        : (config.companyProfile.trim().isNotEmpty
              ? config.companyProfile.trim()
              : 'ITARA');
    final role = config.isAdmin ? 'Administrateur' : 'Caissier';

    final detail = [
      role,
      if (email.isNotEmpty) email,
      company,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        color: PosUi.deskCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PosUi.deskAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              tr(_initials(name)),
              style: AppTypography.text(
                color: PosUi.deskInk,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.text(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: PosUi.deskText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr(detail),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.text(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PosUi.deskMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.selected});

  final String selected;

  static const _rows = [
    ('fr', 'FR', 'Français', 'French'),
    ('en', 'GB', 'English', 'English'),
    ('sw', 'TZ', 'Kiswahili', 'Swahili'),
  ];

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < _rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.border),
            _LanguageRow(
              badge: _rows[i].$2,
              title: _rows[i].$3,
              subtitle: _rows[i].$4,
              selected: selected == _rows[i].$1,
              onTap: () => LocaleController.instance.apply(_rows[i].$1),
            ),
          ],
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String badge;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? _brand.withValues(alpha: 0.16)
                      : AppColors.fieldFill,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  tr(badge),
                  style: AppTypography.text(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? _brand : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(title),
                      style: AppTypography.text(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selected ? _brand : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      tr(subtitle),
                      style: AppTypography.text(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: _brand, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleNotice extends StatelessWidget {
  const _RoleNotice({required this.config});

  final TerminalConfig config;

  @override
  Widget build(BuildContext context) {
    final roleReady = config.isConfigured;
    final companyReady = config.isCompanyConfigured;
    final ready = roleReady && companyReady;
    final title = !roleReady
        ? 'Rôle de l’appareil non configuré'
        : !companyReady
            ? 'Entreprise non configurée'
            : 'Rôle : ${config.posRole.label}';
    final subtitle = !roleReady
        ? 'Ouvrez le Hub et définissez cet appareil comme Master ou Esclave avant de modifier ces options.'
        : !companyReady
            ? 'Liez l’entreprise (tenant / marque) via le Hub pour activer Overview, Point of Sale, Orders et Shifts.'
            : 'Le menu caissier suit ce rôle. Ouvrez le Hub pour le modifier.';
    return _Card(
      onTap: () => context.go(AppRoutes.hub),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(
            icon: ready
                ? Icons.verified_outlined
                : Icons.settings_suggest_outlined,
            color: ready ? AppColors.success : AppColors.warning,
            background: ready ? AppColors.successBg : AppColors.warningBg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(title),
                  style: AppTypography.text(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(subtitle),
                  style: AppTypography.text(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrintCard extends StatelessWidget {
  const _PrintCard({required this.config, required this.prefs});

  final TerminalConfig config;
  final CashierPreferences prefs;

  @override
  Widget build(BuildContext context) {
    final paper = _paperKey(config.printerFormat);
    final mode = _connectionKey(config.printerConnection);
    return Column(
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTitle(
                icon: Icons.print_outlined,
                title: tr('Format du ticket'),
                subtitle: tr('Choisissez la taille de votre imprimante de reçu'),
              ),
              const SizedBox(height: 16),
              _ChoiceBar(
                options: const [
                  _Choice('thermal_58', '58 mm', null),
                  _Choice('thermal_80', '80 mm', null),
                  _Choice('a4', 'A4', null),
                ],
                selected: paper,
                onSelected: (id) => _savePaper(id),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTitle(
                icon: Icons.format_size,
                title: tr('Taille du texte'),
                subtitle:
                    tr('Reçus, factures et bons de cuisine. Le niveau 1 est le plus petit.'),
              ),
              const SizedBox(height: 16),
              _ChoiceBar(
                options: [
                  for (var i = 0; i < CashierPreferences.textLabels.length; i++)
                    _Choice('${i + 1}', CashierPreferences.textLabels[i], null),
                ],
                selected: '${prefs.printTextLevel}',
                onSelected: (id) => prefs.setPrintTextLevel(int.parse(id)),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: PosUi.deskField,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PosUi.deskLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(prefs.printTextCaption),
                      style: AppTypography.text(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('Aperçu ticket'),
                      style: AppTypography.text(
                        fontSize: 11 * prefs.printTextScale,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'TOTAL  36 000 FBu',
                      style: AppTypography.text(
                        fontSize: 14 * prefs.printTextScale,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTitle(
                icon: Icons.print_outlined,
                title: tr('Mode d’impression'),
                subtitle: tr('Choisissez comment cet appareil imprime les reçus'),
              ),
              const SizedBox(height: 16),
              _ChoiceBar(
                options: const [
                  _Choice('system', 'Cet appareil', null),
                  _Choice('lan', 'Réseau', null),
                  _Choice('bluetooth', 'Bluetooth', null),
                ],
                selected: mode,
                onSelected: (id) => _saveConnection(id),
              ),
              const SizedBox(height: 16),
              PrinterSetupPanel(config: config),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _savePaper(String format) async {
    final repo = TerminalConfigRepository.instance;
    final current = repo.config;
    final preset = PrinterModelPreset.byId(current.printerModel);
    final model = preset.format.value == format
        ? current.printerModel
        : switch (format) {
            'thermal_58' => 'generic_58',
            'a4' => 'a4',
            _ => 'generic_80',
          };
    await repo.save(
      current.copyWith(printerFormat: format, printerModel: model),
    );
    await _syncDefaultPrinter();
  }

  Future<void> _saveConnection(String mode) async {
    final repo = TerminalConfigRepository.instance;
    if (_connectionKey(repo.config.printerConnection) == mode) return;
    await repo.save(repo.config.copyWith(printerConnection: mode));
    await _syncDefaultPrinter();
  }

  Future<void> _syncDefaultPrinter() async {
    try {
      await PrinterManager.instance.syncDefaultFromConfig();
    } catch (_) {}
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _brand,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.hub_outlined,
              color: _onBrand,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Hub'),
                  style: AppTypography.text(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  tr('Gestion des appareils'),
                  style: AppTypography.text(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _StoreCard extends StatefulWidget {
  const _StoreCard({required this.storeId});

  final String storeId;

  @override
  State<_StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends State<_StoreCard> {
  List<TerminalStoreOption> _stores = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stores = await loadTerminalStores();
      if (!mounted) return;
      setState(() {
        _stores = stores;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _change() async {
    await openStoreSwitcher(context, stores: _stores);
    if (mounted && _stores.isEmpty) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final current = _stores.where((s) => s.id == widget.storeId).firstOrNull;
    final name = current?.name ?? (_loading ? tr('Chargement…') : tr('Magasin'));
    final subtitle = _loading
        ? tr('Recherche des magasins du compte…')
        : _stores.isEmpty
            ? tr('Liste des magasins indisponible')
            : trf('{0} magasin(s) disponible(s) pour ce compte', [_stores.length]);

    return _Card(
      onTap: _change,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PosUi.deskAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: PosUi.deskInk,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.text(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.text(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _change,
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: Text(tr('Changer')),
          ),
        ],
      ),
    );
  }
}

const _syncBlue = AppColors.accent;

class _DataSyncCard extends StatefulWidget {
  const _DataSyncCard({required this.config});

  final TerminalConfig config;

  @override
  State<_DataSyncCard> createState() => _DataSyncCardState();
}

class _DataSyncCardState extends State<_DataSyncCard> {
  Timer? _tick;
  DateTime? _savedLastSync;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
    OfflineStore.instance.checkpoint('last_sync_at').then((value) {
      if (!mounted || value == null) return;
      setState(() => _savedLastSync = DateTime.tryParse(value));
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _run(String id, Future<SyncReport> Function() action) async {
    if (_busy != null) return;
    setState(() => _busy = id);
    try {
      final report = await action();
      if (!mounted) return;
      final text = report.message.isNotEmpty
          ? report.message
          : (report.ok ? 'Synchronisation terminée' : 'Échec de la synchronisation');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(text)),
          backgroundColor: report.ok ? null : AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _closePeriod() async {
    if (_busy != null) return;
    await showClosePeriodDialog(context, toMaster: widget.config.isSlave);
  }

  String _ago(DateTime? at) {
    if (at == null) return 'jamais';
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 60) return 'il y a ${diff.inSeconds.clamp(0, 59)} s';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    String two(int n) => n.toString().padLeft(2, '0');
    final local = at.toLocal();
    return 'le ${two(local.day)}/${two(local.month)} à ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.config.isCompanyConfigured) return _RoleNotice(config: widget.config);
    return ListenableBuilder(
      listenable: SyncEngine.instance,
      builder: (context, _) {
        final engine = SyncEngine.instance;
        final last = engine.lastSyncAt ?? _savedLastSync;
        final error = engine.lastError;
        final (statusIcon, statusColor) = error != null
            ? (Icons.cloud_off_rounded, AppColors.danger)
            : engine.pending > 0
                ? (Icons.cloud_upload_rounded, AppColors.warning)
                : (Icons.cloud_done_rounded, AppColors.success);
        final idle = _busy == null;
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _brand.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(statusIcon, size: 26, color: statusColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('État de la synchro'),
                          style: AppTypography.text(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          trf('Dernière synchro : {0}''{1}', [_ago(last), engine.pending > 0 ? ' · ${engine.pending} en attente' : '']),
                          style: AppTypography.text(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (error != null)
                          Text(
                            tr(error),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.text(fontSize: 12, color: AppColors.danger),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr('Détails'),
                    onPressed: () => context.go(AppRoutes.sync),
                    icon: Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SyncActionTile(
                        icon: Icons.cloud_upload_rounded,
                        color: _brand,
                        title: tr('Envoyer'),
                        subtitle: widget.config.isSlave
                            ? 'Pousser les changements locaux vers le Master'
                            : 'Pousser les changements locaux vers le cloud',
                        busy: _busy == 'upload',
                        onTap: idle ? () => _run('upload', engine.sendStock) : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SyncActionTile(
                        icon: Icons.sync_rounded,
                        color: _syncBlue,
                        title: tr('Synchro complète'),
                        subtitle: tr('Envoyer et télécharger toutes les données'),
                        busy: _busy == 'full',
                        onTap: idle ? () => _run('full', engine.syncNow) : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ClosePeriodTile(
                busy: _busy == 'close',
                onTap: idle ? _closePeriod : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SyncActionTile extends StatelessWidget {
  const _SyncActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 28,
                child: Center(
                  child: busy
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: color),
                        )
                      : Icon(icon, size: 26, color: color),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tr(title),
                textAlign: TextAlign.center,
                style: AppTypography.text(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(subtitle),
                textAlign: TextAlign.center,
                style: AppTypography.text(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClosePeriodTile extends StatelessWidget {
  const _ClosePeriodTile({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.danger.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: Center(
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.danger),
                        )
                      : const Icon(Icons.storefront_rounded, size: 24, color: AppColors.danger),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Clôturer la période'),
                      style: AppTypography.text(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('Envoyer, vérifier et nettoyer les mouvements locaux'),
                      style: AppTypography.text(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeneralCard extends StatelessWidget {
  const _GeneralCard({required this.config, required this.prefs});

  final TerminalConfig config;
  final CashierPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _NavRow(
            icon: Icons.print_outlined,
            title: tr('Imprimantes'),
            subtitle: tr('Reçus et cuisine (80 mm)'),
            onTap: () {
              if (config.isConfigured) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrinterRoutingScreen(),
                  ),
                );
                return;
              }
              _openConfig(context, 3);
            },
          ),
          Divider(height: 1, color: AppColors.border),
          _NavRow(
            icon: Icons.receipt_long_outlined,
            title: tr('Tickets'),
            subtitle: tr('Mise en page et contenu des reçus'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrinterRoutingScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, color: AppColors.border),
          _NavRow(
            icon: Icons.storefront_outlined,
            title: tr('Type de commerce'),
            subtitle: prefs.standardPos
                ? 'Commerce — caisse standard, sans les fonctions restaurant'
                : 'Restaurant — tables, cuisine et production',
            trailing: Switch(
              value: prefs.standardPos,
              onChanged: prefs.setStandardPos,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuVisibilityCard extends StatelessWidget {
  const _MenuVisibilityCard({required this.prefs});

  final CashierPreferences prefs;

  static const _menus = {
    'overview': ('Overview', Icons.space_dashboard_outlined),
    'pos': ('POS', Icons.point_of_sale_outlined),
    'orders': ('Orders', Icons.receipt_long_outlined),
    'kitchen': ('Kitchen', Icons.soup_kitchen_outlined),
    'tables': ('Tables', Icons.table_restaurant_outlined),
    'shifts': ('Shifts', Icons.schedule_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final atMinimum = prefs.visibleMenuCount <= CashierPreferences.minVisibleMenus;
    final rows = <Widget>[];
    for (final key in CashierPreferences.menuKeys) {
      final (label, icon) = _menus[key]!;
      final available = prefs.menuAvailable(key);
      final visible = prefs.menuVisible(key);
      final locked = visible && atMinimum;
      Widget toggle = Switch(
        value: visible,
        onChanged: !available || locked ? null : (value) => prefs.setMenuVisible(key, value),
      );
      if (locked) {
        toggle = Tooltip(
          message: trf('Au moins {0} menus doivent rester visibles', [CashierPreferences.minVisibleMenus]),
          child: toggle,
        );
      }
      if (rows.isNotEmpty) rows.add(Divider(height: 1, color: AppColors.border));
      rows.add(
        Opacity(
          opacity: available ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                _IconBadge(
                  icon: icon,
                  color: available ? _brand : AppColors.textMuted,
                  background: available
                      ? _brand.withValues(alpha: 0.12)
                      : AppColors.border.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(label),
                        style: AppTypography.text(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (!available)
                        Text(
                          tr('Masqué en mode commerce'),
                          style: AppTypography.text(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                toggle,
              ],
            ),
          ),
        ),
      );
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.visibility_outlined,
            title: tr('Menus visibles'),
            subtitle: tr('Choisissez les menus affichés dans la navigation'),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard({required this.prefs});

  final CashierPreferences prefs;

  static const _channels = <(String key, IconData icon, String label)>[
    ('orders', Icons.receipt_long_outlined, 'Orders'),
    ('stock', Icons.inventory_2_outlined, 'Stock Updates'),
    ('devices', Icons.devices_outlined, 'Device Connections'),
    ('call_ringtone', Icons.ring_volume_outlined, 'Call ringtone'),
    ('call_vibration', Icons.vibration, 'Call vibration'),
    ('sync', Icons.sync, 'Sync Events'),
    ('general', Icons.info_outline, 'General'),
  ];

  @override
  Widget build(BuildContext context) {
    final masterOn = prefs.notificationsEnabled;
    final rows = <Widget>[
      _NotificationMasterRow(
        enabled: masterOn,
        onChanged: prefs.setNotificationsEnabled,
      ),
    ];
    for (final (key, icon, label) in _channels) {
      rows.add(Divider(height: 1, color: AppColors.border));
      rows.add(
        _NotificationChannelRow(
          icon: icon,
          label: label,
          enabled: prefs.enabledNotificationChannels.contains(key),
          interactive: masterOn,
          onChanged: (value) => prefs.setNotificationChannel(key, value),
        ),
      );
    }

    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(children: rows),
    );
  }
}

class _NotificationMasterRow extends StatelessWidget {
  const _NotificationMasterRow({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _IconBadge(
            icon: Icons.notifications_outlined,
            color: _brand,
            background: _brand.withValues(alpha: 0.12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Enable Notifications'),
                  style: AppTypography.text(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  tr('Receive alerts for orders, stock & sync'),
                  style: AppTypography.text(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _NotificationChannelRow extends StatelessWidget {
  const _NotificationChannelRow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.interactive,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final bool interactive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: interactive ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _IconBadge(
              icon: icon,
              color: _brand,
              background: _brand.withValues(alpha: 0.12),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr(label),
                style: AppTypography.text(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Switch(
              value: enabled,
              onChanged: interactive ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoLockCard extends StatelessWidget {
  const _AutoLockCard({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.lock_outline,
            title: tr('Verrouillage automatique'),
            subtitle: tr('Verrouiller l’écran après une période d’inactivité'),
          ),
          const SizedBox(height: 16),
          _ChoiceBar(
            options: const [
              _Choice('0', 'Jamais', null),
              _Choice('1', '1 minute', null),
              _Choice('2', '2 minutes', null),
              _Choice('5', '5 minutes', null),
              _Choice('10', '10 minutes', null),
            ],
            selected: '$minutes',
            onSelected: (id) =>
                CashierPreferences.instance.setAutoLockMinutes(int.parse(id)),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  tr('Le PIN du caissier est demandé pour reprendre. Raccourci : Ctrl+L'),
                  style: AppTypography.text(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
              FilledButton.icon(
                onPressed: () => ScreenLockController.instance.lock(),
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: _onBrand,
                ),
                icon: const Icon(Icons.lock_outline, size: 18),
                label: Text(tr('Verrouiller maintenant')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _NavRow(
            icon: Icons.info_outline,
            title: tr('Version'),
            subtitle: AppConfig.appVersion,
          ),
          Divider(height: 1, color: AppColors.border),
          _NavRow(
            icon: Icons.help_outline,
            title: tr('Aide'),
            subtitle: tr('Assistance pour la caisse'),
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(tr('Aide')),
                  content: Text(
                    tr('Pour l’imprimante, le rôle Master ou Esclave et la connexion au magasin, '
                    'ouvrez le Hub. Le compte administrateur peut terminer la configuration du terminal.'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr('Fermer')),
                    ),
                  ],
                ),
              );
            },
          ),
          Divider(height: 1, color: AppColors.border),
          ValueListenableBuilder<bool>(
            valueListenable: CustomerDisplayLauncher.busy,
            builder: (context, busy, _) {
              return _NavRow(
                icon: Icons.monitor_outlined,
                title: tr('Écran client'),
                subtitle: tr('Activer, masquer et régler le second écran'),
                enabled: !busy,
                onTap: () => CustomerDisplayLauncher.open(context),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      onTap: onTap,
      child: Row(
        children: [
          const _IconBadge(
            icon: Icons.logout_rounded,
            color: AppColors.danger,
            background: Color(0x22C2413A),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Déconnexion'),
                  style: AppTypography.text(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
                Text(
                  tr('Quitter le compte de cette caisse'),
                  style: AppTypography.text(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.danger),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _IconBadge(
            icon: icon,
            color: _brand,
            background: _brand.withValues(alpha: 0.12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(title),
                  style: AppTypography.text(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  tr(subtitle),
                  style: AppTypography.text(
                    fontSize: 12.5,
                    height: 1.3,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
    if (onTap == null || !enabled) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconBadge(
          icon: icon,
          color: PosUi.deskInk,
          background: PosUi.deskAccent,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(title),
                style: AppTypography.text(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: PosUi.deskText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tr(subtitle),
                style: AppTypography.text(
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: PosUi.deskMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _Choice {
  const _Choice(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData? icon;
}

class _ChoiceBar extends StatelessWidget {
  const _ChoiceBar({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<_Choice> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = options.length > 3 || constraints.maxWidth < 360;
        final children = [
          for (final option in options)
            _ChoiceChip(
              option: option,
              selected: option.id == selected,
              onTap: () => onSelected(option.id),
            ),
        ];
        if (compact) {
          const gap = 8.0;
          const minCell = 96.0;
          final width = constraints.maxWidth;
          final columns = [options.length, 3, 2].firstWhere(
            (count) => count <= options.length && (width - gap * (count - 1)) / count >= minCell,
            orElse: () => 2,
          );
          final cell = (width - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final child in children) SizedBox(width: cell, child: child),
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _Choice option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? PosUi.deskInk : PosUi.deskText;
    return Material(
      color: selected ? PosUi.deskAccent : PosUi.deskField,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 72),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? PosUi.deskAccent : PosUi.deskLine),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (option.icon != null) ...[
                Icon(option.icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  tr(option.label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.text(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        children: [
          Icon(_iconFor(text), size: 14, color: PosUi.deskAccent),
          const SizedBox(width: 6),
          Text(
            tr(text),
            style: AppTypography.text(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: PosUi.deskMuted,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String text) => switch (text) {
    'Apparence' => Icons.palette_outlined,
    'Langue' => Icons.language,
    'Visibilité du menu' => Icons.visibility_outlined,
    'Impressions' => Icons.print_outlined,
    'Hub' => Icons.hub_outlined,
    'Synchronisation' => Icons.sync,
    'Général' => Icons.tune,
    'Notifications' => Icons.notifications_none,
    'Verrouillage' => Icons.lock_outline,
    'À propos' => Icons.info_outline,
    _ => Icons.circle,
  };
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );
    return Material(
      color: PosUi.deskCard,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: PosUi.deskLine),
          ),
          child: body,
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'A';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'
      .toUpperCase();
}

String _paperKey(String format) {
  if (format.contains('58')) return 'thermal_58';
  if (format.contains('a4') || format == 'pdf') return 'a4';
  return 'thermal_80';
}

String _connectionKey(String raw) {
  return switch (raw) {
    'bluetooth' => 'bluetooth',
    'lan' || 'ethernet' || 'wifi' || 'network' => 'lan',
    _ => 'system',
  };
}
