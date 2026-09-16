import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/loading_error_view.dart';
import '../data/pos_api_service.dart';
import '../domain/pos_models.dart';
import 'widgets/pos_ui.dart';

class PosOverviewScreen extends StatefulWidget {
  const PosOverviewScreen({super.key});

  @override
  State<PosOverviewScreen> createState() => _PosOverviewScreenState();
}

class _PosOverviewScreenState extends State<PosOverviewScreen> {
  final _api = PosApiService();
  final _dateFormat = DateFormat('dd/MM HH:mm');

  PosOverview? _overview;
  bool _loading = true;
  String? _error;

  String get _currency => TerminalConfigRepository.instance.config.currencyCode;

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
      final overview = await _api.fetchOverview();
      if (!mounted) return;
      setState(() {
        _overview = overview;
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

  @override
  Widget build(BuildContext context) {
    final wide = PosUi.isWide(context) || MediaQuery.sizeOf(context).width >= PosUi.tabletBreakpoint;

    return ColoredBox(
      color: AppColors.canvas,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: PosUi.contentMaxWidth(context)),
            child: RefreshIndicator(
              color: AppColors.brand500,
              onRefresh: _load,
              child: ListView(
                padding: PosUi.pagePadding(context),
                children: [
                  Text('VUE D’ENSEMBLE', style: PosUi.sectionLabel()),
                  const SizedBox(height: 6),
                  Text(
                    'Point de vente',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Indicateurs du jour, raccourcis et activité récente.',
                    style: PosUi.caption(),
                  ),
                  const SizedBox(height: 18),
                  if (_loading && _overview == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: LoadingView(message: 'Chargement de la vue…'),
                    )
                  else if (_error != null && _overview == null)
                    ErrorView(message: _error!, onRetry: _load)
                  else ...[
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!, style: PosUi.caption(color: AppColors.danger)),
                      ),
                    _KpiGrid(overview: _overview, money: _money, wide: wide),
                    const SizedBox(height: 22),
                    Text('ACCÈS RAPIDE', style: PosUi.sectionLabel()),
                    const SizedBox(height: 12),
                    _ShortcutsGrid(wide: wide),
                    const SizedBox(height: 22),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _BestSellersPanel(overview: _overview, money: _money)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RecentOrdersPanel(
                              overview: _overview,
                              money: _money,
                              dateFormat: _dateFormat,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _BestSellersPanel(overview: _overview, money: _money),
                      const SizedBox(height: 12),
                      _RecentOrdersPanel(
                        overview: _overview,
                        money: _money,
                        dateFormat: _dateFormat,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.overview,
    required this.money,
    required this.wide,
  });

  final PosOverview? overview;
  final String Function(int) money;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final shiftOpen = overview?.myShiftOpen == true;
    final cards = [
      _KpiCard(
        label: 'Commandes du jour',
        value: '${overview?.orderCount ?? 0}',
        icon: Icons.receipt_long_outlined,
      ),
      _KpiCard(
        label: 'Chiffre d’affaires',
        value: money(overview?.revenue ?? 0),
        icon: Icons.payments_outlined,
        mono: true,
      ),
      _KpiCard(
        label: 'Mon shift',
        value: shiftOpen ? 'Ouvert' : 'Fermé',
        icon: Icons.schedule_outlined,
        tone: shiftOpen ? PosBadgeTone.success : PosBadgeTone.neutral,
      ),
      _KpiCard(
        label: 'Shifts ouverts',
        value: '${overview?.openShiftsCount ?? 0}',
        icon: Icons.groups_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : (constraints.maxWidth >= 420 ? 2 : 1);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: wide ? 1.85 : 1.55,
          children: cards,
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    this.mono = false,
    this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool mono;
  final PosBadgeTone? tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(PosUi.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.elevationSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.brand50,
                  borderRadius: BorderRadius.circular(PosUi.radiusSm),
                ),
                child: Icon(icon, size: 18, color: AppColors.brandInk),
              ),
              const Spacer(),
              if (tone != null) PosBadge(label: value, tone: tone!, compact: true),
            ],
          ),
          const Spacer(),
          Text(label, style: PosUi.caption()),
          const SizedBox(height: 4),
          if (tone == null)
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono
                  ? PosUi.money(size: 20)
                  : GoogleFonts.ibmPlexSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: AppColors.textPrimary,
                    ),
            ),
        ],
      ),
    );
  }
}

