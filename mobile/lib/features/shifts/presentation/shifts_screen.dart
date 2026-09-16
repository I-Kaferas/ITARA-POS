import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_error_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import '../data/shifts_api_service.dart';
import '../domain/shift_models.dart';
import '../services/shift_z_report_printer.dart';

class ShiftsScreen extends StatefulWidget {
  const ShiftsScreen({super.key});

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  final _api = ShiftsApiService();
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  List<CashRegister> _registers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final registers = await _api.fetchRegisters();
      setState(() {
        _registers = registers;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  ({String name, String code}) _nextRegisterDefaults() {
    final used = _registers.map((register) => register.code.toUpperCase()).toSet();
    var next = 1;
    for (final register in _registers) {
      final match = RegExp(r'(\d+)$').firstMatch(register.code);
      final value = int.tryParse(match?.group(1) ?? '');
      if (value != null && value >= next) next = value + 1;
    }
    var code = 'REG-${next.toString().padLeft(2, '0')}';
    while (used.contains(code)) {
      next += 1;
      code = 'REG-${next.toString().padLeft(2, '0')}';
    }
    final name = next == 1 && _registers.isEmpty ? 'Caisse principale' : 'Caisse ${next.toString().padLeft(2, '0')}';
    return (name: name, code: code);
  }

  Future<void> _createRegister() async {
    final defaults = _nextRegisterDefaults();
    final nameCtrl = TextEditingController(text: defaults.name);
    final codeCtrl = TextEditingController(text: defaults.code);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PosUi.radiusXl)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Nouvelle caisse', style: GoogleFonts.ibmPlexSans(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Code'),
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.ibmPlexMono(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler'))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: PosUi.ctaHeight - 4,
                        child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Créer')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    final code = codeCtrl.text.trim().toUpperCase();
    nameCtrl.dispose();
    codeCtrl.dispose();

    if (confirmed != true) return;
    if (name.isEmpty || code.isEmpty) {
      _showMessage('Nom et code requis');
      return;
    }

    try {
      await _api.createRegister(name: name, code: code);
      _showMessage('Caisse créée');
      await _load();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _openSession(CashRegister register) async {
    final balanceCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PosUi.radiusXl)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ouvrir le shift', style: GoogleFonts.ibmPlexSans(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${register.name} · ${register.code}', style: PosUi.caption()),
                const SizedBox(height: 14),
                TextField(
                  controller: balanceCtrl,
                  decoration: InputDecoration(
                    labelText: 'Fonds initial (${AppConfig.currencyCode})',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes (optionnel)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler'))),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: PosUi.ctaHeight - 4,
                        child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ouvrir')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final balance = _parseMoney(balanceCtrl.text);
      final opened = await _api.openSession(
        registerId: register.id,
        openingBalance: balance,
        notes: notesCtrl.text.trim(),
      );
      final repo = TerminalConfigRepository.instance;
      await repo.save(repo.config.copyWith(
        cashRegisterId: register.id,
        cashSessionId: opened.session?.id ?? repo.config.cashSessionId,
      ));
      _showMessage('Shift ouvert');
      await _load();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _closeSession(CashRegister register) async {
    CurrentSessionResponse? current;
    try {
      current = await _api.currentSession(register.id);
    } catch (e) {
      _showMessage(e.toString());
      return;
    }

    final expected = current.summary?.expectedCash ?? current.session?.expectedCash ?? 0;
    final actualCtrl = TextEditingController(
      text: (expected / 100).toStringAsFixed(2),
    );
    final notesCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final varianceCtrl = TextEditingController();

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PosUi.radiusXl)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Fermer le shift', style: GoogleFonts.ibmPlexSans(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(register.name, style: PosUi.caption()),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: BorderRadius.circular(PosUi.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Text('ESPÈCES ATTENDUES', style: PosUi.totalCaption()),
                      const SizedBox(height: 6),
                      Text(MoneyFormatter.format(expected), style: PosUi.totalAmount(size: 26)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: actualCtrl,
                  decoration: InputDecoration(
                    labelText: 'Espèces comptées (${AppConfig.currencyCode})',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  decoration: const InputDecoration(labelText: 'PIN caissier'),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes de clôture'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: varianceCtrl,
                  decoration: const InputDecoration(labelText: 'Motif d’écart (si besoin)'),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler'))),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: PosUi.ctaHeight - 4,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                          child: const Text('Fermer shift'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final counted = _parseMoney(actualCtrl.text);
      final pin = pinCtrl.text.trim();
      final notes = notesCtrl.text.trim();
      final variance = varianceCtrl.text.trim();
      SessionSummary? report = current.summary;
      if (pin.isNotEmpty) {
        try {
          await _api.closeCashierShiftWithPin(
            registerId: register.id,
            pin: pin,
            countedCash: counted,
            notes: notes,
            varianceReason: variance,
          );
        } catch (_) {
          final closed = await _api.closeSession(
            registerId: register.id,
            actualCash: counted,
            notes: notes,
          );
          report = closed.zReport ?? closed.summary ?? report;
        }
      } else {
        final closed = await _api.closeSession(
          registerId: register.id,
          actualCash: counted,
          notes: notes,
        );
        report = closed.zReport ?? closed.summary ?? report;
      }
      final repo = TerminalConfigRepository.instance;
      if (repo.config.cashRegisterId == register.id) {
        await repo.save(repo.config.copyWith(cashSessionId: ''));
      }
      _showMessage('Shift fermé');
      await _load();

      if (report != null && mounted) {
        final printIt = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Rapport de shift'),
            content: const Text('Voulez-vous imprimer le rapport de clôture ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Imprimer')),
            ],
          ),
        );
        if (printIt == true && mounted) {
          try {
            await ShiftZReportPrinter().printReport(
              registerName: register.name,
              report: report,
            );
          } catch (e) {
            _showMessage(e.toString());
          }
        }
      }
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _showSessionDetail(CashRegister register) async {
    try {
      final current = await _api.currentSession(register.id);
      if (!mounted) return;

      if (current.session == null) {
        _showMessage('Aucun shift ouvert');
        return;
      }

      final sessions = await _api.fetchSessions(register.id);
      if (!mounted) return;

      final detail = _SessionDetailView(
        register: register,
        current: current,
        history: sessions,
        dateFormat: _dateFormat,
        onMovement: () {
          Navigator.of(context).pop();
          _recordMovement(register);
        },
      );
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
            child: detail,
          ),
        ),
      );
      await _load();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _recordMovement(CashRegister register) async {
    if (!register.hasOpenSession) {
      _showMessage('Ouvrez un shift avant d\'ajouter un mouvement.');
      return;
    }

    List<MovementType> types;
    try {
      types = await _api.fetchMovementTypes();
    } catch (e) {
      _showMessage(e.toString());
      return;
    }

    if (types.isEmpty) {
      _showMessage('Aucun type de mouvement disponible.');
      return;
    }

    if (!mounted) return;

    String selectedType = types.first.value;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PosUi.radiusXl)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Mouvement de caisse', style: GoogleFonts.ibmPlexSans(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey(selectedType),
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: types
                        .map((t) => DropdownMenuItem(
                              value: t.value,
                              child: Text(t.labelFr.isNotEmpty ? t.labelFr : t.label),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedType = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    decoration: InputDecoration(
                      labelText: 'Montant (${AppConfig.currencyCode})',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler'))),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: PosUi.ctaHeight - 4,
                          child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final amount = _parseMoney(amountCtrl.text);
    if (amount < 1) {
      _showMessage('Le montant doit être supérieur à 0.');
      return;
    }

    try {
      await _api.recordMovement(
        registerId: register.id,
        movementType: selectedType,
        amount: amount,
        description: descCtrl.text.trim(),
      );
      _showMessage('Mouvement enregistré');
      await _load();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  int _parseMoney(String input) {
    final cleaned = input.replaceAll(',', '.').trim();
    final value = double.tryParse(cleaned) ?? 0;
    return (value * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = TerminalConfigRepository.instance.config.canManageShifts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SlaveModeBanner(
          message: 'Les shifts sont gérés par le terminal Master.',
        ),
        _ShiftsHeader(
          openCount: _registers.where((r) => r.hasOpenSession).length,
          onCreate: canManage ? _createRegister : null,
        ),
        Expanded(
          child: ColoredBox(
            color: AppColors.canvas,
            child: !canManage
              ? const RoleGuard(
                  allowed: false,
                  fallbackMessage:
                      'Seul le terminal Master peut ouvrir, fermer et créer des shifts.',
                  child: SizedBox.shrink(),
                )
              : _loading
              ? const LoadingView(message: 'Chargement des caisses...')
              : _error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : _registers.isEmpty
                      ? EmptyState(
                          icon: Icons.schedule_outlined,
                          title: 'Aucune caisse',
                          subtitle: 'Créez une caisse pour commencer à gérer les shifts.',
                          action: FilledButton.icon(
                            onPressed: _createRegister,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Créer une caisse'),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.brand500,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            itemCount: _registers.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final register = _registers[index];
                              return _RegisterCard(
                                register: register,
                                dateFormat: _dateFormat,
                                onOpen: () => _openSession(register),
                                onClose: () => _closeSession(register),
                                onDetail: () => _showSessionDetail(register),
                                onMovement: () => _recordMovement(register),
                              );
                            },
                          ),
                        ),
          ),
        ),
      ],
    );
  }
}

class _ShiftsHeader extends StatelessWidget {
  const _ShiftsHeader({required this.openCount, this.onCreate});

  final int openCount;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brand50,
              borderRadius: BorderRadius.circular(PosUi.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(Icons.schedule, color: AppColors.brandInk, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shifts',
                  style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    PosBadge(
                      label: openCount > 0
                          ? '$openCount ouvert${openCount > 1 ? 's' : ''}'
                          : 'Aucun ouvert',
                      tone: openCount > 0 ? PosBadgeTone.success : PosBadgeTone.neutral,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onCreate != null)
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouvelle caisse'),
              ),
            ),
        ],
      ),
    );
  }
}

