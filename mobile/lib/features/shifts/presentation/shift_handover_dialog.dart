import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import '../domain/shift_models.dart';
import '../services/shift_z_report_printer.dart';

class ShiftHandoverDialog extends StatefulWidget {
  const ShiftHandoverDialog({
    super.key,
    required this.session,
    required this.summary,
    required this.onReload,
  });

  final CashRegisterSession session;
  final SessionSummary summary;
  final Future<SessionSummary> Function() onReload;

  @override
  State<ShiftHandoverDialog> createState() => _ShiftHandoverDialogState();
}

class _ShiftHandoverDialogState extends State<ShiftHandoverDialog> {
  late SessionSummary _summary;
  final _search = TextEditingController();
  var _refreshing = false;
  var _printing = false;
  var _query = '';

  @override
  void initState() {
    super.initState();
    _summary = widget.summary;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _code {
    final day = DateFormat('yyyyMMdd').format(widget.session.openedAt.toLocal());
    final compact = widget.session.id.replaceAll('-', '');
    final tail = compact.length <= 4 ? compact : compact.substring(compact.length - 4);
    return '#SH-$day-$tail';
  }

  String get _duration {
    final end = widget.session.closedAt ?? DateTime.now();
    final mins = end.difference(widget.session.openedAt).inMinutes.clamp(0, 99999);
    if (mins < 60) return '${mins}m';
    final hours = mins ~/ 60;
    final rest = mins % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  String get _cashier {
    final name = widget.session.openedByName?.trim() ?? '';
    return name.isEmpty ? 'Caissier' : name;
  }

  Future<void> _reload() async {
    setState(() => _refreshing = true);
    try {
      final summary = await widget.onReload();
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      await ShiftZReportPrinter().printHandover(
        sessionCode: _code,
        cashier: _cashier,
        duration: _duration,
        report: _summary,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final handover = _summary.handover;
    final currency = handover.currency;
    final revenue = handover.soldTotal > 0 ? handover.soldTotal : _summary.salesTotal;
    final visible = _visibleStores(handover);
    final visibleSold = visible.fold<int>(0, (sum, store) => sum + store.lines.fold(0, (lineSum, line) => lineSum + line.sold));
    final visibleCredit = visible.fold<int>(0, (sum, store) => sum + store.lines.fold(0, (lineSum, line) => lineSum + line.creditQty));
    final visibleTotal = visible.fold<int>(0, (sum, store) => sum + store.lines.fold(0, (lineSum, line) => lineSum + line.total));
    final footerTotal = _query.isEmpty ? revenue : visibleTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PosUi.deskPay,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          'Situation & Remise de Caisse',
                          style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w800, color: PosUi.deskText),
                        ),
                        _LivePill(open: widget.session.isOpen),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Session $_code · Caissier : $_cashier · $_duration',
                      style: GoogleFonts.ibmPlexSans(fontSize: 12.5, color: PosUi.deskMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualiser',
                onPressed: _refreshing ? null : _reload,
                icon: _refreshing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: PosUi.deskAccent),
                      )
                    : Icon(Icons.refresh_rounded, color: PosUi.deskMuted),
              ),
              IconButton(
                tooltip: 'Fermer',
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: PosUi.deskMuted),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            children: [
              _SectionBox(
                title: 'Synthèse des Ventes & Articles',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 760 ? 4 : 2;
                    final gap = 10.0;
                    final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        _StatCard(
                          width: width,
                          icon: Icons.inventory_2_outlined,
                          iconColor: PosUi.deskAccent,
                          value: '${handover.articlesSold} article${handover.articlesSold == 1 ? '' : 's'}',
                          label: 'Articles Vendus',
                          note: handover.articlesOnCredit > 0 ? '${handover.articlesOnCredit} à crédit' : null,
                        ),
                        _StatCard(
                          width: width,
                          icon: Icons.show_chart_rounded,
                          iconColor: PosUi.deskStock,
                          value: _money(revenue, currency),
                          label: 'Chiffre d\'affaires',
                        ),
                        _StatCard(
                          width: width,
                          icon: Icons.receipt_long_outlined,
                          iconColor: const Color(0xFF4C8DFF),
                          value: '${handover.ordersCount} cmd(s)',
                          label: 'Commandes traitées',
                        ),
                        _StatCard(
                          width: width,
                          icon: Icons.storefront_outlined,
                          iconColor: PosUi.deskMuted,
                          value: '${handover.storesCount} magasin(s)',
                          label: 'Magasins concernés',
                        ),
                        _StatCard(
                          width: width,
                          icon: Icons.request_quote_outlined,
                          iconColor: PosUi.deskAccent,
                          value: _money(handover.creditSalesTotal, currency),
                          label: 'Ventes à Crédit',
                          note: '${handover.creditOrdersCount} commande(s)',
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Articles Vendus & Stocks par Magasin',
                style: GoogleFonts.ibmPlexSans(fontSize: 16, fontWeight: FontWeight.w800, color: PosUi.deskText),
              ),
              const SizedBox(height: 4),
              Text(
                'Produits vendus durant cette session, répartis par magasin avec stock restant disponible.',
                style: GoogleFonts.ibmPlexSans(fontSize: 12.5, color: PosUi.deskMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                style: GoogleFonts.ibmPlexSans(fontSize: 14, color: PosUi.deskText),
                decoration: InputDecoration(
                  hintText: 'Filtrer par nom ou code produit...',
                  hintStyle: GoogleFonts.ibmPlexSans(fontSize: 14, color: PosUi.deskMuted),
                  prefixIcon: Icon(Icons.search_rounded, color: PosUi.deskMuted),
                  filled: true,
                  fillColor: PosUi.deskField,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: PosUi.deskLine)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: PosUi.deskLine)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: PosUi.deskAccent)),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PosUi.deskLine),
                ),
                child: Column(
                  children: [
                    _TableHead(currency: currency),
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          'Aucun article vendu durant cette session.',
                          style: GoogleFonts.ibmPlexSans(fontSize: 13, color: PosUi.deskMuted),
                        ),
                      )
                    else
                      ...visible.map((store) => _StoreBlock(store: store, currency: currency)),
                    _TotalsRow(
                      sold: _query.isEmpty ? handover.articlesSold : visibleSold,
                      credit: _query.isEmpty ? handover.articlesOnCredit : visibleCredit,
                      total: _money(footerTotal, currency),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PosUi.deskText,
                    side: BorderSide(color: PosUi.deskLine),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Close', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _printing ? null : _print,
                  style: FilledButton.styleFrom(
                    backgroundColor: PosUi.deskAccent,
                    foregroundColor: PosUi.deskInk,
                    disabledBackgroundColor: PosUi.deskAccent.withValues(alpha: 0.5),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _printing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: PosUi.deskInk),
                        )
                      : const Icon(Icons.print_outlined, size: 18),
                  label: Text('Imprimer', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<ShiftStoreGroup> _visibleStores(ShiftHandover handover) {
    if (_query.isEmpty) return handover.stores;
    return [
      for (final store in handover.stores)
        if (store.lines.any(_matches))
          ShiftStoreGroup(
            id: store.id,
            name: store.name,
            lines: store.lines.where(_matches).toList(),
          ),
    ];
  }

  bool _matches(ShiftSoldLine line) {
    return line.name.toLowerCase().contains(_query) || line.code.toLowerCase().contains(_query);
  }
}

String _money(int minor, String currency, {bool withCode = true}) {
  final major = minor / 100;
  final whole = (major - major.round()).abs() < 0.001;
  final text = NumberFormat(whole ? '#,##0' : '#,##0.00', 'fr').format(whole ? major.round() : major);
  return withCode ? '$text $currency' : text;
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    final color = open ? PosUi.deskStock : PosUi.deskMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        open ? 'EN DIRECT' : 'CLÔTURÉ',
        style: GoogleFonts.ibmPlexSans(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.4),
      ),
    );
  }
}