class _ShortcutsGrid extends StatelessWidget {
  const _ShortcutsGrid({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.point_of_sale_outlined,
        'Caisse',
        'Vente rapide',
        AppRoutes.pos,
      ),
      (
        Icons.receipt_long_outlined,
        'Commandes',
        'Ventes & attente',
        AppRoutes.orders,
      ),
      (
        Icons.schedule_outlined,
        'Shifts',
        'Ouvrir ou fermer',
        AppRoutes.shifts,
      ),
      (
        Icons.event_seat_outlined,
        'Réservations',
        'Tables & clients',
        AppRoutes.reservations,
      ),
      (
        Icons.undo_outlined,
        'Retours',
        'Remboursements',
        AppRoutes.returns,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= PosUi.phoneBreakpoint ? 3 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: wide ? 2.2 : 1.4,
          children: [
            for (final item in items)
              _ShortcutTile(
                icon: item.$1,
                title: item.$2,
                subtitle: item.$3,
                onTap: () => context.go(item.$4),
              ),
          ],
        );
      },
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(PosUi.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosUi.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosUi.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brand50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.brandInk),
              ),
              const Spacer(),
              Text(title, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: PosUi.caption()),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(PosUi.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: PosUi.cardTitle())),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BestSellersPanel extends StatelessWidget {
  const _BestSellersPanel({required this.overview, required this.money});

  final PosOverview? overview;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final rows = overview?.bestSellers ?? const [];
    return _PanelShell(
      title: 'Meilleures ventes',
      trailing: Text('Aujourd’hui', style: PosUi.caption()),
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('Aucune vente pour le moment', style: PosUi.caption()),
            )
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 16, color: AppColors.border),
                  _BestSellerRow(index: i + 1, row: rows[i], money: money),
                ],
              ],
            ),
    );
  }
}

class _BestSellerRow extends StatelessWidget {
  const _BestSellerRow({
    required this.index,
    required this.row,
    required this.money,
  });

  final int index;
  final dynamic row;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final map = _asMap(row);
    final name = _text(map, const ['product_name', 'productName', 'name'], fallback: 'Article');
    final sku = _text(map, const ['product_sku', 'productSku', 'sku']);
    final qty = _num(map, const ['quantity', 'qty']).toInt();
    final revenue = _num(map, const ['revenue', 'total']).round();

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.brand50,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text('$index', style: PosUi.caption(color: AppColors.brandInk)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: PosUi.body(weight: FontWeight.w600)),
              if (sku.isNotEmpty) Text(sku, style: PosUi.caption()),
            ],
          ),
        ),
        Text('×$qty', style: PosUi.caption()),
        const SizedBox(width: 10),
        Text(money(revenue), style: PosUi.money(size: 12)),
      ],
    );
  }
}

class _RecentOrdersPanel extends StatelessWidget {
  const _RecentOrdersPanel({
    required this.overview,
    required this.money,
    required this.dateFormat,
  });

  final PosOverview? overview;
  final String Function(int) money;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final rows = overview?.recentOrders ?? const [];
    return _PanelShell(
      title: 'Commandes récentes',
      trailing: TextButton(
        onPressed: () => context.go(AppRoutes.orders),
        child: const Text('Voir tout'),
      ),
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('Aucune commande récente', style: PosUi.caption()),
            )
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 16, color: AppColors.border),
                  _RecentOrderRow(row: rows[i], money: money, dateFormat: dateFormat),
                ],
              ],
            ),
    );
  }
}

class _RecentOrderRow extends StatelessWidget {
  const _RecentOrderRow({
    required this.row,
    required this.money,
    required this.dateFormat,
  });

  final dynamic row;
  final String Function(int) money;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final map = _asMap(row);
    final id = _text(map, const ['id']);
    final reference = _text(map, const ['reference'], fallback: '—');
    final customer = _nestedName(map['customer']) ?? '—';
    final total = _num(map, const ['total']).round();
    final paymentStatus = _text(map, const ['payment_status', 'paymentStatus']);
    final dateRaw = _text(map, const ['completed_at', 'completedAt', 'created_at', 'createdAt']);
    final date = DateTime.tryParse(dateRaw);

    return InkWell(
      onTap: id.isEmpty ? null : () => context.go(AppRoutes.saleDetail(id)),
      borderRadius: BorderRadius.circular(PosUi.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reference, style: GoogleFonts.ibmPlexMono(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(
                    date == null ? customer : '$customer · ${dateFormat.format(date.toLocal())}',
                    style: PosUi.caption(),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(money(total), style: PosUi.money(size: 12)),
                if (paymentStatus.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  PosBadge(
                    label: paymentStatus,
                    tone: paymentStatus == 'paid' ? PosBadgeTone.success : PosBadgeTone.warning,
                    compact: true,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
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

String _text(Map<String, dynamic> map, List<String> keys, {String fallback = ''}) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

num _num(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is num) return value;
    final parsed = num.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

String? _nestedName(dynamic value) {
  if (value is Map) {
    final name = value['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
  }
  return null;
}