class _RegisterCard extends StatelessWidget {
  const _RegisterCard({
    required this.register,
    required this.dateFormat,
    required this.onOpen,
    required this.onClose,
    required this.onDetail,
    required this.onMovement,
  });

  final CashRegister register;
  final DateFormat dateFormat;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onDetail;
  final VoidCallback onMovement;

  @override
  Widget build(BuildContext context) {
    final isOpen = register.hasOpenSession;
    final session = register.openSession;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(PosUi.radiusXl),
        border: Border.all(
          color: isOpen ? AppColors.success.withValues(alpha: 0.35) : AppColors.border,
          width: isOpen ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onDetail,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(PosUi.radiusXl)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isOpen ? AppColors.successBg : AppColors.brand50,
                      borderRadius: BorderRadius.circular(PosUi.radiusMd),
                    ),
                    child: Icon(
                      isOpen ? Icons.lock_open_rounded : Icons.point_of_sale_outlined,
                      color: isOpen ? AppColors.success : AppColors.brandInk,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                register.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(register.code, style: PosUi.money(size: 12, color: AppColors.textMuted)),
                            const SizedBox(width: 8),
                            PosBadge(
                              label: isOpen ? 'Ouvert' : 'Fermé',
                              tone: isOpen ? PosBadgeTone.success : PosBadgeTone.neutral,
                              compact: true,
                            ),
                          ],
                        ),
                        if (isOpen && session != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Ouvert le ${dateFormat.format(session.openedAt)}',
                            style: PosUi.caption(),
                          ),
                          if (session.openedByName != null)
                            Text('Par ${session.openedByName}', style: PosUi.caption()),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          if (isOpen && session != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  _MiniStat(label: 'Fonds', value: MoneyFormatter.format(session.openingBalance)),
                  _MiniStat(label: 'Ventes', value: MoneyFormatter.format(session.salesTotal)),
                  _MiniStat(label: 'Attendu', value: MoneyFormatter.format(session.expectedCash)),
                ],
              ),
            ),
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (!isOpen)
                  Expanded(
                    child: SizedBox(
                      height: PosUi.ctaHeight - 4,
                      child: FilledButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Ouvrir shift'),
                      ),
                    ),
                  )
                else ...[
                  Expanded(
                    child: SizedBox(
                      height: PosUi.ctaHeight - 4,
                      child: OutlinedButton.icon(
                        onPressed: onMovement,
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('Mouvement'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: PosUi.ctaHeight - 4,
                      child: FilledButton.icon(
                        onPressed: onClose,
                        icon: const Icon(Icons.stop_rounded, size: 18),
                        label: const Text('Fermer'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(PosUi.radiusSm),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: PosUi.caption()),
            const SizedBox(height: 2),
            Text(value, style: PosUi.money(size: 12)),
          ],
        ),
      ),
    );
  }
}

