import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import 'pos_ui.dart';

class PosGateRegister {
  const PosGateRegister({
    required this.id,
    required this.name,
    this.code,
  });

  final String id;
  final String name;
  final String? code;

  String get label {
    final codeText = code?.trim();
    if (codeText == null || codeText.isEmpty) return name;
    return '$name ($codeText)';
  }
}

class PosSessionGate extends StatefulWidget {
  const PosSessionGate({
    super.key,
    required this.registers,
    required this.currentShiftOpen,
    required this.loading,
    required this.onOpen,
    required this.onRefresh,
  });

  final List<PosGateRegister> registers;
  final bool currentShiftOpen;
  final bool loading;
  final Future<void> Function(String pin, String registerId, int openingFloat) onOpen;
  final Future<void> Function() onRefresh;

  @override
  State<PosSessionGate> createState() => _PosSessionGateState();
}

class _PosSessionGateState extends State<PosSessionGate> {
  final _pinCtrl = TextEditingController();
  final _floatCtrl = TextEditingController(text: '0');
  String? _registerId;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _syncRegister();
  }

  @override
  void didUpdateWidget(covariant PosSessionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registers != widget.registers) {
      _syncRegister();
    }
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  void _syncRegister() {
    final registers = widget.registers;
    if (registers.isEmpty) {
      _registerId = null;
      return;
    }
    if (_registerId == null || !registers.any((item) => item.id == _registerId)) {
      _registerId = registers.first.id;
    }
  }

  int _parseOpeningFloat(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return 0;
    final major = double.tryParse(normalized) ?? 0;
    return (major * 100).round();
  }

  Future<void> _submit() async {
    final pin = _pinCtrl.text.trim();
    final registerId = _registerId;
    setState(() => _error = null);

    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      setState(() => _error = 'Code PIN invalide (4 à 6 chiffres)');
      return;
    }
    if (registerId == null || registerId.isEmpty) {
      setState(() => _error = 'Aucune caisse disponible');
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.onOpen(pin, registerId, _parseOpeningFloat(_floatCtrl.text));
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentShiftOpen) return const SizedBox.shrink();

    final busy = widget.loading || _submitting;

    return SizedBox.expand(
      child: Material(
        color: const Color(0x730F172A),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                margin: const EdgeInsets.all(PosUi.spaceLg),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(PosUi.radiusXl),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A0F172A),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ouvrir la caisse',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualiser',
                        onPressed: busy ? null : () => widget.onRefresh(),
                        icon: widget.loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saisissez votre PIN et sélectionnez une caisse pour démarrer le service.',
                    style: PosUi.caption(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: PosUi.spaceLg),
                  Text('Caisse', style: PosUi.sectionLabel()),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_registerId ?? 'register'),
                    initialValue: _registerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: widget.registers
                        .map(
                          (register) => DropdownMenuItem(
                            value: register.id,
                            child: Text(register.label, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: busy || widget.registers.isEmpty
                        ? null
                        : (value) => setState(() => _registerId = value),
                  ),
                  if (widget.registers.isEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Aucune caisse configurée',
                      style: PosUi.caption(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: PosUi.spaceMd),
                  Text('Code PIN', style: PosUi.sectionLabel()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _pinCtrl,
                    obscureText: true,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      counterText: '',
                      isDense: true,
                    ),
                    onSubmitted: (_) => busy ? null : _submit(),
                  ),
                  const SizedBox(height: PosUi.spaceMd),
                  Text('Fonds d\'ouverture', style: PosUi.sectionLabel()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _floatCtrl,
                    enabled: !busy,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: PosUi.spaceSm),
                    Text(_error!, style: PosUi.caption(color: AppColors.danger)),
                  ],
                  const SizedBox(height: PosUi.spaceLg),
                  SizedBox(
                    height: PosUi.ctaHeight,
                    child: FilledButton(
                      onPressed: busy || widget.registers.isEmpty ? null : _submit,
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Ouvrir la caisse',
                              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
