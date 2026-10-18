import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money_formatter.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import '../domain/shift_models.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

class ShiftDetailSheet extends StatefulWidget {
  const ShiftDetailSheet({
    super.key,
    required this.register,
    required this.current,
    required this.onRefresh,
    required this.onSituation,
    this.onCloseShift,
  });

  final CashRegister register;
  final CurrentSessionResponse current;
  final Future<CurrentSessionResponse> Function() onRefresh;
  final Future<void> Function() onSituation;
  final VoidCallback? onCloseShift;

  @override
  State<ShiftDetailSheet> createState() => _ShiftDetailSheetState();
}

class _ShiftDetailSheetState extends State<ShiftDetailSheet> {
  SessionSummary? _summary;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _summary = widget.current.summary;
  }

  CashRegisterSession? get _session => widget.current.session;

  String get _code {
    final session = _session;
    if (session == null) return widget.register.code;
    final day = DateFormat('yyyyMMdd').format(session.openedAt.toLocal());
    final compact = session.id.replaceAll('-', '');
    final tail = compact.length <= 4 ? compact : compact.substring(compact.length - 4);
    return 'SH-$day-$tail';
  }

  String get _duration {
    final session = _session;
    if (session == null) return '0m';
    final end = session.closedAt ?? DateTime.now();
    final mins = end.difference(session.openedAt).inMinutes.clamp(0, 99999);
    if (mins < 60) return '${mins}m';
    final hours = mins ~/ 60;
    final rest = mins % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final next = await widget.onRefresh();
      if (!mounted) return;
      setState(() => _summary = next.summary ?? _summary);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final summary = _summary;
    final open = session?.isOpen ?? false;
    final cashier = (session?.openedByName ?? '').trim().isEmpty ? 'Caissier' : session!.openedByName!.trim();
    final invoices = summary?.invoices ?? const <ShiftInvoice>[];
    final itemsSold = invoices.fold<int>(0, (sum, invoice) => sum + invoice.itemCount);
    final discounts = invoices.fold<int>(0, (sum, invoice) => sum + invoice.discount);
    final refunds = (summary?.paymentMethods ?? const <PaymentMethodBreakdown>[])
        .where((row) => row.method.toLowerCase().contains('refund'))
        .fold<int>(0, (sum, row) => sum + row.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PosUi.deskSuccessBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.play_arrow_rounded, color: PosUi.deskPay, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(_code),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.text(fontSize: 18, fontWeight: FontWeight.w800, color: PosUi.deskText),
                    ),
                    Text(tr(cashier), style: AppTypography.text(fontSize: 13, color: PosUi.deskMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: open ? PosUi.deskSuccessBg : PosUi.deskRaised,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tr(open ? 'Active' : 'Closed'),
                  style: AppTypography.text(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: open ? PosUi.deskPay : PosUi.deskMuted,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: PosUi.deskMuted, size: 20),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: PosUi.deskLine),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 18, color: PosUi.deskMuted),
                  const SizedBox(width: 8),
                  Text(trf('Duration: {0}', [_duration]), style: AppTypography.text(fontSize: 14, fontWeight: FontWeight.w700, color: PosUi.deskText)),
                  const Spacer(),
                  Text(tr('elapsed'), style: AppTypography.text(fontSize: 12, color: PosUi.deskMuted)),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.storefront_outlined, size: 18, color: PosUi.deskMuted),
                  const SizedBox(width: 8),
                  Text(tr('Session stores'), style: AppTypography.text(fontSize: 15, fontWeight: FontWeight.w700, color: PosUi.deskText)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr(widget.register.name.toUpperCase()),
                style: AppTypography.text(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: PosUi.deskMuted),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 18, color: PosUi.deskMuted),
                  const SizedBox(width: 8),
                  Text(tr('Commandes de la session'), style: AppTypography.text(fontSize: 15, fontWeight: FontWeight.w700, color: PosUi.deskText)),
                  const SizedBox(width: 8),
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: PosUi.deskRaised, shape: BoxShape.circle),
                    child: Text(
                      '${invoices.length}',
                      style: AppTypography.text(fontSize: 11, fontWeight: FontWeight.w800, color: PosUi.deskText),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _refreshing ? null : _refresh,
                    icon: _refreshing
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: PosUi.deskMuted))
                        : Icon(Icons.refresh_rounded, color: PosUi.deskMuted, size: 20),
                  ),
                ],
              ),
              if (invoices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(tr('Aucune commande'), style: AppTypography.text(fontSize: 13, color: PosUi.deskMuted)),
                )
              else
                for (final invoice in invoices) ...[
                  const SizedBox(height: 8),
                  _OrderCard(invoice: invoice, storeName: widget.register.name),
                ],
              const SizedBox(height: 22),
              Text(tr('Payment Breakdown'), style: AppTypography.text(fontSize: 18, fontWeight: FontWeight.w800, color: PosUi.deskText)),
              const SizedBox(height: 14),
              _BreakdownGrid(
                opening: summary?.openingBalance ?? session?.openingBalance ?? 0,
                sales: summary?.salesTotal ?? session?.salesTotal ?? 0,
                orders: summary?.invoicesCount ?? invoices.length,
                itemsSold: itemsSold,
                refunds: refunds,
                discounts: discounts,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: PosUi.deskLine),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => widget.onSituation(),
                  style: FilledButton.styleFrom(
                    backgroundColor: PosUi.deskPay,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text(tr('Situation & Remise'), style: AppTypography.text(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
              if (widget.onCloseShift != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onCloseShift,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE23D3D),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 16),
                    label: Text(tr('Close Shift'), style: AppTypography.text(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.invoice, required this.storeName});

  final ShiftInvoice invoice;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final time = invoice.completedAt == null ? '' : DateFormat('HH:mm').format(invoice.completedAt!.toLocal());
    final method = _methodLabel(invoice.method);
    final meta = [
      if (invoice.itemCount > 0) '${invoice.itemCount} art.',
      if ((invoice.customerName ?? '').trim().isNotEmpty) invoice.customerName!.trim(),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: PosUi.deskField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      tr(invoice.reference.isEmpty ? 'Commande' : '#${invoice.reference}'),
                      style: AppTypography.text(fontSize: 14, fontWeight: FontWeight.w800, color: PosUi.deskText),
                    ),
                    _Chip(label: storeName.toUpperCase()),
                    if (time.isNotEmpty) Text(tr(time), style: AppTypography.text(fontSize: 12, color: PosUi.deskMuted)),
                  ],
                ),
                if (meta.isNotEmpty || method.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      if (meta.isNotEmpty) Text(tr(meta), style: AppTypography.text(fontSize: 12, color: PosUi.deskMuted)),
                      if (method.isNotEmpty) _Chip(label: method, filled: true),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tr(MoneyFormatter.format(invoice.total)),
                style: AppTypography.text(fontSize: 16, fontWeight: FontWeight.w800, color: PosUi.deskText),
              ),
              if (invoice.outstanding > 0)
                Text(
                  trf('Dû: {0}', [MoneyFormatter.format(invoice.outstanding)]),
                  style: AppTypography.text(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFE23D3D)),
                ),
            ],
          ),
          Icon(Icons.chevron_right, color: PosUi.deskMuted, size: 18),
        ],
      ),
    );
  }
}

