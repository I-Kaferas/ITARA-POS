import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/branding/branding_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/terminal_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../sync/local_master_discovery.dart';
import '../../../sync/sync_engine.dart';
import '../../../sync/sync_models.dart';
import '../../settings/data/device_api_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;
  bool _showToken = false;
  bool _showRefreshToken = false;

  final _apiUrlCtrl = TextEditingController(text: AppConfig.apiBaseUrl);
  final _tokenCtrl = TextEditingController(text: AppConfig.authToken);
  final _refreshTokenCtrl = TextEditingController(
    text: TerminalConfigRepository.instance.config.refreshToken,
  );
  final _slugCtrl = TextEditingController(
    text: TerminalConfigRepository.instance.config.tenantSlug.isNotEmpty
        ? TerminalConfigRepository.instance.config.tenantSlug
        : 'demo',
  );
  final _tenantCtrl = TextEditingController(text: AppConfig.tenantId);
  final _storeCtrl = TextEditingController(text: AppConfig.storeId);
  final _nameCtrl = TextEditingController(text: 'Terminal POS');
  final _masterHostCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: AppConfig.currencyCode);

  PosRole _role = PosRole.standalone;
  String? _masterDeviceId;
  List<PosDeviceOption> _masters = [];
  bool _loading = false;
  String? _error;

  static const _steps = [
    _SetupStep(title: 'Magasin', caption: 'Poste et contexte'),
    _SetupStep(title: 'Mode', caption: 'Rôle de ce terminal'),
    _SetupStep(title: 'Liaison', caption: 'Master et nom du poste'),
  ];

  bool get _hasAdminSession {
    final config = TerminalConfigRepository.instance.config;
    return config.isSignedIn && config.authToken.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    final config = TerminalConfigRepository.instance.config;
    if (config.apiBaseUrl.isNotEmpty) _apiUrlCtrl.text = config.apiBaseUrl;
    if (config.authToken.isNotEmpty) _tokenCtrl.text = config.authToken;
    if (config.refreshToken.isNotEmpty) _refreshTokenCtrl.text = config.refreshToken;
    if (config.tenantSlug.isNotEmpty) _slugCtrl.text = config.tenantSlug;
    if (config.tenantId.isNotEmpty) _tenantCtrl.text = config.tenantId;
    if (config.storeId.isNotEmpty) _storeCtrl.text = config.storeId;
    if (config.deviceName.isNotEmpty) _nameCtrl.text = config.deviceName;
    if (config.currencyCode.isNotEmpty) _currencyCtrl.text = config.currencyCode;
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    _tokenCtrl.dispose();
    _refreshTokenCtrl.dispose();
    _slugCtrl.dispose();
    _tenantCtrl.dispose();
    _storeCtrl.dispose();
    _nameCtrl.dispose();
    _masterHostCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _saveDraft();
      final service = DeviceApiService();
      final devices = await service.fetchDevices();
      setState(() {
        _masters = devices
            .where((d) => d.posRole == 'master')
            .map((d) => PosDeviceOption(id: d.id, name: d.name))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveDraft() async {
    final repo = TerminalConfigRepository.instance;
    final current = repo.config;
    await repo.save(current.copyWith(
      apiBaseUrl: _apiUrlCtrl.text.trim(),
      authToken: ApiClient.normalizeBearer(_tokenCtrl.text),
      refreshToken: _refreshTokenCtrl.text.trim(),
      tenantId: _tenantCtrl.text.trim(),
      tenantSlug: _slugCtrl.text.trim().toLowerCase(),
      storeId: _storeCtrl.text.trim(),
      deviceName: _nameCtrl.text.trim(),
      posRole: _role,
      masterDeviceId: _masterDeviceId ?? '',
      masterHost: _masterHostCtrl.text.trim(),
      currencyCode: _currencyCtrl.text.trim(),
    ));
  }

  Future<void> _resolveBranding() async {
    final slug = _slugCtrl.text.trim().toLowerCase();
    if (slug.isEmpty) {
      throw Exception('Slug tenant requis');
    }
    final branding = await BrandingService().fetchPublic(
      slug: slug,
      apiBaseUrl: _apiUrlCtrl.text.trim(),
    );
    _tenantCtrl.text = branding.tenantId;
    final repo = TerminalConfigRepository.instance;
    await repo.save(repo.config.copyWith(
      apiBaseUrl: _apiUrlCtrl.text.trim(),
      authToken: ApiClient.normalizeBearer(_tokenCtrl.text),
      refreshToken: _refreshTokenCtrl.text.trim(),
      tenantId: branding.tenantId,
      tenantSlug: branding.slug,
      brandName: branding.brandName,
      brandLogoUrl: branding.logoUrl ?? '',
      brandPrimaryColor: branding.primaryColor,
      brandAccentColor: branding.accentColor,
      storeId: _storeCtrl.text.trim(),
      deviceName: _nameCtrl.text.trim(),
      currencyCode: _currencyCtrl.text.trim(),
    ));
    ThemeController.instance.applyFromConfig();
  }

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == PosRole.slave &&
        (_masterDeviceId == null || _masterDeviceId!.isEmpty) &&
        _masterHostCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Sélectionnez un master ou saisissez son adresse IP');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _saveDraft();
      final repo = TerminalConfigRepository.instance;
      final config = repo.config;

      var deviceId = config.deviceIdentifier;
      var deviceName = _nameCtrl.text.trim();
      try {
        final device = await DeviceApiService().register(
          name: deviceName,
          identifier: config.deviceIdentifier,
          posRole: _role.name,
          masterDeviceId: _masterDeviceId,
          masterHost: _masterHostCtrl.text.trim().isEmpty ? null : _masterHostCtrl.text.trim(),
          platform: Platform.operatingSystem,
          appVersion: AppConfig.appVersion,
        );
        if (device.id.isNotEmpty) deviceId = device.id;
        if (device.name.isNotEmpty) deviceName = device.name;
      } catch (error) {
        final host = _masterHostCtrl.text.trim();
        if (host.isEmpty || config.storeId.isEmpty) rethrow;
      }

      await repo.save(config.copyWith(
        deviceId: deviceId,
        deviceName: deviceName,
        isConfigured: false,
      ));

      if (!mounted) return;
      setState(() => _loading = true);
      final report = await SyncEngine.instance.downloadStock();
      if (!mounted) return;
      setState(() => _loading = false);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _FirstSyncReportDialog(report: report),
      );
      if (!mounted) return;

      await repo.save(repo.config.copyWith(isConfigured: true));
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: ThemeModeButton(),
                    ),
                  ),
                  _Header(step: _step, steps: _steps),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: switch (_step) {
                        0 => _ConnectionStep(
                            apiUrlCtrl: _apiUrlCtrl,
                            tokenCtrl: _tokenCtrl,
                            refreshTokenCtrl: _refreshTokenCtrl,
                            slugCtrl: _slugCtrl,
                            storeCtrl: _storeCtrl,
                            currencyCtrl: _currencyCtrl,
                            nameCtrl: _nameCtrl,
                            showToken: _showToken,
                            showRefreshToken: _showRefreshToken,
                            hideTokens: _hasAdminSession,
                            adminName: TerminalConfigRepository.instance.config.cashierName,
                            onToggleToken: () => setState(() => _showToken = !_showToken),
                            onToggleRefreshToken: () => setState(() => _showRefreshToken = !_showRefreshToken),
                          ),
                        1 => _RoleStep(
                            role: _role,
                            onRoleChanged: (r) => setState(() => _role = r),
                          ),
                        _ => _SlaveStep(
                            masters: _masters,
                            masterDeviceId: _masterDeviceId,
                            masterHostCtrl: _masterHostCtrl,
                            nameCtrl: _nameCtrl,
                            onMasterChanged: (id) => setState(() => _masterDeviceId = id),
                          ),
                      },
                    ),
                  ),
                  _Footer(
                    loading: _loading,
                    error: _error,
                    showBack: _step > 0,
                    label: _primaryLabel,
                    onBack: () => setState(() {
                      _error = null;
                      _step--;
                    }),
                    onNext: _loading ? null : _onNext,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _primaryLabel {
    if (_step == 1 && _role != PosRole.slave) return 'Terminer';
    if (_step == 2) return 'Terminer';
    return 'Suivant';
  }

  Future<void> _onNext() async {
    if (!_formKey.currentState!.validate()) return;

    if (_step == 0) {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        await _resolveBranding();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _step = 1;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
      return;
    }

    if (_step == 1) {
      if (_role == PosRole.slave) {
        await _loadMasters();
        if (!mounted) return;
        setState(() => _step = 2);
      } else {
        await _finish();
      }
      return;
    }

    await _finish();
  }
}

