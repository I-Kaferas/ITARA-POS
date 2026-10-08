import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/terminal_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/local/local_database.dart';
import '../../../sync/local_master_discovery.dart';
import '../../../sync/local_master_server.dart';
import '../../../sync/pairing_service.dart';
import '../../printers/domain/print_group.dart';
import '../../printers/domain/printer.dart';
import '../../printers/domain/printer_connection_type.dart';
import '../../printers/services/printer_service.dart';

/// CREATE MASTER flow (mobile.md §47).
class MasterSetupWizard extends StatefulWidget {
  const MasterSetupWizard({super.key, this.onBackToWelcome});

  final VoidCallback? onBackToWelcome;

  @override
  State<MasterSetupWizard> createState() => _MasterSetupWizardState();
}

enum _MasterStep {
  business,
  branch,
  masterName,
  localNetwork,
  database,
  printers,
  pairDevices,
  complete,
}

class _MasterSetupWizardState extends State<MasterSetupWizard> {
  final _formKey = GlobalKey<FormState>();
  var _step = _MasterStep.business;
  bool _loading = false;
  String? _error;

  final _businessCtrl = TextEditingController();
  final _slugCtrl = TextEditingController(text: 'demo');
  final _currencyCtrl = TextEditingController(text: AppConfig.currencyCode);
  final _branchCtrl = TextEditingController(text: 'Magasin principal');
  final _storeIdCtrl = TextEditingController();
  final _masterNameCtrl = TextEditingController(text: 'ITARA POS Master');
  final _printerNameCtrl = TextEditingController(text: 'Caisse');
  final _printerHostCtrl = TextEditingController();
  final _printerPortCtrl = TextEditingController(text: '9100');

  String? _lanAddress;
  String? _dbPath;
  bool _dbReady = false;
  bool _networkReady = false;
  bool _printerSaved = false;
  String? _pairCode;

  static const _labels = <_MasterStep, (String, String)>{
    _MasterStep.business: ('Business', 'Commerce et devise'),
    _MasterStep.branch: ('Branch', 'Branche / magasin'),
    _MasterStep.masterName: ('Master Name', 'Nom de ce terminal Master'),
    _MasterStep.localNetwork: ('Local Network', 'API locale LAN'),
    _MasterStep.database: ('Database', 'Base SQLite locale'),
    _MasterStep.printers: ('Printers', 'Imprimante du commerce'),
    _MasterStep.pairDevices: ('Pair Devices', 'Code d’appairage Slave'),
    _MasterStep.complete: ('Complete', 'Master prêt'),
  };

  @override
  void initState() {
    super.initState();
    final config = TerminalConfigRepository.instance.config;
    if (config.brandName.isNotEmpty) _businessCtrl.text = config.brandName;
    if (config.tenantSlug.isNotEmpty) _slugCtrl.text = config.tenantSlug;
    if (config.currencyCode.isNotEmpty) _currencyCtrl.text = config.currencyCode;
    if (config.deviceName.isNotEmpty) _masterNameCtrl.text = config.deviceName;
    if (config.storeId.isNotEmpty) _storeIdCtrl.text = config.storeId;
    if (config.printerHost.isNotEmpty) _printerHostCtrl.text = config.printerHost;
    if (config.printerName.isNotEmpty) _printerNameCtrl.text = config.printerName;
  }

  @override
  void dispose() {
    _businessCtrl.dispose();
    _slugCtrl.dispose();
    _currencyCtrl.dispose();
    _branchCtrl.dispose();
    _storeIdCtrl.dispose();
    _masterNameCtrl.dispose();
    _printerNameCtrl.dispose();
    _printerHostCtrl.dispose();
    _printerPortCtrl.dispose();
    super.dispose();
  }

  int get _index => _MasterStep.values.indexOf(_step);

