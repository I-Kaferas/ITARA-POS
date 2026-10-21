import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../sync/offline_store.dart';
import '../../auth/data/pin_auth_service.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/loading_error_view.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import '../data/local_shifts_store.dart';
import '../domain/shift_models.dart';
import '../services/shift_z_report_printer.dart';
import 'shift_close_gate.dart';
import 'shift_detail_sheet.dart';
import 'shift_handover_dialog.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

class ShiftsScreen extends StatefulWidget {
  const ShiftsScreen({super.key});

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  final _api = LocalShiftsStore.instance;
  final _search = TextEditingController();

  List<CashRegister> _registers = [];
  List<({CashRegister register, CashRegisterSession session})> _shifts = [];
  Map<String, SessionSummary> _summaries = {};
  bool _loading = true;
  String? _error;
  int _lane = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final registers = await _api.fetchRegisters();
      final shifts = <({CashRegister register, CashRegisterSession session})>[];
      for (final register in registers) {
        final sessions = await _api.fetchSessions(register.id);
        for (final session in sessions) {
          shifts.add((register: register, session: session));
        }
      }
      shifts.sort((a, b) => b.session.openedAt.compareTo(a.session.openedAt));
      final summaries = <String, SessionSummary>{};
      for (final shift in shifts) {
        summaries[shift.session.id] = await _api.summaryFor(shift.session);
      }
      setState(() {
        _registers = registers;
        _shifts = shifts;
        _summaries = summaries;
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
      SnackBar(content: Text(tr(message))),
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

  ({CashRegister register, CashRegisterSession session})? get _myOpenShift {
    final cashierId = TerminalConfigRepository.instance.config.cashierId.trim();
    if (cashierId.isEmpty) return null;
    for (final shift in _shifts) {
      if (!shift.session.isOpen) continue;
      final owner = shift.session.openedById?.trim() ?? '';
      if (owner == cashierId) return shift;
    }
    return null;
  }

  Future<void> _openSession(CashRegister register) async {
    if (!TerminalConfigRepository.instance.config.canOpenShift) {
      _showMessage('Seul un caissier peut ouvrir un shift.');
      return;
    }
    if (_myOpenShift != null) {
      _showMessage('Close your current shift before opening another.');
      return;
    }
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
                Text(tr('Ouvrir le shift'), style: AppTypography.text(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${register.name} · ${register.code}', style: PosUi.caption()),
                const SizedBox(height: 14),
                TextField(
                  controller: balanceCtrl,
                  decoration: InputDecoration(
                    labelText: trf('Fonds initial ({0})', [AppConfig.currencyCode]),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(labelText: tr('Notes (optionnel)')),
                  maxLines: 2,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Annuler')))),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: PosUi.ctaHeight - 4,
                        child: FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Ouvrir'))),
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
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
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
    final unpaid = (current.summary?.invoices ?? []).where(_invoiceUnpaid).toList();
    final holds = OfflineStore.instance.holdsForStore(
      await OfflineStore.instance.loadLocalHolds(),
      TerminalConfigRepository.instance.config.storeId,
    );
    if (!mounted) return;
    final proceed = await showShiftCloseGate(context, unpaid: unpaid, holds: holds);
    if (!proceed || !mounted) return;

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
          constraints: BoxConstraints(maxWidth: 520, maxHeight: MediaQuery.sizeOf(context).height * 0.88),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('Fermer le shift'), style: AppTypography.text(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(tr(register.name), style: PosUi.caption()),
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
                      Text(tr('ESPÈCES ATTENDUES'), style: PosUi.totalCaption()),
                      const SizedBox(height: 6),
                      Text(tr(MoneyFormatter.format(expected)), style: PosUi.totalAmount(size: 26)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _UnpaidOrdersPanel(invoices: unpaid, holds: holds),
                const SizedBox(height: 14),
                TextField(
                  controller: actualCtrl,
                  decoration: InputDecoration(
                    labelText: trf('Espèces comptées ({0})', [AppConfig.currencyCode]),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  decoration: InputDecoration(labelText: tr('PIN caissier')),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(labelText: tr('Notes de clôture')),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: varianceCtrl,
                  decoration: InputDecoration(labelText: tr('Motif d’écart (si besoin)')),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Annuler')))),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: PosUi.ctaHeight - 4,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                          child: Text(tr('Fermer shift')),
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
      final config = TerminalConfigRepository.instance.config;
      if (pin.isNotEmpty &&
          config.pinVerifier.isNotEmpty &&
          PinAuthService.pinVerifier(config.cashierId, pin) != config.pinVerifier) {
        _showMessage('PIN refusé');
        return;
      }
      final variance = varianceCtrl.text.trim();
      final notes = [
        notesCtrl.text.trim(),
        if (variance.isNotEmpty) variance,
      ].where((part) => part.isNotEmpty).join('\n');
      SessionSummary? report = current.summary;
      final closed = await _api.closeSession(
        registerId: register.id,
        actualCash: counted,
        notes: notes,
      );
      report = closed.zReport ?? closed.summary ?? report;
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
            title: Text(tr('Rapport de shift')),
            content: Text(tr('Voulez-vous imprimer le rapport de clôture ?')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Non'))),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Imprimer'))),
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

  Future<void> _printSessionReport(CashRegister register, CashRegisterSession session) async {
    try {
      final day = DateFormat('yyyyMMdd').format(session.openedAt.toLocal());
      final compact = session.id.replaceAll('-', '');
      final tail = compact.length <= 4 ? compact : compact.substring(compact.length - 4);
      final report = await _api.sessionPerformance(
        session,
        sessionCode: 'SH-$day-$tail',
        registerName: register.name,
      );
      await ShiftZReportPrinter().printSessionReport(report);
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _showSessionDetail(CashRegister register, CashRegisterSession session) async {
    try {
      final summary = _summaries[session.id] ?? await _api.summaryFor(session);
      if (!mounted) return;
      final current = CurrentSessionResponse(session: session, summary: summary, zReport: summary);

      final detail = ShiftDetailSheet(
        register: register,
        current: current,
        onRefresh: () async {
          final next = await _api.summaryFor(session);
          return CurrentSessionResponse(session: session, summary: next, zReport: next);
        },
        onCloseShift: session.isOpen
            ? () {
                Navigator.of(context).pop();
                _closeSession(register);
              }
            : null,
        onSituation: () async {
          try {
          final latest = await _api.summaryFor(session);
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              backgroundColor: PosUi.deskPanel,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              child: SizedBox(
                width: 980,
                height: MediaQuery.sizeOf(context).height * 0.88,
                child: ShiftHandoverDialog(
                  session: session,
                  summary: latest,
                  onReload: () => _api.summaryFor(session),
                ),
              ),
            ),
          );
          } catch (error) {
            _showMessage(error.toString());
          }
        },
      );
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: PosUi.deskPanel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: SizedBox(width: 480, height: 700, child: detail),
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
                  Text(tr('Mouvement de caisse'), style: AppTypography.text(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey(selectedType),
                    initialValue: selectedType,
                    decoration: InputDecoration(labelText: tr('Type')),
                    items: types
                        .map((t) => DropdownMenuItem(
                              value: t.value,
                              child: Text(tr(t.labelFr.isNotEmpty ? t.labelFr : t.label)),
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
                      labelText: trf('Montant ({0})', [AppConfig.currencyCode]),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(labelText: tr('Description')),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Annuler')))),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: PosUi.ctaHeight - 4,
                          child: FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Enregistrer'))),
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

  Future<void> _startShift() async {
    if (!TerminalConfigRepository.instance.config.canOpenShift) {
      _showMessage('Seul un caissier peut ouvrir un shift.');
      return;
    }
    if (_myOpenShift != null) {
      _showMessage('Close your current shift before opening another.');
      return;
    }
    var idle = _registers.where((register) => !register.hasOpenSession).toList();
    if (idle.isEmpty) {
      final defaults = _nextRegisterDefaults();
      try {
        final created = await _api.createRegister(name: defaults.name, code: defaults.code);
        await _load();
        idle = _registers.where((register) => register.id == created.id).toList();
      } catch (e) {
        _showMessage(e.toString());
        return;
      }
    }
    if (idle.isEmpty || !mounted) return;
    await _openSession(idle.first);
  }

  @override
  Widget build(BuildContext context) {
    final config = TerminalConfigRepository.instance.config;
    final canManage = config.canManageShifts;
    final canOpen = config.canOpenShift;
    final cashierId = config.cashierId.trim();
    final query = _search.text.trim().toLowerCase();
    bool matches(String value) => query.isEmpty || value.toLowerCase().contains(query);
    bool isMine(CashRegisterSession? session) {
      if (cashierId.isEmpty || session == null) return false;
      return (session.openedById?.trim() ?? '') == cashierId;
    }

    final active = _registers.where((register) {
      if (!register.hasOpenSession) return false;
      final session = register.openSession;
      if (!config.isAdmin && !isMine(session)) return false;
      return matches('${register.name} ${register.code} ${session?.openedByName ?? ''}');
    }).toList();
    final closed = _shifts.where((shift) {
      if (shift.session.isOpen) return false;
      if (!config.isAdmin && !isMine(shift.session)) return false;
      return matches('${shift.register.name} ${shift.register.code} ${shift.session.openedByName ?? ''}');
    }).toList();
    final showActive = _lane != 2;
    final showClosed = _lane != 1;
    final visibleActive = showActive ? active : const <CashRegister>[];
    final visibleClosed = showClosed ? closed : const <({CashRegister register, CashRegisterSession session})>[];
    final activeCount = _shifts.where((shift) => shift.session.isOpen).length;
    final closedCount = _shifts.where((shift) => !shift.session.isOpen).length;
    final empty = visibleActive.isEmpty && visibleClosed.isEmpty;

    final mine = _myOpenShift;
    return ColoredBox(
      color: PosUi.deskNight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SlaveModeBanner(
            message: tr('Les shifts sont gérés par le terminal Master.'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _ShiftsChrome(
              search: _search,
              lane: _lane,
              activeCount: activeCount,
              closedCount: closedCount,
              totalCount: _shifts.length,
              refreshing: _loading,
              onLane: (value) => setState(() => _lane = value),
              onSearch: (_) => setState(() {}),
              onRefresh: _loading ? null : _load,
              onOpen: canOpen && mine == null ? () => _startShift() : null,
              onClose: canManage && mine != null ? () => _closeSession(mine.register) : null,
            ),
          ),
          Expanded(
            child: !canManage
                ? const RoleGuard(
                    allowed: false,
                    fallbackMessage: 'Seul le terminal Master peut ouvrir, fermer et créer des shifts.',
                    child: SizedBox.shrink(),
                  )
                : _loading
                    ? LoadingView(message: tr('Loading shifts...'))
                    : _error != null
                        ? ErrorView(message: _error!, onRetry: _load)
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: AppColors.brandInk,
                            child: empty
                                ? LayoutBuilder(
                                    builder: (context, constraints) => ListView(
                                      children: [
                                        SizedBox(
                                          height: constraints.maxHeight,
                                          child: _ShiftsEmpty(onStart: canOpen ? _startShift : null),
                                        ),
                                      ],
                                    ),
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      final items = [
                                        if (showActive)
                                          for (final register in visibleActive)
                                            (register: register, session: register.openSession!),
                                        ...visibleClosed,
                                      ];
                                      const gap = 12.0;
                                      final width = constraints.maxWidth - 40;
                                      final columns = width >= 1100 ? 3 : (width >= 300 ? 2 : 1);
                                      final tileWidth = (width - gap * (columns - 1)) / columns;
                                      final compact = tileWidth < 360;
                                      return ListView(
                                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                                        children: [
                                          for (var start = 0; start < items.length; start += columns) ...[
                                            if (start > 0) const SizedBox(height: gap),
                                            IntrinsicHeight(
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  for (var i = start; i < start + columns; i++) ...[
                                                    if (i > start) const SizedBox(width: gap),
                                                    Expanded(
                                                      child: i < items.length
                                                          ? _WorkShiftCard(
                                                              register: items[i].register,
                                                              session: items[i].session,
                                                              summary: _summaries[items[i].session.id],
                                                              compact: compact,
                                                              onDetail: () => _showSessionDetail(items[i].register, items[i].session),
                                                              onClose: items[i].session.isOpen
                                                                  ? () => _closeSession(items[i].register)
                                                                  : null,
                                                              onMovement: items[i].session.isOpen
                                                                  ? () => _recordMovement(items[i].register)
                                                                  : null,
                                                              onPrintReport: items[i].session.isOpen
                                                                  ? null
                                                                  : () => _printSessionReport(items[i].register, items[i].session),
                                                            )
                                                          : const SizedBox.shrink(),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      );
                                    },
                                  ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ShiftsChrome extends StatelessWidget {
  const _ShiftsChrome({
    required this.search,
    required this.lane,
    required this.activeCount,
    required this.closedCount,
    required this.totalCount,
    required this.refreshing,
    required this.onLane,
    required this.onSearch,
    required this.onRefresh,
    this.onOpen,
    this.onClose,
  });

  final TextEditingController search;
  final int lane;
  final int activeCount;
  final int closedCount;
  final int totalCount;
  final bool refreshing;
  final ValueChanged<int> onLane;
  final ValueChanged<String> onSearch;
  final VoidCallback? onRefresh;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final stats = [
      _ShiftStat(
        icon: Icons.circle,
        iconColor: PosUi.deskStock,
        iconBg: PosUi.deskSuccessBg,
        value: '$activeCount',
        label: tr('Active Shifts'),
      ),
      _ShiftStat(
        icon: Icons.stop_rounded,
        iconColor: PosUi.deskMuted,
        iconBg: PosUi.deskRaised,
        value: '$closedCount',
        label: tr('Closed Shifts'),
      ),
      _ShiftStat(
        icon: Icons.grid_view_rounded,
        iconColor: PosUi.deskAccent,
        iconBg: PosUi.deskRaised,
        value: '$totalCount',
        label: tr('total shifts'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: PosUi.deskAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.schedule_rounded, color: PosUi.deskInk, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Work Shifts'),
                    style: AppTypography.text(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: PosUi.deskText,
                    ),
                  ),
                  Text(
                    tr('Manage work shifts, track cash flow and reconcile'),
                    style: AppTypography.text(fontSize: 13, color: PosUi.deskMuted),
                  ),
                ],
              ),
            ),
            if (wide && onClose != null) ...[
              FilledButton.icon(
                onPressed: onClose,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE23D3D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.stop_rounded, size: 16),
                label: Text(tr('Close Shift'), style: AppTypography.text(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 8),
            ],
            if (wide && onOpen != null) ...[
              FilledButton.icon(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: PosUi.deskAccent,
                  foregroundColor: PosUi.deskInk,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(tr('Open Shift'), style: AppTypography.text(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 8),
            ],
            OutlinedButton.icon(
              onPressed: onRefresh,
              style: OutlinedButton.styleFrom(
                foregroundColor: PosUi.deskText,
                backgroundColor: PosUi.deskCard,
                side: BorderSide(color: PosUi.deskLine),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: refreshing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: Text(tr('Refresh'), style: AppTypography.text(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
        if (!wide && (onClose != null || onOpen != null)) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: onClose ?? onOpen,
              style: FilledButton.styleFrom(
                backgroundColor: onClose != null ? const Color(0xFFE23D3D) : PosUi.deskAccent,
                foregroundColor: onClose != null ? Colors.white : PosUi.deskInk,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(onClose != null ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 18),
              label: Text(
                tr(onClose != null ? 'Close Shift' : 'Open Shift'),
                style: AppTypography.text(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (wide)
          Row(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: stats[i]),
              ],
            ],
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: stats[i].asCompact()),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        if (wide)
          Row(
            children: [
              _ShiftFilters(lane: lane, onLane: onLane),
              const Spacer(),
              SizedBox(width: 280, child: _ShiftSearch(search: search, onSearch: onSearch)),
            ],
          )
        else ...[
          _ShiftFilters(lane: lane, onLane: onLane),
          const SizedBox(height: 10),
          _ShiftSearch(search: search, onSearch: onSearch),
        ],
      ],
    );
  }
}

class _ShiftStat extends StatelessWidget {
  const _ShiftStat({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  final bool compact;

  _ShiftStat asCompact() => _ShiftStat(
        icon: icon,
        iconColor: iconColor,
        iconBg: iconBg,
        value: value,
        label: label,
        compact: true,
      );

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PosUi.deskCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PosUi.deskLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 15, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              tr(value),
              style: AppTypography.text(fontSize: 19, fontWeight: FontWeight.w800, color: PosUi.deskText),
            ),
            Text(
              tr(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.text(fontSize: 11, color: PosUi.deskMuted),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: PosUi.deskCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(value),
                  style: AppTypography.text(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: PosUi.deskText,
                  ),
                ),
                Text(tr(label), style: AppTypography.text(fontSize: 12, color: PosUi.deskMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftFilters extends StatelessWidget {
  const _ShiftFilters({required this.lane, required this.onLane});

  final int lane;
  final ValueChanged<int> onLane;

  static const _labels = ['All', 'Active', 'Closed'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: lane == i ? PosUi.deskAccent : PosUi.deskCard,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => onLane(i),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: lane == i ? PosUi.deskAccent : PosUi.deskLine),
                  ),
                  child: Text(
                    tr(_labels[i]),
                    style: AppTypography.text(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: lane == i ? PosUi.deskInk : PosUi.deskMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ShiftSearch extends StatelessWidget {
  const _ShiftSearch({required this.search, required this.onSearch});

  final TextEditingController search;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: search,
      onChanged: onSearch,
      style: AppTypography.text(fontSize: 14, color: PosUi.deskText),
      decoration: InputDecoration(
        hintText: tr('Search shifts...'),
        hintStyle: AppTypography.text(color: PosUi.deskMuted, fontSize: 14),
        prefixIcon: Icon(Icons.search, color: PosUi.deskMuted, size: 20),
        filled: true,
        fillColor: PosUi.deskCard,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: PosUi.deskLine)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: PosUi.deskLine)),
        focusedBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: PosUi.deskAccent)),
      ),
    );
  }
}

class _ShiftsEmpty extends StatelessWidget {
  const _ShiftsEmpty({this.onStart});

  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.schedule_outlined, size: 42, color: PosUi.deskMuted),
        const SizedBox(height: 16),
        Text(
          tr('No shifts yet'),
          style: AppTypography.text(fontSize: 18, fontWeight: FontWeight.w800, color: PosUi.deskText),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: onStart,
          child: Text(
            tr('Count your opening cash and start your shift'),
            style: AppTypography.text(fontSize: 13, color: PosUi.deskMuted),
          ),
        ),
      ],
    );
  }
}

class _WorkShiftCard extends StatelessWidget {
  const _WorkShiftCard({
    required this.register,
    required this.session,
    required this.onDetail,
    this.summary,
    this.onClose,
    this.onMovement,
    this.onPrintReport,
    this.compact = false,
  });

  final CashRegister register;
  final CashRegisterSession session;
  final SessionSummary? summary;
  final VoidCallback onDetail;
  final VoidCallback? onClose;
  final VoidCallback? onMovement;
  final VoidCallback? onPrintReport;
  final bool compact;

  String get _code {
    final day = DateFormat('yyyyMMdd').format(session.openedAt.toLocal());
    final compact = session.id.replaceAll('-', '');
    final tail = compact.length <= 4 ? compact : compact.substring(compact.length - 4);
    return 'SH-$day-$tail';
  }

  String get _duration {
    final end = session.closedAt ?? DateTime.now();
    final minutes = end.difference(session.openedAt).inMinutes.abs();
    if (minutes < 60) return '${minutes}min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return '${hours}h';
    return '${hours}h ${rest}min';
  }

  @override
  Widget build(BuildContext context) {
    final open = session.isOpen;
    final sales = summary?.salesTotal ?? session.salesTotal;
    final orders = summary?.invoicesCount ?? 0;
    final cashier = (session.openedByName ?? '').trim().isEmpty ? 'Cashier' : session.openedByName!.trim();
    final time = DateFormat('HH:mm').format(session.openedAt.toLocal());

    final indent = compact ? 0.0 : 20.0;
    final metrics = [
      _Metric(value: MoneyFormatter.format(session.openingBalance), label: tr('Opening'), compact: compact),
      _Metric(value: MoneyFormatter.format(sales), label: tr('Sales'), valueColor: PosUi.deskStock, compact: compact),
      _Metric(value: '$orders', label: tr('Orders'), compact: compact),
      _Metric(value: _duration, label: tr('Duration'), valueColor: PosUi.deskAccent, compact: compact),
    ];

    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: open ? PosUi.deskStock : PosUi.deskMuted,
        shape: BoxShape.circle,
      ),
    );
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: open ? PosUi.deskSuccessBg : PosUi.deskRaised,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tr(open ? 'Active' : 'Closed'),
        style: AppTypography.text(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: open ? PosUi.deskStock : PosUi.deskMuted,
        ),
      ),
    );
    final code = Text(
      tr(_code),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.text(
        fontSize: compact ? 13.5 : 16,
        fontWeight: FontWeight.w800,
        color: PosUi.deskText,
      ),
    );
    final menu = PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, color: PosUi.deskMuted),
      color: PosUi.deskPanel,
      padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 220),
      onSelected: (value) {
        switch (value) {
          case 'detail':
            onDetail();
          case 'movement':
            onMovement?.call();
          case 'report':
            onPrintReport?.call();
          case 'close':
            onClose?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'detail', child: Text(tr('Details'))),
        if (onMovement != null) PopupMenuItem(value: 'movement', child: Text(tr('Cash movement'))),
        if (onPrintReport != null) PopupMenuItem(value: 'report', child: Text(tr('Imprimer le rapport de session'))),
        if (onClose != null) PopupMenuItem(value: 'close', child: Text(tr('Close shift'))),
      ],
    );

    return Material(
      color: PosUi.deskCard,
      child: InkWell(
        onTap: onDetail,
        child: Padding(
          padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 14, compact ? 8 : 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact) ...[
                Row(
                  children: [
                    dot,
                    const SizedBox(width: 8),
                    badge,
                    const Spacer(),
                    SizedBox(width: 36, height: 36, child: menu),
                  ],
                ),
                Padding(padding: const EdgeInsets.only(right: 10), child: code),
              ] else
                Row(
                  children: [
                    dot,
                    const SizedBox(width: 10),
                    Flexible(child: code),
                    const SizedBox(width: 8),
                    badge,
                    const Spacer(),
                    menu,
                  ],
                ),
              const SizedBox(height: 6),
              Padding(
                padding: EdgeInsets.only(left: indent, right: compact ? 10 : 0),
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: PosUi.deskMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        tr(cashier),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.text(fontSize: 12, color: PosUi.deskMuted),
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 12),
                    Icon(Icons.schedule, size: 14, color: PosUi.deskMuted),
                    const SizedBox(width: 4),
                    Text(tr(time), style: AppTypography.text(fontSize: 12, color: PosUi.deskMuted)),
                  ],
                ),
              ),
              SizedBox(height: compact ? 10 : 14),
              Padding(
                padding: EdgeInsets.only(left: indent, right: compact ? 10 : 12),
                child: compact
                    ? Column(
                        children: [
                          for (var i = 0; i < metrics.length; i++) ...[
                            if (i > 0) const SizedBox(height: 4),
                            metrics[i],
                          ],
                        ],
                      )
                    : Row(children: [for (final metric in metrics) Expanded(child: metric)]),
              ),
              const Spacer(),
              SizedBox(height: compact ? 10 : 12),
              Padding(
                padding: EdgeInsets.only(left: indent, right: compact ? 10 : 0),
                child: Row(
                  children: [
                    Icon(Icons.storefront_outlined, size: 14, color: PosUi.deskAccent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tr(register.name.toUpperCase()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.text(fontSize: 12, fontWeight: FontWeight.w700, color: PosUi.deskAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, this.valueColor, this.compact = false});

  final String value;
  final String label;
  final Color? valueColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      tr(value),
      maxLines: 1,
      style: AppTypography.text(
        fontSize: compact ? 13 : 15,
        fontWeight: FontWeight.w800,
        color: valueColor ?? PosUi.deskText,
      ),
    );
    final labelText = Text(tr(label), style: AppTypography.text(fontSize: 11, color: PosUi.deskMuted));

    if (compact) {
      return Row(
        children: [
          labelText,
          const SizedBox(width: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: valueText,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: valueText),
        const SizedBox(height: 2),
        labelText,
      ],
    );
  }
}

bool _invoiceUnpaid(ShiftInvoice invoice) {
  if (invoice.outstanding > 0) return true;
  final method = (invoice.method ?? '').toLowerCase();
  return method == 'credit' || method == 'on_credit' || method == 'unpaid';
}

int _holdTotal(Map<String, dynamic> hold) {
  final items = hold['items'];
  if (items is! List) return 0;
  var sum = 0;
  for (final raw in items) {
    if (raw is! Map) continue;
    final quantity = raw['quantity'] is num
        ? (raw['quantity'] as num).round()
        : int.tryParse('${raw['quantity']}') ?? 1;
    final price = raw['unit_price'] is num
        ? (raw['unit_price'] as num).round()
        : int.tryParse('${raw['unit_price']}') ?? 0;
    final discount = raw['line_discount_fixed'] is num ? (raw['line_discount_fixed'] as num).round() : 0;
    sum += price * (quantity < 1 ? 1 : quantity) - discount;
  }
  final ticketDiscount = hold['discount_amount'];
  if (ticketDiscount is num) sum -= ticketDiscount.round();
  return sum < 0 ? 0 : sum;
}

String _holdLabel(Map<String, dynamic> hold) {
  final label = hold['label']?.toString().trim() ?? '';
  if (label.isNotEmpty) return label;
  final table = hold['table_label']?.toString().trim() ?? '';
  if (table.isNotEmpty) return table;
  final customer = hold['customer'];
  if (customer is Map) {
    final name = customer['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
  }
  return tr('Commande ouverte');
}

class _UnpaidOrdersPanel extends StatelessWidget {
  const _UnpaidOrdersPanel({required this.invoices, required this.holds});

  final List<ShiftInvoice> invoices;
  final List<Map<String, dynamic>> holds;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String, int)>[
      for (final invoice in invoices)
        (
          invoice.reference.isEmpty ? tr('Vente') : invoice.reference,
          invoice.customerName?.trim().isNotEmpty == true
              ? invoice.customerName!.trim()
              : tr(invoice.method ?? 'impayée'),
          invoice.outstanding > 0 ? invoice.outstanding : invoice.total,
        ),
      for (final hold in holds) (_holdLabel(hold), tr('Encaissement en attente'), _holdTotal(hold)),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: rows.isEmpty ? AppColors.fieldFill : AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(PosUi.radiusMd),
        border: Border.all(color: rows.isEmpty ? AppColors.border : AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            trf('Commandes non payées ({0})', [rows.length]),
            style: AppTypography.text(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                tr('Aucune commande impayée sur ce shift.'),
                style: AppTypography.text(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            )
          else
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.text(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            row.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.text(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      MoneyFormatter.format(row.$3),
                      style: AppTypography.text(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.warning),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
