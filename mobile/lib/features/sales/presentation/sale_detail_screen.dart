import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/loading_error_view.dart';
import '../../pos/data/pos_api_service.dart';
import '../../pos/domain/pos_models.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import '../../receipt/domain/receipt_models.dart';
import '../../receipt/services/receipt_print_service.dart';

class SaleDetailScreen extends StatefulWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final String saleId;

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  final _api = PosApiService();
  final _printer = ReceiptPrintService();
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  Map<String, dynamic>? _sale;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  String get _currency {
    final fromSale = _sale?['currency']?.toString();
    if (fromSale != null && fromSale.isNotEmpty) return fromSale;
    return TerminalConfigRepository.instance.config.currencyCode;
  }

  String _money(int amount) => MoneyFormatter.format(amount, currencyCode: _currency);

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
      final sale = await _api.fetchSaleDetail(widget.saleId);
      if (!mounted) return;
      setState(() {
        _sale = _asMap(sale);
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

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _issueDocument({
    required Future<dynamic> Function() create,
    required String successLabel,
  }) async {
    setState(() => _busy = true);
    try {
      final result = await create();
      final payload = _extractPayload(result);
      if (payload != null) {
        await _printer.print(payload);
        _snack('$successLabel imprimé');
      } else {
        _snack('$successLabel créé avec succès');
      }
    } catch (error) {
      _snack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printReceipt() {
    return _issueDocument(
      create: () => _api.createReceipt(widget.saleId),
      successLabel: 'Reçu',
    );
  }

  Future<void> _printInvoice() {
    return _issueDocument(
      create: () => _api.createInvoice(widget.saleId),
      successLabel: 'Facture',
    );
  }

  Future<void> _openReturnDialog() async {
    final sale = _sale;
    if (sale == null) return;

    final items = (_list(sale['items']))
        .map(_asMap)
        .where((item) => _text(item, const ['id']).isNotEmpty)
        .toList();
    if (items.isEmpty) {
      _snack('Aucune ligne à retourner');
      return;
    }

    List<SaleReturnReason> reasons = const [];
    try {
      reasons = await _api.fetchReturnReasons();
    } catch (_) {}

    if (!mounted) return;

    final quantities = <String, int>{
      for (final item in items) _text(item, const ['id']): 0,
    };
    var reason = reasons.isNotEmpty ? reasons.first.value : 'customer_changed_mind';
    var refundMethod = 'cash';
    final notesCtrl = TextEditingController();
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Dialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PosUi.radiusXl)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Créer un retour',
                        style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          children: [
                            for (final item in items)
                              _ReturnQtyTile(
                                label: _itemName(item),
                                maxQty: _returnableQty(item),
                                value: quantities[_text(item, const ['id'])] ?? 0,
                                onChanged: (value) {
                                  setLocal(() {
                                    quantities[_text(item, const ['id'])] = value;
                                  });
                                },
                              ),
                            const SizedBox(height: 8),
                            Text('Motif', style: PosUi.caption()),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              key: ValueKey('reason-$reason'),
                              initialValue: reason,
                              items: [
                                if (reasons.isEmpty)
                                  const DropdownMenuItem(
                                    value: 'customer_changed_mind',
                                    child: Text('Changement d’avis'),
                                  ),
                                for (final item in reasons)
                                  DropdownMenuItem(value: item.value, child: Text(item.label)),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setLocal(() => reason = value);
                              },
                              decoration: _fieldDecoration(),
                            ),
                            const SizedBox(height: 10),
                            Text('Remboursement', style: PosUi.caption()),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              key: ValueKey('refund-$refundMethod'),
                              initialValue: refundMethod,
                              items: const [
                                DropdownMenuItem(value: 'cash', child: Text('Espèces')),
                                DropdownMenuItem(value: 'original', child: Text('Mode d’origine')),
                                DropdownMenuItem(value: 'credit', child: Text('Avoir magasin')),
                                DropdownMenuItem(value: 'store_credit', child: Text('Crédit magasin')),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setLocal(() => refundMethod = value);
                              },
                              decoration: _fieldDecoration(),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: notesCtrl,
                              maxLines: 2,
                              decoration: _fieldDecoration(hint: 'Notes (optionnel)'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: submitting ? null : () => Navigator.pop(context),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: submitting
                                  ? null
                                  : () async {
                                      final selected = quantities.entries
                                          .where((entry) => entry.value > 0)
                                          .map(
                                            (entry) => {
                                              'sale_item_id': entry.key,
                                              'quantity': entry.value,
                                            },
                                          )
                                          .toList();
                                      if (selected.isEmpty) {
                                        _snack('Sélectionnez au moins une quantité');
                                        return;
                                      }
                                      setLocal(() => submitting = true);
                                      try {
                                        await _api.createSaleReturn(widget.saleId, {
                                          'reason': reason,
                                          'refund_method': refundMethod,
                                          if (notesCtrl.text.trim().isNotEmpty) 'notes': notesCtrl.text.trim(),
                                          'items': selected,
                                        });
                                        if (context.mounted) Navigator.pop(context);
                                        _snack('Retour créé');
                                        await _load();
                                      } catch (error) {
                                        setLocal(() => submitting = false);
                                        _snack(error.toString().replaceFirst('Exception: ', ''));
                                      }
                                    },
                              style: FilledButton.styleFrom(backgroundColor: AppColors.brand600),
                              child: submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Valider'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    notesCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sale = _sale;
    final reference = sale == null ? 'Vente' : _text(sale, const ['reference'], fallback: 'Vente');

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(reference, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading && sale == null
          ? const LoadingView(message: 'Chargement de la vente…')
          : _error != null && sale == null
              ? ErrorView(message: _error!, onRetry: _load)
              : sale == null
                  ? const ErrorView(message: 'Vente introuvable')
                  : RefreshIndicator(
                      color: AppColors.brand500,
                      onRefresh: _load,
                      child: ListView(
                        padding: PosUi.pagePadding(context),
                        children: [
                          _HeaderCard(sale: sale, money: _money, dateFormat: _dateFormat),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'Lignes',
                            child: Column(
                              children: [
                                for (final item in _list(sale['items']).map(_asMap)) ...[
                                  _LineRow(item: item, money: _money),
                                  Divider(height: 16, color: AppColors.border),
                                ],
                                if (_list(sale['items']).isEmpty)
                                  Text('Aucune ligne', style: PosUi.caption()),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'Taxes',
                            child: _KeyValueList(
                              rows: _list(sale['taxes']).map(_asMap).map((tax) {
                                final label = _text(
                                  tax,
                                  const ['name', 'label', 'tax_name'],
                                  fallback: 'Taxe',
                                );
                                final amount = _amount(tax, const ['amount', 'tax_amount', 'total']);
                                return (label, _money(amount));
                              }).toList(),
                              empty: 'Aucune taxe',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'Remises',
                            child: _KeyValueList(
                              rows: _list(sale['discounts']).map(_asMap).map((discount) {
                                final label = _text(
                                  discount,
                                  const ['name', 'label', 'code'],
                                  fallback: 'Remise',
                                );
                                final amount = _amount(discount, const ['amount', 'discount_amount', 'total']);
                                return (label, _money(amount));
                              }).toList(),
                              empty: 'Aucune remise',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'Paiements',
                            child: _KeyValueList(
                              rows: _list(sale['payments']).map(_asMap).map((payment) {
                                final label = _text(
                                  payment,
                                  const ['method_label', 'methodLabel', 'method', 'payment_method'],
                                  fallback: 'Paiement',
                                );
                                final amount = _amount(payment, const ['amount', 'paid_amount']);
                                return (label, _money(amount));
                              }).toList(),
                              empty: 'Aucun paiement',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _TotalsCard(sale: sale, money: _money),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: _busy ? null : _printReceipt,
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('Reçu'),
                                style: FilledButton.styleFrom(backgroundColor: AppColors.brand600),
                              ),
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _printInvoice,
                                icon: const Icon(Icons.description_outlined),
                                label: const Text('Facture'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _openReturnDialog,
                                icon: const Icon(Icons.undo_outlined),
                                label: const Text('Créer un retour'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.sale,
    required this.money,
    required this.dateFormat,
  });

  final Map<String, dynamic> sale;
  final String Function(int) money;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final status = _text(sale, const ['status'], fallback: '—');
    final paymentStatus = _text(sale, const ['payment_status', 'paymentStatus']);
    final customer = _nestedName(sale['customer']) ?? 'Client de passage';
    final created = DateTime.tryParse(
      _text(sale, const ['completed_at', 'completedAt', 'created_at', 'createdAt']),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(PosUi.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _text(sale, const ['reference'], fallback: '—'),
                  style: GoogleFonts.ibmPlexMono(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              PosBadge(label: status, tone: PosBadgeTone.brand),
            ],
          ),
          const SizedBox(height: 10),
          Text(customer, style: PosUi.body(weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            [
              if (paymentStatus.isNotEmpty) paymentStatus,
              if (created != null) dateFormat.format(created.toLocal()),
              money(_amount(sale, const ['total'])),
            ].join(' · '),
            style: PosUi.caption(),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(PosUi.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: PosUi.sectionLabel()),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.item, required this.money});

  final Map<String, dynamic> item;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final qty = _amount(item, const ['quantity']);
    final unit = _amount(item, const ['unit_price', 'unitPrice', 'price']);
    final total = _amount(item, const ['line_total', 'lineTotal', 'total']);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_itemName(item), style: PosUi.body(weight: FontWeight.w600)),
              Text('Qté $qty · PU ${money(unit)}', style: PosUi.caption()),
            ],
          ),
        ),
        Text(money(total), style: PosUi.money(size: 13)),
      ],
    );
  }
}

class _KeyValueList extends StatelessWidget {
  const _KeyValueList({required this.rows, required this.empty});

  final List<(String, String)> rows;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return Text(empty, style: PosUi.caption());
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(child: Text(row.$1, style: PosUi.body())),
                Text(row.$2, style: PosUi.money(size: 12)),
              ],
            ),
          ),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.sale, required this.money});

  final Map<String, dynamic> sale;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Sous-total', _amount(sale, const ['subtotal'])),
      ('Remises', _amount(sale, const ['discount_total', 'discountTotal'])),
      ('Taxes', _amount(sale, const ['tax_total', 'taxTotal'])),
      ('Frais', _amount(sale, const ['fees_total', 'feesTotal'])),
      ('Total', _amount(sale, const ['total'])),
      ('Payé', _amount(sale, const ['paid_amount', 'paidAmount'])),
      ('Reste', _amount(sale, const ['outstanding_amount', 'outstandingAmount'])),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand50,
        borderRadius: BorderRadius.circular(PosUi.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.$1,
                      style: row.$1 == 'Total'
                          ? PosUi.totalCaption()
                          : PosUi.body(color: AppColors.textSecondary),
                    ),
                  ),
                  Text(
                    money(row.$2),
                    style: row.$1 == 'Total' ? PosUi.totalAmount(size: 22) : PosUi.money(size: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReturnQtyTile extends StatelessWidget {
  const _ReturnQtyTile({
    required this.label,
    required this.maxQty,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int maxQty;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: PosUi.body(weight: FontWeight.w600))),
          IconButton(
            onPressed: value <= 0 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$value / $maxQty', style: PosUi.money(size: 12)),
          IconButton(
            onPressed: value >= maxQty ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
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

ReceiptPrintPayload? _extractPayload(dynamic result) {
  if (result is ReceiptPrintPayload) return result;
  if (result is ReceiptIssueResult) return result.payload;
  if (result is InvoiceIssueResult) return result.payload;
  if (result is Map) {
    final map = Map<String, dynamic>.from(result);
    final payload = map['payload'] ??
        (map['data'] is Map ? (map['data'] as Map)['payload'] : null) ??
        map;
    if (payload is Map) {
      try {
        return ReceiptPrintPayload.fromJson(Map<String, dynamic>.from(payload));
      } catch (_) {}
    }
  }
  try {
    final payload = (result as dynamic).payload;
    if (payload is ReceiptPrintPayload) return payload;
    if (payload is Map) {
      return ReceiptPrintPayload.fromJson(Map<String, dynamic>.from(payload));
    }
  } catch (_) {}
  return null;
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

String _itemName(Map<String, dynamic> item) {
  return _text(
    item,
    const ['product_name', 'productName', 'name'],
    fallback: 'Article',
  );
}

int _returnableQty(Map<String, dynamic> item) {
  final returnable = _amount(item, const ['quantity_returnable', 'quantityReturnable']);
  if (returnable > 0) return returnable;
  return _amount(item, const ['quantity']);
}

String? _nestedName(dynamic value) {
  if (value is Map) {
    final name = value['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
  }
  return null;
}
