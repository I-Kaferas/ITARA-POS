import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/terminal_config_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../data/pos_api_service.dart';
import '../../domain/pos_models.dart';
import 'pos_ui.dart';

Future<bool?> showPosMergeSheet(
  BuildContext context, {
  required String saleId,
  PosApiService? api,
  String? saleReference,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(PosUi.radiusXl)),
    ),
    builder: (context) => PosMergeSheet(
      saleId: saleId,
      saleReference: saleReference,
      api: api ?? PosApiService(),
    ),
  );
}

class PosMergeSheet extends StatefulWidget {
  const PosMergeSheet({
    super.key,
    required this.saleId,
    required this.api,
    this.saleReference,
  });

  final String saleId;
  final String? saleReference;
  final PosApiService api;

  @override
  State<PosMergeSheet> createState() => _PosMergeSheetState();
}

class _PosMergeSheetState extends State<PosMergeSheet> {
  List<MergeCandidate> _candidates = [];
  final Set<String> _selected = {};
  MergePreview? _preview;
  bool _loading = true;
  bool _previewing = false;
  bool _merging = false;
  String? _error;
  bool _showPreview = false;

  String get _currency => TerminalConfigRepository.instance.config.currencyCode;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final candidates = await widget.api.mergeCandidates(widget.saleId);
      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadPreview() async {
    if (_selected.isEmpty) {
      setState(() => _error = 'Sélectionnez au moins une commande');
      return;
    }
    setState(() {
      _previewing = true;
      _error = null;
    });
    try {
      final preview = await widget.api.mergePreview(widget.saleId, _selected.toList());
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _showPreview = true;
        _previewing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _previewing = false;
      });
    }
  }

  Future<void> _confirmMerge() async {
    if (_selected.isEmpty) return;
    setState(() {
      _merging = true;
      _error = null;
    });
    try {
      await widget.api.mergeSales(widget.saleId, _selected.toList());
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Commandes fusionnées')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _merging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final reference = widget.saleReference?.trim().isNotEmpty == true
        ? widget.saleReference!.trim()
        : widget.saleId;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Fusionner les commandes',
                  style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.brand50,
              borderRadius: BorderRadius.circular(PosUi.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Commande actuelle', style: PosUi.caption()),
                const SizedBox(height: 2),
                Text(reference, style: PosUi.body(weight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: PosUi.caption(color: AppColors.danger)),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator(color: AppColors.brand500)),
            )
          else if (!_showPreview) ...[
            Text(
              'Sélectionnez une ou plusieurs commandes à fusionner.',
              style: PosUi.caption(),
            ),
            const SizedBox(height: 10),
            if (_candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Aucune commande compatible', style: PosUi.caption()),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _candidates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final candidate = _candidates[index];
                    final selected = _selected.contains(candidate.id);
                    return Material(
                      color: selected ? AppColors.brand50 : AppColors.fieldFill,
                      borderRadius: BorderRadius.circular(PosUi.radiusMd),
                      child: CheckboxListTile(
                        value: selected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selected.add(candidate.id);
                            } else {
                              _selected.remove(candidate.id);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          candidate.reference,
                          style: GoogleFonts.ibmPlexMono(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        subtitle: Text(
                          [
                            if ((candidate.table?['name']?.toString() ?? '').isNotEmpty)
                              candidate.table!['name'].toString(),
                            if ((candidate.customer?['name']?.toString() ?? '').isNotEmpty)
                              candidate.customer!['name'].toString(),
                            MoneyFormatter.format(candidate.total, currencyCode: _currency),
                            if ((candidate.itemCount ?? 0) > 0) '${candidate.itemCount} art.',
                          ].join(' · '),
                          style: PosUi.caption(),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(PosUi.radiusMd),
                          side: BorderSide(
                            color: selected ? AppColors.brand200 : AppColors.border,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _previewing || _selected.isEmpty ? null : _loadPreview,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand600),
                    child: _previewing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Aperçu'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text('Aperçu de la fusion', style: PosUi.cardTitle()),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    '${_selected.length} commande(s) sélectionnée(s)',
                    style: PosUi.caption(),
                  ),
                  const SizedBox(height: 8),
                  for (final line in _previewLines(_preview))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(line.$1, style: PosUi.body())),
                          Text('×${line.$2}', style: PosUi.money(size: 12)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Total : ${MoneyFormatter.format(_previewTotal(_preview), currencyCode: _currency)}',
                    style: PosUi.money(size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _merging
                        ? null
                        : () => setState(() {
                              _showPreview = false;
                              _preview = null;
                            }),
                    child: const Text('Retour'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _merging ? null : _confirmMerge,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand600),
                    child: _merging
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Confirmer'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<(String, int)> _previewLines(MergePreview? preview) {
    if (preview == null) return const [];
    return [
      for (final item in preview.items)
        (
          _text(item, const ['product_name', 'productName', 'name'], fallback: 'Article'),
          _amount(item, const ['quantity']),
        ),
    ];
  }

  int _previewTotal(MergePreview? preview) {
    if (preview == null) return 0;
    return _amount(preview.totals, const ['total']);
  }
}

String _text(Map<String, dynamic> map, List<String> keys, {String fallback = ''}) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

int _amount(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.round();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}