  Future<void> _persistPartial({bool asMaster = true}) async {
    final repo = TerminalConfigRepository.instance;
    final current = repo.config;
    final storeId = _storeIdCtrl.text.trim().isEmpty
        ? const Uuid().v4()
        : _storeIdCtrl.text.trim();
    if (_storeIdCtrl.text.trim().isEmpty) {
      _storeIdCtrl.text = storeId;
    }
    await repo.save(current.copyWith(
      brandName: _businessCtrl.text.trim(),
      tenantSlug: _slugCtrl.text.trim().toLowerCase(),
      currencyCode: _currencyCtrl.text.trim().toUpperCase(),
      storeId: storeId,
      companyProfile: _branchCtrl.text.trim(),
      deviceName: _masterNameCtrl.text.trim(),
      posRole: asMaster ? PosRole.master : current.posRole,
      printerName: _printerNameCtrl.text.trim(),
      printerHost: _printerHostCtrl.text.trim(),
      printerPort: int.tryParse(_printerPortCtrl.text.trim()) ?? 9100,
      printerEnabled: _printerHostCtrl.text.trim().isNotEmpty,
      isConfigured: false,
    ));
  }

  Future<void> _prepareNetwork() async {
    await _persistPartial();
    await LocalMasterServer.instance.startIfMaster();
    await LocalMasterDiscovery.instance.start();
    PairingService.instance.startMasterSession();
    setState(() {
      _lanAddress = LocalMasterServer.instance.lanAddress;
      _networkReady = LocalMasterServer.instance.listening;
      _pairCode = PairingService.instance.activeCode;
      if (!_networkReady) {
        _error = LocalMasterServer.instance.lastError ??
            'API locale indisponible sur le port ${LocalMasterServer.port}';
      }
    });
  }

  Future<void> _prepareDatabase() async {
    await LocalDatabase.ensureInitialized();
    final path = await LocalDatabase.instance.sqlitePath();
    await LocalDatabase.instance.database;
    setState(() {
      _dbPath = path;
      _dbReady = true;
    });
  }

  Future<void> _savePrinter({bool skip = false}) async {
    if (skip) {
      setState(() => _printerSaved = true);
      return;
    }
    final host = _printerHostCtrl.text.trim();
    if (host.isEmpty) {
      setState(() => _error = 'Saisissez une IP ou passez cette étape');
      return;
    }
    await _persistPartial();
    await PrinterService.instance.upsertPrinter(Printer(
      id: 'master-cashier',
      name: _printerNameCtrl.text.trim().isEmpty
          ? 'Caisse'
          : _printerNameCtrl.text.trim(),
      group: PrintGroup.cashier,
      host: host,
      port: int.tryParse(_printerPortCtrl.text.trim()) ?? 9100,
      connection: PrinterConnectionType.lan,
      enabled: true,
      priority: 10,
    ));
    setState(() => _printerSaved = true);
  }

