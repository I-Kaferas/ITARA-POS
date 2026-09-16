import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/branding/branding_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/terminal_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../auth/data/pin_auth_service.dart';
import '../../backup/presentation/backup_screen.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import '../../receipt/domain/printer_models.dart';
import '../../settings/data/device_api_service.dart';
import '../../../sync/local_master_discovery.dart';
import '../../../sync/local_master_server.dart';

class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  void applyMasterHost(String host) {
    _masterHostCtrl.text = host;
    setState(() {});
  }

  late final TerminalConfigRepository _repo;
  late TextEditingController _apiUrlCtrl;
  late TextEditingController _internalUrlCtrl;
  late TextEditingController _tokenCtrl;
  late TextEditingController _tenantCtrl;
  late TextEditingController _slugCtrl;
  late TextEditingController _storeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _masterHostCtrl;
  late TextEditingController _currencyCtrl;
  late TextEditingController _printerHostCtrl;
  late TextEditingController _printerPortCtrl;

  PosRole _role = PosRole.standalone;
  bool _printerEnabled = false;
  String _printerModel = 'generic_80';
  PrinterConnection _printerConnection = PrinterConnection.system;
  String _printerName = '';
  bool _testingPrint = false;
  bool _showToken = false;
  bool _saving = false;
  String? _message;
  bool _messageOk = false;
  int _section = 0;

  static const _sections = <_Section>[
    _Section(icon: Icons.memory_outlined, label: 'Terminal', caption: 'Identité et mode'),
    _Section(icon: Icons.storefront_outlined, label: 'Magasin', caption: 'Identifiants'),
    _Section(icon: Icons.lan_outlined, label: 'Connexion', caption: 'Serveurs, token, impression'),
    _Section(icon: Icons.print_outlined, label: 'Impression', caption: 'Ticket réseau'),
    _Section(icon: Icons.tune_outlined, label: 'Paramètres', caption: 'Configurations'),
  ];

  @override
  void initState() {
    super.initState();
    _repo = TerminalConfigRepository.instance;
    final config = _repo.config;
    _apiUrlCtrl = TextEditingController(text: config.apiBaseUrl);
    _internalUrlCtrl = TextEditingController(text: config.internalApiBaseUrl);
    _tokenCtrl = TextEditingController(text: config.authToken);
    _tenantCtrl = TextEditingController(text: config.tenantId);
    _slugCtrl = TextEditingController(text: config.tenantSlug);
    _storeCtrl = TextEditingController(text: config.storeId);
    _nameCtrl = TextEditingController(text: config.deviceName);
    _masterHostCtrl = TextEditingController(text: config.masterHost);
    _currencyCtrl = TextEditingController(text: config.currencyCode);
    _printerHostCtrl = TextEditingController(text: config.printerHost);
    _printerPortCtrl = TextEditingController(text: '${config.printerPort}');
    _role = config.posRole;
    _printerEnabled = config.printerEnabled;
    _printerModel = config.printerModel;
    _printerConnection = PrinterConnection.fromString(config.printerConnection);
    _printerName = config.printerName;
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    _internalUrlCtrl.dispose();
    _tokenCtrl.dispose();
    _tenantCtrl.dispose();
    _slugCtrl.dispose();
    _storeCtrl.dispose();
    _nameCtrl.dispose();
    _masterHostCtrl.dispose();
    _currencyCtrl.dispose();
    _printerHostCtrl.dispose();
    _printerPortCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      final current = _repo.config;
      final token = _tokenCtrl.text.trim();
      final tokenChanged = token != current.authToken;
      final slug = _slugCtrl.text.trim().toLowerCase();

      var tenantId = _tenantCtrl.text.trim();
      var brandName = current.brandName;
      var brandLogoUrl = current.brandLogoUrl;
      var brandPrimaryColor = current.brandPrimaryColor;
      var brandAccentColor = current.brandAccentColor;

      if (slug.isNotEmpty) {
        final branding = await BrandingService().fetchPublic(
          slug: slug,
          apiBaseUrl: _apiUrlCtrl.text.trim(),
        );
        tenantId = branding.tenantId;
        _tenantCtrl.text = tenantId;
        brandName = branding.brandName;
        brandLogoUrl = branding.logoUrl ?? '';
        brandPrimaryColor = branding.primaryColor;
        brandAccentColor = branding.accentColor;
      }

      await _repo.save(current.copyWith(
        apiBaseUrl: _apiUrlCtrl.text.trim(),
        internalApiBaseUrl: _internalUrlCtrl.text.trim(),
        authToken: token,
        refreshToken: tokenChanged ? '' : current.refreshToken,
        tokenExpiresAt: tokenChanged ? '' : current.tokenExpiresAt,
        tenantId: tenantId,
        tenantSlug: slug,
        brandName: brandName,
        brandLogoUrl: brandLogoUrl,
        brandPrimaryColor: brandPrimaryColor,
        brandAccentColor: brandAccentColor,
        storeId: _storeCtrl.text.trim(),
        deviceName: _nameCtrl.text.trim(),
        posRole: _role,
        masterHost: _masterHostCtrl.text.trim(),
        currencyCode: _currencyCtrl.text.trim().isEmpty ? 'FBU' : _currencyCtrl.text.trim(),
        printerHost: _printerHostCtrl.text.trim(),
        printerPort: int.tryParse(_printerPortCtrl.text.trim()) ?? 9100,
        printerEnabled: _printerEnabled,
        printerModel: _printerModel,
        printerConnection: _printerConnection.name,
        printerName: _printerName,
        printerFormat: PrinterModelPreset.byId(_printerModel).format.value,
        isConfigured: true,
      ));
      ThemeController.instance.applyFromConfig();

      final device = await DeviceApiService().register(
        name: _nameCtrl.text.trim(),
        identifier: _repo.config.deviceIdentifier,
        posRole: _role.name,
        masterDeviceId: _repo.config.masterDeviceId.isEmpty ? null : _repo.config.masterDeviceId,
        masterHost: _masterHostCtrl.text.trim().isEmpty ? null : _masterHostCtrl.text.trim(),
        platform: Platform.operatingSystem,
        appVersion: AppConfig.appVersion,
      );

      await _repo.save(_repo.config.copyWith(deviceId: device.id));

      setState(() {
        _message = 'Réglages enregistrés';
        _messageOk = true;
        _saving = false;
      });
    } catch (e) {
      setState(() {
        _message = e.toString().replaceFirst('Exception: ', '');
        _messageOk = false;
        _saving = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Le caissier sera déconnecté. Le terminal reste configuré.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Déconnexion')),
        ],
      ),
    );
    if (confirmed != true) return;

    await PinAuthService.signOut();
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reconfigurer le terminal ?'),
        content: const Text('Les identifiants locaux seront effacés. Le terminal devra être configuré à nouveau.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo.clear();
    if (!mounted) return;
    context.go(AppRoutes.setup);
  }

  @override
  Widget build(BuildContext context) {
    final config = _repo.config;
    final wide = PosUi.isWide(context);
    final compact = PosUi.isPhone(context) || MediaQuery.sizeOf(context).width < PosUi.tabletBreakpoint;
    final pad = PosUi.pagePadding(context);

    return ColoredBox(
      color: AppColors.canvas,
      child: Column(
        children: [
          _Header(
            name: _nameCtrl.text.trim().isEmpty ? 'Terminal POS' : _nameCtrl.text.trim(),
            role: _role,
            configured: config.isConfigured,
            platform: _platformLabel(),
            compact: compact,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad.left, 12, pad.right, 0),
              child: wide ? _desktopBody(config) : _mobileBody(config),
            ),
          ),
          _Footer(
            saving: _saving,
            message: _message,
            messageOk: _messageOk,
            compact: compact,
            onSave: _save,
            onLogout: _logout,
            onReset: _reset,
          ),
        ],
      ),
    );
  }

  Widget _desktopBody(TerminalConfig config) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 248,
          child: _SectionNav(
            sections: _sections,
            selected: _section,
            onSelect: (index) => setState(() => _section = index),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: _panel(config)),
      ],
    );
  }

  Widget _mobileBody(TerminalConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionChips(
          sections: _sections,
          selected: _section,
          onSelect: (index) => setState(() => _section = index),
        ),
        const SizedBox(height: 12),
        Expanded(child: _panel(config)),
      ],
    );
  }

  Widget _panel(TerminalConfig config) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        children: [
          _SectionHeading(section: _sections[_section]),
          const SizedBox(height: 16),
          switch (_section) {
            0 => _terminalSection(config),
            1 => _storeSection(),
            2 => _connectionSection(),
            3 => _printSection(),
            _ => _settingsHub(),
          },
        ],
      ),
    );
  }

  Widget _terminalSection(TerminalConfig config) {
    final wide = MediaQuery.sizeOf(context).width >= PosUi.tabletBreakpoint;
    final tiles = [
      _Fact(label: 'Caissier', value: config.cashierName.isEmpty ? 'Non connecté' : config.cashierName),
      _Fact(label: 'Identifiant', value: config.deviceIdentifier.isEmpty ? '—' : config.deviceIdentifier),
      _Fact(label: 'Device ID', value: config.deviceId.isEmpty ? 'Non enregistré' : config.deviceId),
      _Fact(label: 'Plateforme', value: _platformLabel()),
      _Fact(label: 'Version', value: AppConfig.appVersion),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= PosUi.phoneBreakpoint ? 3 : 2;
            final gap = 10.0;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: tiles
                  .map((tile) => SizedBox(width: width, child: tile))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        Text('Mode du terminal', style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          'Choisissez comment ce poste se comporte sur le réseau du magasin.',
          style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < PosRole.values.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _RoleCard(
                    role: PosRole.values[i],
                    selected: _role == PosRole.values[i],
                    onTap: () => setState(() => _role = PosRole.values[i]),
                  ),
                ),
              ],
            ],
          )
        else
          ...PosRole.values.map(
            (role) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RoleCard(
                role: role,
                selected: _role == role,
                onTap: () => setState(() => _role = role),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.sync),
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Ouvrir la synchronisation'),
          ),
        ),
      ],
    );
  }

  Widget _settingsHub() {
    final items = <(String, String, VoidCallback)>[
      ('Entreprise', 'Identité du magasin', () => setState(() => _section = 1)),
      ('Magasin', 'Identifiants', () => setState(() => _section = 1)),
      ('POS', 'Mode du terminal', () => setState(() => _section = 0)),
      ('Taxes', 'Appliquées par le catalogue', () => setState(() => _section = 1)),
      ('Devise', configCurrency(), () => setState(() => _section = 1)),
      ('Impression', 'Ticket', () => setState(() => _section = 3)),
      ('Stock', 'Mouvements du terminal', () => context.go(AppRoutes.reports)),
      ('Sync', 'File et maître local', () => context.go(AppRoutes.sync)),
      ('Sauvegardes', 'SQLite, sync, configuration, cloud', () {
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BackupScreen()));
      }),
      ('Restaurant', 'Tables et cuisine', () => context.go(AppRoutes.hospitality)),
      ('Hôtel', 'Chambres et folios', () => context.go(AppRoutes.hospitality)),
    ];
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.border),
              ),
              title: Text(item.$1),
              subtitle: Text(item.$2),
              trailing: const Icon(Icons.chevron_right),
              onTap: item.$3,
            ),
          ),
      ],
    );
  }

  String configCurrency() => _currencyCtrl.text.trim().isEmpty ? 'FBU' : _currencyCtrl.text.trim();

  Widget _storeSection() {
    return Column(
      children: [
        _field(_nameCtrl, 'Nom du terminal', icon: Icons.point_of_sale_outlined, hint: 'Caisse 1'),
        const SizedBox(height: 12),
        _field(_slugCtrl, 'Slug tenant', icon: Icons.tag_outlined, hint: 'demo'),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'À l’enregistrement, le slug charge la marque et remplit le Tenant ID.',
            style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        _field(_tenantCtrl, 'Tenant ID', icon: Icons.apartment_outlined),
        const SizedBox(height: 12),
        _field(_storeCtrl, 'Store ID', icon: Icons.store_outlined),
        const SizedBox(height: 12),
        _field(_currencyCtrl, 'Devise', icon: Icons.payments_outlined, hint: 'FBU'),
      ],
    );
  }

  Widget _connectionSection() {
    return Column(
      children: [
        if (_role == PosRole.master) const _LocalMasterStatus(),
        if (_role == PosRole.master) const SizedBox(height: 12),
        _field(
          _internalUrlCtrl,
          'Serveur interne (LAN)',
          icon: Icons.router_outlined,
          hint: 'http://192.168.1.10:8001/api/v1',
        ),
        const SizedBox(height: 8),
        Text(
          'Utilisé en priorité. Le cloud sert de secours si le réseau local ne répond pas.',
          style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        _field(_apiUrlCtrl, 'API cloud', icon: Icons.cloud_outlined),
        const SizedBox(height: 12),
        _field(
          _tokenCtrl,
          'Token d\'accès',
          icon: Icons.key_outlined,
          obscure: !_showToken,
          suffix: IconButton(
            onPressed: () => setState(() => _showToken = !_showToken),
            icon: Icon(_showToken ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
          ),
        ),
        if (_role == PosRole.slave) ...[
          const SizedBox(height: 12),
          _field(_masterHostCtrl, 'Adresse du master', icon: Icons.hub_outlined, hint: '192.168.1.10'),
          const SizedBox(height: 8),
          const _DiscoveredMasters(),
        ],
        const SizedBox(height: 22),
        Text('Réglage impression', style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Modèle, connexion et ticket, configurés avec le terminal.',
          style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        _printSection(),
      ],
    );
  }

  void _selectPrinterModel(PrinterModelPreset model) {
    setState(() {
      _printerModel = model.id;
      _printerConnection = model.connection;
      _printerPortCtrl.text = '${model.defaultPort}';
    });
  }

  Future<void> _pickSystemPrinter() async {
    final printers = await Printing.listPrinters();
    if (!mounted) return;
    if (printers.isEmpty) {
      setState(() => _message = 'Aucune imprimante système détectée');
      _messageOk = false;
      return;
    }
    final selected = await showDialog<Printer>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Choisir une imprimante')),
              ...printers.map(
                (printer) => ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: Text(printer.name),
                  subtitle: Text(printer.isAvailable ? 'Disponible' : 'Indisponible'),
                  onTap: () => Navigator.pop(ctx, printer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _printerName = selected.name);
  }

  Future<void> _testPrint() async {
    setState(() => _testingPrint = true);
    try {
      final model = PrinterModelPreset.byId(_printerModel);
      final width = model.format.paperWidthMm * PdfPageFormat.mm;
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(width, 80 * PdfPageFormat.mm, marginAll: 4 * PdfPageFormat.mm),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Test POS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text(model.label),
              pw.Text(_printerConnection.label),
              if (_printerName.isNotEmpty) pw.Text(_printerName),
            ],
          ),
        ),
      );
      final bytes = await doc.save();
      if (_printerConnection == PrinterConnection.network) {
        final host = _printerHostCtrl.text.trim();
        if (host.isEmpty) throw Exception('Saisissez l’adresse de l’imprimante');
        final port = int.tryParse(_printerPortCtrl.text.trim()) ?? 9100;
        await Printing.directPrintPdf(
          printer: Printer(url: 'socket://$host:$port', name: model.label),
          onLayout: (_) async => bytes,
        );
      } else if (_printerName.isNotEmpty) {
        final printers = await Printing.listPrinters();
        final printer = printers.where((item) => item.name == _printerName).firstOrNull;
        if (printer == null) throw Exception('Imprimante introuvable');
        await Printing.directPrintPdf(printer: printer, onLayout: (_) async => bytes);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'Test POS');
      }
      if (!mounted) return;
      setState(() {
        _message = 'Ticket de test envoyé';
        _messageOk = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('Exception: ', '');
        _messageOk = false;
      });
    } finally {
      if (mounted) setState(() => _testingPrint = false);
    }
  }

  Widget _printSection() {
    final model = PrinterModelPreset.byId(_printerModel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _printerEnabled ? AppColors.successBg : const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _printerEnabled ? const Color(0xFFA7F3D0) : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.print_outlined,
                color: _printerEnabled ? AppColors.success : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _printerEnabled ? 'Impression activée' : 'Impression désactivée',
                      style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      '${model.brand} · ${model.label}',
                      style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _printerEnabled,
                onChanged: (value) => setState(() => _printerEnabled = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('Modèle', style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...PrinterModelPreset.all.map((item) {
          final selected = _printerModel == item.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selected ? AppColors.brand50 : const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _printerEnabled ? () => _selectPrinterModel(item) : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? AppColors.brand600 : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 18,
                        color: selected ? AppColors.brand600 : AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.label, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 13)),
                            Text(
                              '${item.brand} · ${item.hint}',
                              style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Text('Connexion', style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PrinterConnection.values.map((connection) {
            final selected = _printerConnection == connection;
            return ChoiceChip(
              label: Text(connection.label),
              selected: selected,
              onSelected: _printerEnabled
                  ? (_) => setState(() => _printerConnection = connection)
                  : null,
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(
          _printerConnection.hint,
          style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (_printerConnection == PrinterConnection.network) ...[
          _field(_printerHostCtrl, 'Adresse IP', icon: Icons.dns_outlined, enabled: _printerEnabled, hint: '192.168.1.50'),
          const SizedBox(height: 12),
          _field(_printerPortCtrl, 'Port', icon: Icons.tag, enabled: _printerEnabled, hint: '9100'),
        ] else ...[
          OutlinedButton.icon(
            onPressed: _printerEnabled ? _pickSystemPrinter : null,
            icon: Icon(printerConnectionIcon(_printerConnection), size: 18),
            label: Text(_printerName.isEmpty ? 'Choisir l’imprimante' : _printerName),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: !_printerEnabled || _testingPrint ? null : _testPrint,
          icon: _testingPrint
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.receipt_long_outlined, size: 18),
          label: const Text('Imprimer un ticket de test'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    IconData? icon,
    String? hint,
    bool obscure = false,
    bool enabled = true,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.ibmPlexSans(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: enabled ? const Color(0xFFF8FAFB) : AppColors.brand50,
        prefixIcon: icon == null ? null : Icon(icon, size: 18),
        suffixIcon: suffix,
        isDense: true,
      ),
    );
  }
}

String _platformLabel() {
  if (Platform.isWindows) return 'Windows';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iOS';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isLinux) return 'Linux';
  return Platform.operatingSystem;
}

class _Section {
  const _Section({required this.icon, required this.label, required this.caption});

  final IconData icon;
  final String label;
  final String caption;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.role,
    required this.configured,
    required this.platform,
    required this.compact,
  });

  final String name;
  final PosRole role;
  final bool configured;
  final String platform;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(compact ? 16 : 24, compact ? 14 : 18, compact ? 16 : 24, compact ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuration',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: compact ? 20 : 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$name · $platform · ${role.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _StatusPill(configured: configured),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.configured});

  final bool configured;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: configured ? AppColors.successBg : AppColors.warningBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: configured ? AppColors.success.withValues(alpha: 0.25) : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        configured ? 'Configuré' : 'Incomplet',
        style: GoogleFonts.ibmPlexSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: configured ? AppColors.success : AppColors.warning,
        ),
      ),
    );
  }
}

class _SectionNav extends StatelessWidget {
  const _SectionNav({
    required this.sections,
    required this.selected,
    required this.onSelect,
  });

  final List<_Section> sections;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            _NavTile(
              section: sections[i],
              selected: selected == i,
              onTap: () => onSelect(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _Section section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand50 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: selected ? AppColors.brand600 : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(section.icon, size: 18, color: selected ? AppColors.brand700 : AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.label,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.brandInk : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    section.caption,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionChips extends StatelessWidget {
  const _SectionChips({
    required this.sections,
    required this.selected,
    required this.onSelect,
  });

  final List<_Section> sections;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < sections.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            _chip(index),
          ],
        ],
      ),
    );
  }

  Widget _chip(int index) {
    final section = sections[index];
    final active = selected == index;
    return Material(
      color: active ? AppColors.brand600 : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => onSelect(index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? AppColors.brand600 : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(section.icon, size: 16, color: active ? Colors.white : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                section.label,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.section});

  final _Section section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          section.caption,
          style: GoogleFonts.ibmPlexSans(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final PosRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brand50 : AppColors.fieldFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.brand600 : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(role.icon, size: 18, color: selected ? AppColors.brand700 : AppColors.textMuted),
                  const Spacer(),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    size: 16,
                    color: selected ? AppColors.brand600 : AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(role.label, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                role.description,
                style: GoogleFonts.ibmPlexSans(fontSize: 11, height: 1.35, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.saving,
    required this.message,
    required this.messageOk,
    required this.compact,
    required this.onSave,
    required this.onLogout,
    required this.onReset,
  });

  final bool saving;
  final String? message;
  final bool messageOk;
  final bool compact;
  final VoidCallback onSave;
  final VoidCallback onLogout;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 14 : 24, 12, compact ? 14 : 24, compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: messageOk ? AppColors.successBg : AppColors.dangerBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: messageOk
                      ? AppColors.success.withValues(alpha: 0.2)
                      : AppColors.danger.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                message!,
                style: GoogleFonts.ibmPlexSans(
                  color: messageOk ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: saving ? null : onSave,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand600),
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Enregistrer'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : onLogout,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Déconnexion'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: saving ? null : onReset,
                        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              children: [
                FilledButton.icon(
                  onPressed: saving ? null : onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand600,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Enregistrer'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: saving ? null : onLogout,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Déconnexion'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: saving ? null : onReset,
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reconfigurer'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LocalMasterStatus extends StatelessWidget {
  const _LocalMasterStatus();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalMasterServer.instance,
      builder: (context, _) {
        final server = LocalMasterServer.instance;
        final url = server.advertiseUrl;
        final ready = server.listening && url != null;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ready ? const Color(0xFFECFDF3) : const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ready ? const Color(0xFF86EFAC) : const Color(0xFFFDBA74)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ready ? 'Serveur maître local actif' : 'Serveur maître local arrêté',
                style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                ready
                    ? '$url — les autres caisses (Android ou Windows) se connectent ici, même sans Internet. Sous Windows, autorisez le port ${LocalMasterServer.port} (API) et ${LocalMasterDiscovery.beaconPort} (découverte) si le pare-feu le demande.'
                    : server.listening
                        ? 'Écoute sur le port ${LocalMasterServer.port}, mais l’adresse IP locale est introuvable.'
                        : server.lastError ?? 'Le terminal maître n’écoute pas encore sur le réseau local.',
                style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (ready) ...[
                const SizedBox(height: 8),
                Text(
                  server.clients.isEmpty
                      ? 'Aucune autre caisse connectée pour le moment. Elles apparaissent dès qu’elles joignent cette adresse, sans Internet.'
                      : 'Caisses connectées : ${server.clients.values.map((item) => item.name).join(', ')}',
                  style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DiscoveredMasters extends StatelessWidget {
  const _DiscoveredMasters();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalMasterDiscovery.instance,
      builder: (context, _) {
        final found = LocalMasterDiscovery.instance.visible;
        if (found.isEmpty) {
          return Text(
            'Recherche du maître sur le réseau local…',
            style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textMuted),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Maîtres trouvés sur le réseau', style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...found.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: OutlinedButton(
                    onPressed: () {
                      context.findAncestorStateOfType<_ConfigurationScreenState>()?.applyMasterHost(item.host);
                    },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('${item.name} · ${item.host}'),
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }
}
