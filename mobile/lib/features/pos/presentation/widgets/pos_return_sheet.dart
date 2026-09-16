import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/terminal_config_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../data/pos_api_service.dart';
import '../../domain/pos_models.dart';
import 'pos_ui.dart';

Future<bool?> showPosReturnSheet(
  BuildContext context, {
  PosApiService? api,
  String? initialReference,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(PosUi.radiusXl)),
    ),
    builder: (context) => PosReturnSheet(
      api: api ?? PosApiService(),
      initialReference: initialReference,
    ),
  );
}

class PosReturnSheet extends StatefulWidget {
  const PosReturnSheet({
    super.key,
    required this.api,
    this.initialReference,
  });

  final PosApiService api;
  final String? initialReference;

  @override
  State<PosReturnSheet> createState() => _PosReturnSheetState();
}

class _PosReturnSheetState extends State<PosReturnSheet> {
  final _searchCtrl = TextEditingController();

  String? _saleId;
  String? _saleReference;
  List<_ReturnLine> _lines = [];
  List<SaleReturnReason> _reasons = [];
  String _reason = 'customer_changed_mind';
  String _refundMethod = 'original';
  bool _searching = false;
  bool _submitting = false;
  String? _error;

  String get _currency => TerminalConfigRepository.instance.config.currencyCode;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialReference?.trim();
    if (initial != null && initial.isNotEmpty) {
      _searchCtrl.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
    _loadReasons();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReasons() async {
    try {
      final reasons = await widget.api.fetchReturnReasons();
      if (!mounted || reasons.isEmpty) return;
      setState(() {
        _reasons = reasons;
        _reason = reasons.first.value;
      });
    } catch (_) {}
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
      _saleId = null;
      _saleReference = null;
      _lines = [];
    });