  Future<void> _complete() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _persistPartial();
      if (!LocalMasterServer.instance.listening) {
        await LocalMasterServer.instance.startIfMaster();
      }
      PairingService.instance.startMasterSession();
      final repo = TerminalConfigRepository.instance;
      await repo.save(repo.config.copyWith(
        posRole: PosRole.master,
        isConfigured: true,
        deviceId: repo.config.deviceId.isEmpty
            ? repo.config.deviceIdentifier
            : repo.config.deviceId,
      ));
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _next() async {
    setState(() => _error = null);
    if (_step != _MasterStep.complete &&
        _step != _MasterStep.pairDevices &&
        _step != _MasterStep.localNetwork &&
        _step != _MasterStep.database &&
        !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);
    try {
      switch (_step) {
        case _MasterStep.business:
          await _persistPartial();
          setState(() => _step = _MasterStep.branch);
        case _MasterStep.branch:
          await _persistPartial();
          setState(() => _step = _MasterStep.masterName);
        case _MasterStep.masterName:
          await _persistPartial();
          setState(() => _step = _MasterStep.localNetwork);
          await _prepareNetwork();
        case _MasterStep.localNetwork:
          if (!_networkReady) {
            await _prepareNetwork();
            if (!_networkReady) return;
          }
          setState(() => _step = _MasterStep.database);
          await _prepareDatabase();
        case _MasterStep.database:
          if (!_dbReady) await _prepareDatabase();
          setState(() => _step = _MasterStep.printers);
        case _MasterStep.printers:
          if (!_printerSaved && _printerHostCtrl.text.trim().isNotEmpty) {
            await _savePrinter();
            if (!_printerSaved) return;
          } else {
            await _savePrinter(skip: true);
          }
          setState(() => _step = _MasterStep.pairDevices);
          PairingService.instance.startMasterSession();
          setState(() => _pairCode = PairingService.instance.activeCode);
        case _MasterStep.pairDevices:
          setState(() => _step = _MasterStep.complete);
        case _MasterStep.complete:
          await _complete();
          return;
      }
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _back() {
    setState(() => _error = null);
    if (_step == _MasterStep.business) {
      widget.onBackToWelcome?.call();
      return;
    }
    setState(() => _step = _MasterStep.values[_index - 1]);
  }

  @override
  Widget build(BuildContext context) {
    final meta = _labels[_step]!;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _WizardHeader(
            title: meta.$1,
            caption: meta.$2,
            step: _index,
            total: _MasterStep.values.length,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: switch (_step) {
                _MasterStep.business => _BusinessStep(
                    businessCtrl: _businessCtrl,
                    slugCtrl: _slugCtrl,
                    currencyCtrl: _currencyCtrl,
                  ),
                _MasterStep.branch => _BranchStep(
                    branchCtrl: _branchCtrl,
                    storeIdCtrl: _storeIdCtrl,
                  ),
                _MasterStep.masterName => _MasterNameStep(
                    nameCtrl: _masterNameCtrl,
                  ),
                _MasterStep.localNetwork => _NetworkStep(
                    ready: _networkReady,
                    lanAddress: _lanAddress,
                    onRefresh: _prepareNetwork,
                  ),
                _MasterStep.database => _DatabaseStep(
                    ready: _dbReady,
                    path: _dbPath,
                    onRefresh: _prepareDatabase,
                  ),
                _MasterStep.printers => _PrintersStep(
                    nameCtrl: _printerNameCtrl,
                    hostCtrl: _printerHostCtrl,
                    portCtrl: _printerPortCtrl,
                    saved: _printerSaved,
                  ),
                _MasterStep.pairDevices => _PairDevicesStep(
                    code: _pairCode,
                    lanAddress: _lanAddress,
                    onRefreshCode: () {
                      PairingService.instance.refreshCode();
                      setState(
                        () => _pairCode = PairingService.instance.activeCode,
                      );
                    },
                  ),
                _MasterStep.complete => _CompleteStep(
                    business: _businessCtrl.text.trim(),
                    branch: _branchCtrl.text.trim(),
                    masterName: _masterNameCtrl.text.trim(),
                    lanAddress: _lanAddress,
                  ),
              },
            ),
          ),
          _WizardFooter(
            loading: _loading,
            error: _error,
            showBack: true,
            label: switch (_step) {
              _MasterStep.printers
                  when _printerHostCtrl.text.trim().isEmpty =>
                'Passer',
              _MasterStep.complete => 'Terminer',
              _ => 'Suivant',
            },
            onBack: _loading ? null : _back,
            onNext: _loading ? null : _next,
          ),
        ],
      ),
    );
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.title,
    required this.caption,
    required this.step,
    required this.total,
  });

  final String title;
  final String caption;
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CREATE MASTER',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand600,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Text(
                '${step + 1}/$total',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: i <= step ? AppColors.brand600 : AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                if (i != total - 1) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            caption,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardFooter extends StatelessWidget {
  const _WizardFooter({
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
  final VoidCallback? onBack;
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                error!,
                style: GoogleFonts.ibmPlexSans(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          Row(
            children: [
              if (showBack)
                OutlinedButton(
                  onPressed: onBack,
                  child: const Text('Retour'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: onNext,
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.requiredField = true,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool requiredField;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: requiredField
            ? (value) =>
                (value == null || value.trim().isEmpty) ? 'Requis' : null
            : null,
      ),
    );
  }
}

class _BusinessStep extends StatelessWidget {
  const _BusinessStep({
    required this.businessCtrl,
    required this.slugCtrl,
    required this.currencyCtrl,
  });

  final TextEditingController businessCtrl;
  final TextEditingController slugCtrl;
  final TextEditingController currencyCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Field(controller: businessCtrl, label: 'Nom du commerce', hint: 'ITARA Restaurant'),
        _Field(controller: slugCtrl, label: 'Slug tenant', hint: 'itara-gitega'),
        _Field(controller: currencyCtrl, label: 'Devise', hint: 'BIF'),
      ],
    );
  }
}

class _BranchStep extends StatelessWidget {
  const _BranchStep({
    required this.branchCtrl,
    required this.storeIdCtrl,
  });

  final TextEditingController branchCtrl;
  final TextEditingController storeIdCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Field(controller: branchCtrl, label: 'Branche', hint: 'Gitega'),
        _Field(
          controller: storeIdCtrl,
          label: 'Store / Branch ID',
          hint: 'Laisser vide pour générer',
          requiredField: false,
        ),
      ],
    );
  }
}