class _BreakdownGrid extends StatelessWidget {
  const _BreakdownGrid({
    required this.opening,
    required this.sales,
    required this.orders,
    required this.itemsSold,
    required this.refunds,
    required this.discounts,
  });

  final int opening;
  final int sales;
  final int orders;
  final int itemsSold;
  final int refunds;
  final int discounts;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Tile(icon: Icons.lock_outline, color: const Color(0xFF8B7CFF), value: MoneyFormatter.format(opening), label: tr('Opening Cash')),
      _Tile(icon: Icons.trending_up, color: PosUi.deskPay, value: MoneyFormatter.format(sales), label: tr('Total Sales')),
      _Tile(icon: Icons.receipt_outlined, color: const Color(0xFF5B8DEF), value: '$orders', label: tr('Total Orders')),
      _Tile(icon: Icons.shopping_bag_outlined, color: const Color(0xFFE0A100), value: '$itemsSold', label: tr('Items Sold')),
      _Tile(icon: Icons.undo, color: const Color(0xFFE23D3D), value: MoneyFormatter.format(refunds), label: tr('Refunds')),
      _Tile(icon: Icons.local_offer_outlined, color: const Color(0xFFE0A100), value: MoneyFormatter.format(discounts), label: tr('Discounts')),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 18,
      crossAxisSpacing: 12,
      childAspectRatio: 2.6,
      children: tiles,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.color, required this.value, required this.label});

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tr(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.text(fontSize: 16, fontWeight: FontWeight.w800, color: PosUi.deskText),
              ),
              Text(tr(label), style: AppTypography.text(fontSize: 12, color: PosUi.deskMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.filled = false});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? const Color(0xFF1E3A5F) : PosUi.deskRaised,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tr(label),
        style: AppTypography.text(fontSize: 11, fontWeight: FontWeight.w700, color: filled ? const Color(0xFF8EBEFF) : PosUi.deskMuted),
      ),
    );
  }
}

String _methodLabel(String? method) {
  switch (method?.toLowerCase().trim()) {
    case 'cash':
      return 'Espèces';
    case 'card':
      return 'Carte';
    case 'credit':
    case 'account':
      return 'Crédit';
    case 'mobile':
    case 'mobile_money':
      return 'Mobile';
    case null:
    case '':
      return '';
    default:
      return method!.replaceAll('_', ' ');
  }
}
