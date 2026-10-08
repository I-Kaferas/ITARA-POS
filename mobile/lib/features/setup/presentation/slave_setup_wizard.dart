import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/config/terminal_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../sync/discovery/master_beacon.dart';
import '../../../sync/master_config_store.dart';
import '../../../sync/pairing_models.dart';
import '../../../sync/sync_engine.dart';
import '../../barcode/presentation/camera_scan_screen.dart';
import '../../devices/presentation/bloc/master_discovery_bloc.dart';
import '../../devices/presentation/bloc/master_pairing_bloc.dart';
import '../domain/slave_station_role.dart';

/// Slave Setup Wizard (mobile.md §48).
///
/// Welcome → discover Master → QR / pairing code → device name + role → COMPLETE.
class SlaveSetupWizard extends StatefulWidget {
  const SlaveSetupWizard({super.key});

  @override
  State<SlaveSetupWizard> createState() => _SlaveSetupWizardState();
}

class _SlaveSetupWizardState extends State<SlaveSetupWizard> {
  static const _steps = ['Welcome', 'Pairing', 'Identity'];

  int _step = 0;
  DiscoveredMaster? _selected;
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController(text: 'POS-04');
  SlaveStationRole _stationRole = SlaveStationRole.cashier;
  bool _busy = false;
  String? _error;
  bool _paired = false;