class _SessionDetailView extends StatelessWidget {
  const _SessionDetailView({
    required this.register,
    required this.current,
    required this.history,
    required this.dateFormat,
    required this.onMovement,
  });

  final CashRegister register;
  final CurrentSessionResponse current;
  final List<CashRegisterSession> history;
  final DateFormat dateFormat;
  final VoidCallback onMovement;

  @override
  Widget build(BuildContext context) {
    final summary = current.summary;
    final session = current.session;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(register.name, style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(register.code, style: GoogleFonts.ibmPlexMono(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
        if (session != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusBadge(
                label: session.isOpen ? 'Ouvert' : 'Fermé',
                variant: StatusBadge.forSessionStatus(session.status),
              ),
              Text(
                'Depuis ${dateFormat.format(session.openedAt)}',
                style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (session.openedByName != null)
                Text(
                  session.openedByName!,
                  style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
        ],
        if (summary != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(PosUi.radiusLg),
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: Column(
              children: [
                Text('ESPÈCES ATTENDUES', style: PosUi.totalCaption()),
                const SizedBox(height: 6),
                Text(
                  MoneyFormatter.format(summary.expectedCash),
                  style: PosUi.totalAmount(size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AmountLine(label: 'Fonds d’ouverture', amount: summary.openingBalance),
          _AmountLine(label: 'Ventes', amount: summary.salesTotal),
          _AmountLine(label: 'Entrées de caisse', amount: summary.cashInTotal),
          _AmountLine(label: 'Sorties de caisse', amount: summary.cashOutTotal),
          _AmountLine(label: 'Dépenses', amount: summary.expensesTotal),
          if (summary.actualCash != null)
            _AmountLine(label: 'Comptage réel', amount: summary.actualCash!),
          if (summary.variance != null)
            _AmountLine(label: 'Écart', amount: summary.variance!, emphasize: true),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onMovement,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter un mouvement'),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text('Historique', style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (history.isEmpty)
          Text('Aucun shift précédent', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textMuted))
        else
          ...history.take(8).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dateFormat.format(item.openedAt), style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(
                              item.closedAt == null ? 'En cours' : 'Fermé ${dateFormat.format(item.closedAt!)}',
                              style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        item.variance == null ? '—' : MoneyFormatter.format(item.variance!),
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: (item.variance ?? 0) < 0 ? AppColors.danger : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.label,
    required this.amount,
    this.emphasize = false,
  });

  final String label;
  final int amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final color = emphasize
        ? (amount < 0 ? AppColors.danger : AppColors.success)
        : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 13, color: AppColors.textSecondary))),
          Text(
            MoneyFormatter.format(amount),
            style: GoogleFonts.ibmPlexMono(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