class _SectionBox extends StatelessWidget {
  const _SectionBox({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: PosUi.deskCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 16, color: PosUi.deskMuted),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w700, color: PosUi.deskText)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.note,
  });

  final double width;
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: PosUi.deskSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PosUi.deskLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.ibmPlexSans(fontSize: 16, fontWeight: FontWeight.w800, color: PosUi.deskText),
            ),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 12, color: PosUi.deskMuted)),
            if (note != null) ...[
              const SizedBox(height: 6),
              Text(
                note!,
                style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700, color: PosUi.deskAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TableHead extends StatelessWidget {
  const _TableHead({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, color: PosUi.deskMuted, letterSpacing: 0.4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PosUi.deskRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
      ),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('PRODUIT / ARTICLE', style: style)),
          Expanded(flex: 2, child: Text('VENDU', textAlign: TextAlign.center, style: style)),
          Expanded(flex: 2, child: Text('RESTE', textAlign: TextAlign.center, style: style)),
          Expanded(flex: 2, child: Text('TOTAL ($currency)', textAlign: TextAlign.right, style: style)),
        ],
      ),
    );
  }
}

class _StoreBlock extends StatelessWidget {
  const _StoreBlock({required this.store, required this.currency});

  final ShiftStoreGroup store;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: PosUi.deskField,
          child: Row(
            children: [
              Icon(Icons.storefront_outlined, size: 16, color: PosUi.deskMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  store.name.toUpperCase(),
                  style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w800, color: PosUi.deskText),
                ),
              ),
              Text(
                '${store.articlesCount} article(s)',
                style: GoogleFonts.ibmPlexSans(fontSize: 12, color: PosUi.deskMuted),
              ),
            ],
          ),
        ),
        ...store.lines.map((line) => _ProductRow(line: line, currency: currency)),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.line, required this.currency});

  final ShiftSoldLine line;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: PosUi.deskLine))),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w700, color: PosUi.deskText)),
                if (line.code.isNotEmpty)
                  Text('Code : ${line.code}', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: PosUi.deskMuted)),
                if (line.creditQty > 0)
                  Text(
                    '${line.creditQty} à crédit',
                    style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700, color: PosUi.deskAccent),
                  ),
              ],
            ),
          ),
          Expanded(flex: 2, child: Center(child: _QtyPill(value: '${line.sold}', credit: false))),
          Expanded(flex: 2, child: Center(child: _QtyPill(value: line.remaining == null ? '—' : '${line.remaining}', credit: true))),
          Expanded(
            flex: 2,
            child: Text(
              _money(line.total, currency, withCode: false),
              textAlign: TextAlign.right,
              style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w700, color: PosUi.deskText),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyPill extends StatelessWidget {
  const _QtyPill({required this.value, required this.credit});

  final String value;
  final bool credit;

  @override
  Widget build(BuildContext context) {
    final background = credit ? PosUi.deskSuccessBg : AppColors.accentSoft;
    final foreground = credit ? PosUi.deskStock : PosUi.deskAccent;
    return Container(
      constraints: const BoxConstraints(minWidth: 42),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w800, color: foreground),
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.sold, required this.credit, required this.total});

  final int sold;
  final int credit;
  final String total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: PosUi.deskSoft,
        border: Border(top: BorderSide(color: PosUi.deskLine)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL ARTICLES VENDUS',
                  style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w800, color: PosUi.deskText),
                ),
                if (credit > 0)
                  Text(
                    '$credit à crédit',
                    style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700, color: PosUi.deskAccent),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '$sold',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w800, color: PosUi.deskAccent),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('—', textAlign: TextAlign.center, style: GoogleFonts.ibmPlexSans(fontSize: 14, color: PosUi.deskMuted)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              total,
              textAlign: TextAlign.right,
              style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w800, color: PosUi.deskStock),
            ),
          ),
        ],
      ),
    );
  }
}