    try {
      final list = await widget.api.fetchSales(search: query, status: 'completed');
      if (list.isEmpty) {
        setState(() {
          _error = 'Vente introuvable';
          _searching = false;
        });
        return;
      }

      Map<String, dynamic>? match;
      for (final item in list) {
        if (_text(item, const ['reference']) == query) {
          match = item;
          break;
        }
      }
      match ??= list.first;

      final saleId = _text(match, const ['id']);
      if (saleId.isEmpty) {
        setState(() {
          _error = 'Vente introuvable';
          _searching = false;
        });
        return;
      }

      final detail = await widget.api.fetchSaleDetail(saleId);
      final sale = _asMap(detail);
      final items = (_list(sale['items'])).map(_asMap).where((item) {
        return _returnableQty(item) > 0 && _text(item, const ['id']).isNotEmpty;
      }).toList();

      if (!mounted) return;
      if (items.isEmpty) {
        setState(() {
          _error = 'Rien à retourner sur cette vente';
          _searching = false;
        });
        return;
      }

      setState(() {
        _saleId = saleId;
        _saleReference = _text(sale, const ['reference'], fallback: query);
        _lines = [
          for (final item in items)
            _ReturnLine(
              saleItemId: _text(item, const ['id']),
              name: _text(item, const ['product_name', 'productName', 'name'], fallback: 'Article'),
              maxQty: _returnableQty(item),
              returning: _returnableQty(item),
              lineTotal: _amount(item, const ['line_total', 'lineTotal', 'total']),
              quantity: _amount(item, const ['quantity']),
            ),
        ];
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _searching = false;
      });
    }
  }

  int get _refundEstimate {
    return _lines.fold<int>(0, (sum, line) {
      if (line.quantity <= 0 || line.returning <= 0) return sum;
      final qty = line.returning.clamp(0, line.maxQty);
      return sum + ((line.lineTotal * qty) / line.quantity).round();
    });
  }

  Future<void> _submit() async {
    final saleId = _saleId;
    if (saleId == null) return;
    final items = [
      for (final line in _lines)
        if (line.returning > 0)
          {
            'sale_item_id': line.saleItemId,
            'quantity': line.returning,
          },
    ];
    if (items.isEmpty) {
      setState(() => _error = 'Sélectionnez au moins une quantité');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await widget.api.createSaleReturn(saleId, {
        'reason': _reason,
        'refund_method': _refundMethod,
        'items': items,
      });
      if (!mounted) return;
      final number = result.returnNumber;
      final estimate = _refundEstimate;
      Navigator.pop(context, true);
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            number.isEmpty
                ? 'Retour créé'
                : 'Retour $number · ${MoneyFormatter.format(estimate, currencyCode: _currency)}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

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
                  'Retour / remboursement',
                  style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            'Recherchez une vente par référence, puis choisissez les quantités.',
            style: PosUi.caption(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Référence vente',
                    filled: true,
                    fillColor: AppColors.fieldFill,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PosUi.radiusMd),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PosUi.radiusMd),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _searching ? null : _search,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand600,
                  minimumSize: const Size(0, PosUi.ctaHeight - 4),
                ),
                child: _searching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Chercher'),
              ),
            ],
          ),
          if (_saleReference != null) ...[
            const SizedBox(height: 10),
            Text('Vente $_saleReference', style: PosUi.body(weight: FontWeight.w700)),
          ],
          if (_lines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final line in _lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(line.name, style: PosUi.body(weight: FontWeight.w600)),
                          ),
                          IconButton(
                            onPressed: line.returning <= 0
                                ? null
                                : () => setState(() => line.returning -= 1),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('${line.returning}/${line.maxQty}', style: PosUi.money(size: 12)),
                          IconButton(
                            onPressed: line.returning >= line.maxQty
                                ? null
                                : () => setState(() => line.returning += 1),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    'Estimation : ${MoneyFormatter.format(_refundEstimate, currencyCode: _currency)}',
                    style: PosUi.caption(),
                  ),
                  const SizedBox(height: 10),
                  Text('Motif', style: PosUi.caption()),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: ValueKey('reason-$_reason'),
                    initialValue: _reason,
                    items: [
                      if (_reasons.isEmpty)
                        const DropdownMenuItem(
                          value: 'customer_changed_mind',
                          child: Text('Changement d’avis'),
                        ),
                      for (final reason in _reasons)
                        DropdownMenuItem(value: reason.value, child: Text(reason.label)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _reason = value);
                    },
                    decoration: _dropdownDecoration(),
                  ),
                  const SizedBox(height: 10),
                  Text('Mode de remboursement', style: PosUi.caption()),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: ValueKey('refund-$_refundMethod'),
                    initialValue: _refundMethod,
                    items: const [
                      DropdownMenuItem(value: 'original', child: Text('Mode d’origine')),
                      DropdownMenuItem(value: 'cash', child: Text('Espèces')),
                      DropdownMenuItem(value: 'store_credit', child: Text('Crédit magasin')),
                      DropdownMenuItem(value: 'credit', child: Text('Avoir magasin')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _refundMethod = value);
                    },
                    decoration: _dropdownDecoration(),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand600,
                      minimumSize: const Size.fromHeight(PosUi.ctaHeight - 4),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Valider le retour'),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: PosUi.caption(color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}

class _ReturnLine {
  _ReturnLine({
    required this.saleItemId,
    required this.name,
    required this.maxQty,
    required this.returning,
    required this.lineTotal,
    required this.quantity,
  });

  final String saleItemId;
  final String name;
  final int maxQty;
  int returning;
  final int lineTotal;
  final int quantity;
}

InputDecoration _dropdownDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: AppColors.fieldFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PosUi.radiusMd),
      borderSide: BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PosUi.radiusMd),
      borderSide: BorderSide(color: AppColors.border),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  try {
    final json = (value as dynamic).toJson();
    if (json is Map) return Map<String, dynamic>.from(json);
  } catch (_) {}
  return const {};
}

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  return const [];
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

int _returnableQty(Map<String, dynamic> item) {
  final returnable = _amount(item, const ['quantity_returnable', 'quantityReturnable']);
  if (returnable > 0) return returnable;
  return _amount(item, const ['quantity']);
}