class _MasterNameStep extends StatelessWidget {
  const _MasterNameStep({required this.nameCtrl});

  final TextEditingController nameCtrl;

  @override
  Widget build(BuildContext context) {
    return _Field(
      controller: nameCtrl,
      label: 'Nom du Master',
      hint: 'ITARA POS — Gitega',
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.ok,
    required this.title,
    required this.detail,
    this.onRefresh,
  });

  final bool ok;
  final String title;
  final String detail;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.hourglass_top, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700),
                ),
              ),
              if (onRefresh != null)
                TextButton(onPressed: onRefresh, child: const Text('Relancer')),
            ],
          ),
          const SizedBox(height: 6),
          Text(detail, style: GoogleFonts.ibmPlexMono(fontSize: 12)),
        ],
      ),
    );
  }
}

class _NetworkStep extends StatelessWidget {
  const _NetworkStep({
    required this.ready,
    required this.lanAddress,
    required this.onRefresh,
  });

  final bool ready;
  final String? lanAddress;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return _StatusCard(
      ok: ready,
      title: ready ? 'API locale active' : 'Démarrage du réseau local…',
      detail: ready
          ? 'http://${lanAddress ?? '…'}:${LocalMasterServer.port}/api/v1'
          : 'Le Master écoute sur le port ${LocalMasterServer.port}',
      onRefresh: () => unawaited(onRefresh()),
    );
  }
}

class _DatabaseStep extends StatelessWidget {
  const _DatabaseStep({
    required this.ready,
    required this.path,
    required this.onRefresh,
  });

  final bool ready;
  final String? path;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return _StatusCard(
      ok: ready,
      title: ready ? 'Base locale prête' : 'Initialisation SQLite…',
      detail: path ?? 'pos_offline.sqlite',
      onRefresh: () => unawaited(onRefresh()),
    );
  }
}

class _PrintersStep extends StatelessWidget {
  const _PrintersStep({
    required this.nameCtrl,
    required this.hostCtrl,
    required this.portCtrl,
    required this.saved,
  });

  final TextEditingController nameCtrl;
  final TextEditingController hostCtrl;
  final TextEditingController portCtrl;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ajoutez l’imprimante caisse (optionnel — failover §41 si plusieurs).',
          style: GoogleFonts.ibmPlexSans(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        _Field(controller: nameCtrl, label: 'Nom', requiredField: false),
        _Field(
          controller: hostCtrl,
          label: 'IP réseau',
          hint: '192.168.1.50',
          requiredField: false,
        ),
        _Field(
          controller: portCtrl,
          label: 'Port',
          hint: '9100',
          requiredField: false,
          keyboardType: TextInputType.number,
        ),
        if (saved)
          Text(
            'Imprimante enregistrée',
            style: GoogleFonts.ibmPlexSans(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _PairDevicesStep extends StatelessWidget {
  const _PairDevicesStep({
    required this.code,
    required this.lanAddress,
    required this.onRefreshCode,
  });

  final String? code;
  final String? lanAddress;
  final VoidCallback onRefreshCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Les Slaves utilisent ce code pour s’appairer au Master.',
          style: GoogleFonts.ibmPlexSans(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text(
                code ?? '······',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lanAddress == null
                    ? 'Master LAN'
                    : '$lanAddress:${LocalMasterServer.port}',
                style: GoogleFonts.ibmPlexSans(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: code == null
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: code!));
                          },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copier'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onRefreshCode,
                    child: const Text('Nouveau code'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompleteStep extends StatelessWidget {
  const _CompleteStep({
    required this.business,
    required this.branch,
    required this.masterName,
    required this.lanAddress,
  });

  final String business;
  final String branch;
  final String masterName;
  final String? lanAddress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified, size: 40, color: AppColors.success),
        const SizedBox(height: 12),
        Text(
          'Master prêt',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text('$business · $branch'),
        Text(masterName),
        if (lanAddress != null)
          Text(
            '$lanAddress:${LocalMasterServer.port}',
            style: GoogleFonts.ibmPlexMono(fontSize: 12),
          ),
        const SizedBox(height: 12),
        Text(
          'Les terminaux Slave peuvent maintenant se connecter.',
          style: GoogleFonts.ibmPlexSans(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