  @override
  void initState() {
    super.initState();
    final config = TerminalConfigRepository.instance.config;
    if (config.deviceName.isNotEmpty) {
      _nameCtrl.text = config.deviceName;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MasterDiscoveryBloc>().add(const MasterDiscoveryStarted());
      context.read<MasterDiscoveryBloc>().add(const MasterDiscoverySearchRequested());
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect(DiscoveredMaster master) async {
    setState(() {
      _selected = master;
      _error = null;
      _step = 1;
    });
  }

  Future<void> _pairWithCode() async {
    final master = _selected;
    final code = _codeCtrl.text.trim();
    if (master == null) {
      setState(() => _error = 'Sélectionnez d’abord un Master.');
      return;
    }
    if (code.length != 6) {
      setState(() => _error = 'Le code d’appairage comporte 6 chiffres.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final pairing = context.read<MasterPairingBloc>();
    final done = pairing.stream.firstWhere(
      (s) =>
          !s.busy &&
          (s.phase == PairingPhase.registered ||
              s.phase == PairingPhase.rejected),
    );
    pairing.add(MasterPairingSlaveRequested(master: master, code: code));
    await done;

    if (!mounted) return;
    final err = pairing.state.errorMessage;
    setState(() {
      _busy = false;
      if (err != null) {
        _error = err;
      } else {
        _paired = true;
        _error = null;
        _step = 2;
      }
    });
  }

  Future<void> _scanQr() async {
    setState(() => _error = null);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CameraScanScreen(
          onScan: (raw, format) {
            if (format != BarcodeFormat.qrCode &&
                !raw.contains('ITARA') &&
                !raw.contains('master')) {
              // Still try — pairing QR may be plain JSON.
            }
            _submitQr(raw);
          },
        ),
      ),
    );
  }

  Future<void> _submitQr(String raw) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final pairing = context.read<MasterPairingBloc>();
    final done = pairing.stream.firstWhere(
      (s) =>
          !s.busy &&
          (s.phase == PairingPhase.registered ||
              s.phase == PairingPhase.rejected),
    );
    pairing.add(MasterPairingQrRequested(raw));
    await done;

    if (!mounted) return;
    final err = pairing.state.errorMessage;
    setState(() {
      _busy = false;
      if (err != null) {
        _error = err;
      } else {
        _paired = true;
        _error = null;
        _step = 2;
      }
    });
  }

  Future<void> _complete() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nom de l’appareil requis.');
      return;
    }
    if (!_paired && _selected == null) {
      setState(() => _error = 'Appairez-vous d’abord au Master.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repo = TerminalConfigRepository.instance;
      await repo.save(repo.config.copyWith(
        deviceName: name,
        posRole: PosRole.slave,
        isConfigured: false,
      ));
      await MasterConfigStore.instance.save({
        'pos_settings': {
          'station_role': _stationRole.name,
          'station_label': _stationRole.label,
        },
      });

      // Soft first sync from Master if reachable.
      try {
        await SyncEngine.instance.downloadStock();
      } catch (_) {}

      await repo.save(repo.config.copyWith(isConfigured: true));
      if (!mounted) return;
      context.go(AppRoutes.pin);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _back() {
    if (_busy) return;
    setState(() {
      _error = null;
      if (_step > 0) {
        _step--;
        return;
      }
    });
    context.go(AppRoutes.setup);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _WizardHeader(
                  step: _step,
                  steps: _steps,
                  onBack: _back,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: switch (_step) {
                      0 => _WelcomeDiscoverStep(
                          key: const ValueKey('welcome'),
                          selected: _selected,
                          onConnect: _connect,
                        ),
                      1 => _PairingStep(
                          key: const ValueKey('pairing'),
                          master: _selected,
                          codeCtrl: _codeCtrl,
                          busy: _busy,
                          onScanQr: _scanQr,
                          onSubmitCode: _pairWithCode,
                        ),
                      _ => _IdentityStep(
                          key: const ValueKey('identity'),
                          nameCtrl: _nameCtrl,
                          role: _stationRole,
                          busy: _busy,
                          onRoleChanged: (role) {
                            setState(() {
                              _stationRole = role;
                              if (_nameCtrl.text.trim().isEmpty ||
                                  SlaveStationRole.values.any(
                                    (r) => r.suggestedDeviceName == _nameCtrl.text.trim(),
                                  )) {
                                _nameCtrl.text = role.suggestedDeviceName;
                              }
                            });
                          },
                          onComplete: _complete,
                        ),
                    },
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        color: AppColors.danger,
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

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.step,
    required this.steps,
    required this.onBack,
  });

  final int step;
  final List<String> steps;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text(
                  'Slave Setup',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${step + 1}/${steps.length}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 0, 8),
            child: Row(
              children: List.generate(steps.length, (i) {
                final active = i <= step;
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(right: i == steps.length - 1 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: active ? AppColors.brand600 : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeDiscoverStep extends StatelessWidget {
  const _WelcomeDiscoverStep({
    super.key,
    required this.selected,
    required this.onConnect,
  });

  final DiscoveredMaster? selected;
  final ValueChanged<DiscoveredMaster> onConnect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          'Welcome',
          style: GoogleFonts.fraunces(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ce terminal rejoindra un Master sur le réseau local.',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        BlocBuilder<MasterDiscoveryBloc, MasterDiscoveryState>(
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (state.searching) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                    ] else
                      Icon(Icons.radar, size: 18, color: AppColors.brand700),
                    const SizedBox(width: 6),
                    Text(
                      state.searching
                          ? 'Searching for Master...'
                          : (state.masters.isEmpty
                              ? 'Aucun Master trouvé'
                              : 'Masters found'),
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        context
                            .read<MasterDiscoveryBloc>()
                            .add(const MasterDiscoverySearchRequested());
                      },
                      child: const Text('Relancer'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.masters.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      state.statusMessage.isEmpty
                          ? 'Assurez-vous qu’un Master est allumé sur le même Wi‑Fi / LAN.'
                          : state.statusMessage,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  ...state.masters.map((master) {
                    final isSelected = selected?.host == master.host &&
                        selected?.port == master.port;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DiscoverMasterCard(
                        master: master,
                        selected: isSelected,
                        onConnect: () => onConnect(master),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DiscoverMasterCard extends StatelessWidget {
  const _DiscoverMasterCard({
    required this.master,
    required this.selected,
    required this.onConnect,
  });

  final DiscoveredMaster master;
  final bool selected;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.brand600 : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brand50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.hub_outlined, color: AppColors.brand700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  master.name.isEmpty ? 'ITARA POS' : master.name,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  master.displayHost,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onConnect,
            child: const Text('CONNECT'),
          ),
        ],
      ),
    );
  }
}

class _PairingStep extends StatelessWidget {
  const _PairingStep({
    super.key,
    required this.master,
    required this.codeCtrl,
    required this.busy,
    required this.onScanQr,
    required this.onSubmitCode,
  });

  final DiscoveredMaster? master;
  final TextEditingController codeCtrl;
  final bool busy;
  final VoidCallback onScanQr;
  final VoidCallback onSubmitCode;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          'Secure Pairing',
          style: GoogleFonts.fraunces(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          master == null
              ? 'Scannez le QR du Master ou saisissez le code à 6 chiffres.'
              : 'Connecté à ${master!.name} (${master!.displayHost}).\nScan QR ou code d’appairage.',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        _PairOptionCard(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Scan QR',
          subtitle: 'Ouvrez la caméra et visez le QR affiché sur le Master',
          actionLabel: 'Scanner',
          onTap: busy ? null : onScanQr,
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'ou',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pairing Code',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Saisissez le code à 6 chiffres affiché sur le Master, puis attendez ACCEPT.',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: codeCtrl,
                enabled: !busy,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 8,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                ),
                onSubmitted: (_) => onSubmitCode(),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: busy ? null : onSubmitCode,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Demander l’accès'),
              ),
            ],
          ),
        ),
        if (busy) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Authorization… en attente ACCEPT sur le Master.',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PairOptionCard extends StatelessWidget {
  const _PairOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brand50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.brand700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                actionLabel,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({
    super.key,
    required this.nameCtrl,
    required this.role,
    required this.busy,
    required this.onRoleChanged,
    required this.onComplete,
  });

  final TextEditingController nameCtrl;
  final SlaveStationRole role;
  final bool busy;
  final ValueChanged<SlaveStationRole> onRoleChanged;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          'Identity',
          style: GoogleFonts.fraunces(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Nommez ce terminal et choisissez son rôle au sein du magasin.',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Device Name',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: nameCtrl,
          enabled: !busy,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'POS-04',
            prefixIcon: Icon(Icons.tablet_mac_outlined),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Role',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SlaveStationRole.values.map((item) {
            final selected = item == role;
            return ChoiceChip(
              avatar: Icon(item.icon, size: 16),
              label: Text(item.label),
              selected: selected,
              onSelected: busy ? null : (_) => onRoleChanged(item),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: busy ? null : onComplete,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('COMPLETE'),
        ),
      ],
    );
  }
}