class PosDeviceOption {
  const PosDeviceOption({required this.id, required this.name});
  final String id;
  final String name;
}

class _SetupStep {
  const _SetupStep({required this.title, required this.caption});

  final String title;
  final String caption;
}

class _Header extends StatelessWidget {
  const _Header({required this.step, required this.steps});

  final int step;
  final List<_SetupStep> steps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brand50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.point_of_sale, color: AppColors.brand700, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Configuration',
                style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(
                '${step + 1}/${steps.length}',
                style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: i <= step ? AppColors.brand600 : AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                if (i != steps.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            steps[step].title,
            style: GoogleFonts.ibmPlexSans(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            steps[step].caption,
            style: GoogleFonts.ibmPlexSans(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.loading,
    required this.error,
    required this.showBack,
    required this.label,
    required this.onBack,
    required this.onNext,
  });

  final bool loading;
  final String? error;
  final bool showBack;
  final String label;
  final VoidCallback onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                error!,
                style: GoogleFonts.ibmPlexSans(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
          Row(
            children: [
              if (showBack)
                OutlinedButton(
                  onPressed: loading ? null : onBack,
                  child: const Text('Retour'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: onNext,
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(label),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectionStep extends StatelessWidget {
  const _ConnectionStep({
    required this.apiUrlCtrl,
    required this.tokenCtrl,
    required this.refreshTokenCtrl,
    required this.slugCtrl,
    required this.storeCtrl,
    required this.currencyCtrl,
    required this.nameCtrl,
    required this.showToken,
    required this.showRefreshToken,
    required this.onToggleToken,
    required this.onToggleRefreshToken,
    this.hideTokens = false,
    this.adminName,
  });

  final TextEditingController apiUrlCtrl;
  final TextEditingController tokenCtrl;
  final TextEditingController refreshTokenCtrl;
  final TextEditingController slugCtrl;
  final TextEditingController storeCtrl;
  final TextEditingController currencyCtrl;
  final TextEditingController nameCtrl;
  final bool showToken;
  final bool showRefreshToken;
  final VoidCallback onToggleToken;
  final VoidCallback onToggleRefreshToken;
  final bool hideTokens;
  final String? adminName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (hideTokens) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
            ),
            child: Text(
              'Connecté en tant que ${adminName?.trim().isNotEmpty == true ? adminName : 'admin'}. Complétez la configuration du terminal.',
              style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success),
            ),
          ),
          const SizedBox(height: 14),
        ],
        _Field(
          controller: nameCtrl,
          label: 'Nom du terminal',
          hint: 'Caisse 1',
          icon: Icons.point_of_sale_outlined,
          textInputAction: TextInputAction.next,
          validator: _required,
        ),
        const SizedBox(height: 12),
        _Field(
          controller: apiUrlCtrl,
          label: 'URL de l\'API',
          hint: 'http://127.0.0.1:8000/api/v1',
          icon: Icons.link,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          validator: _required,
        ),
        if (!hideTokens) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Utilisez le backend Laravel (port 8000), pas le front Vite (5173).',
              style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          _Field(
            controller: tokenCtrl,
            label: 'Token d\'accès',
            hint: 'Collez le token des Paramètres',
            icon: Icons.key_outlined,
            obscure: !showToken,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            suffix: IconButton(
              tooltip: showToken ? 'Masquer' : 'Afficher',
              onPressed: onToggleToken,
              icon: Icon(showToken ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
            ),
            validator: _required,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: refreshTokenCtrl,
            label: 'Token de rafraîchissement',
            hint: 'Copié depuis Paramètres web',
            icon: Icons.refresh_outlined,
            obscure: !showRefreshToken,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            suffix: IconButton(
              tooltip: showRefreshToken ? 'Masquer' : 'Afficher',
              onPressed: onToggleRefreshToken,
              icon: Icon(showRefreshToken ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _Field(
          controller: slugCtrl,
          label: 'Slug tenant',
          hint: 'demo',
          icon: Icons.apartment_outlined,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          validator: _required,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Le slug résout automatiquement le tenant et charge la marque (logo, couleurs).',
            style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        _Field(
          controller: storeCtrl,
          label: 'Store ID',
          hint: 'UUID du magasin',
          icon: Icons.storefront_outlined,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          validator: _required,
        ),
        const SizedBox(height: 12),
        _Field(
          controller: currencyCtrl,
          label: 'Devise',
          hint: 'FBU / USD / EUR',
          icon: Icons.payments_outlined,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          validator: _required,
        ),
      ],
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Champ requis';
    return null;
  }
}

class _RoleStep extends StatelessWidget {
  const _RoleStep({required this.role, required this.onRoleChanged});

  final PosRole role;
  final ValueChanged<PosRole> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: PosRole.values.map((item) {
        final selected = role == item;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => onRoleChanged(item),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? AppColors.brand600 : AppColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, size: 20, color: selected ? AppColors.brand700 : AppColors.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(item.description, style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      size: 18,
                      color: selected ? AppColors.brand600 : AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SlaveStep extends StatelessWidget {
  const _SlaveStep({
    required this.masters,
    required this.masterDeviceId,
    required this.masterHostCtrl,
    required this.nameCtrl,
    required this.onMasterChanged,
  });

  final List<PosDeviceOption> masters;
  final String? masterDeviceId;
  final TextEditingController masterHostCtrl;
  final TextEditingController nameCtrl;
  final ValueChanged<String?> onMasterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          controller: nameCtrl,
          label: 'Nom du terminal',
          icon: Icons.point_of_sale_outlined,
          textInputAction: TextInputAction.next,
          validator: _required,
        ),
        const SizedBox(height: 16),
        Text('Terminal master', style: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (masters.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Aucun master enregistré. Saisissez l\'adresse IP ci-dessous.',
              style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.warning),
            ),
          )
        else
          ...masters.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => onMasterChanged(item.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: masterDeviceId == item.id ? AppColors.brand600 : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          masterDeviceId == item.id ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: masterDeviceId == item.id ? AppColors.brand600 : AppColors.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 13)),
                              Text(item.id, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        _Field(
          controller: masterHostCtrl,
          label: 'Adresse IP du master',
          hint: '192.168.1.10',
          icon: Icons.lan_outlined,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          autocorrect: false,
        ),
        const SizedBox(height: 8),
        _LanMasters(controller: masterHostCtrl),
        const SizedBox(height: 8),
        Text(
          'Sans Internet, choisissez le maître trouvé sur le réseau, ou saisissez son IP. L’API locale écoute sur le port 8001.',
          style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _LanMasters extends StatelessWidget {
  const _LanMasters({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalMasterDiscovery.instance,
      builder: (context, _) {
        final found = LocalMasterDiscovery.instance.visible;
        if (found.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Recherche d’un maître Android ou Windows sur le réseau…',
              style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textMuted),
            ),
          );
        }
        return Column(
          children: found
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () => controller.text = item.host,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('${item.name} · ${item.host}'),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.obscure = false,
    this.suffix,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.enableSuggestions = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final bool enableSuggestions;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      enableIMEPersonalizedLearning: !obscure,
      style: GoogleFonts.ibmPlexSans(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: icon == null ? null : Icon(icon, size: 18),
        suffixIcon: suffix,
      ),
      validator: validator,
    );
  }
}

String? _required(String? value) => value == null || value.trim().isEmpty ? 'Requis' : null;

class _FirstSyncReportDialog extends StatelessWidget {
  const _FirstSyncReportDialog({required this.report});

  final SyncReport report;

  @override
  Widget build(BuildContext context) {
    final color = report.ok ? AppColors.success : AppColors.danger;
    final bg = report.ok ? AppColors.successBg : AppColors.dangerBg;

    return AlertDialog(
      title: Text(report.ok ? 'Synchronisation initiale' : 'Synchronisation incomplète'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Text(
              report.message.isNotEmpty
                  ? report.message
                  : (report.ok ? 'Données téléchargées' : 'Échec de la synchronisation'),
              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, color: color),
            ),
          ),
          if (report.ok) ...[
            const SizedBox(height: 14),
            ...report.lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(line.label, style: GoogleFonts.ibmPlexSans(fontSize: 14)),
                    ),
                    Text(
                      '${line.count}',
                      style: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Continuer'),
        ),
      ],
    );
  }
}
