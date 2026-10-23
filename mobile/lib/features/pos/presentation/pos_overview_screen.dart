import 'package:flutter/material.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/loading_error_view.dart';
import '../../../sync/offline_store.dart';
import '../data/pos_api_service.dart';
import '../domain/pos_models.dart';
import 'widgets/pos_ui.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

class PosOverviewScreen extends StatefulWidget {
  const PosOverviewScreen({super.key});

  @override
  State<PosOverviewScreen> createState() => _PosOverviewScreenState();
}

class _PosOverviewScreenState extends State<PosOverviewScreen> {
  PosOverview? _overview;
  bool _loading = true;
  String? _error;
  String _storeId = '';
  int _generation = 0;

  String get _currency => TerminalConfigRepository.instance.config.currencyCode;

  String _money(int amount) => MoneyFormatter.format(amount, currencyCode: _currency);

  @override
  void initState() {
    super.initState();
    _storeId = TerminalConfigRepository.instance.config.storeId;
    TerminalConfigRepository.instance.addListener(_onConfigChanged);
    OfflineStore.instance.salesRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    TerminalConfigRepository.instance.removeListener(_onConfigChanged);
    OfflineStore.instance.salesRevision.removeListener(_load);
    super.dispose();
  }

  void _onConfigChanged() {
    final storeId = TerminalConfigRepository.instance.config.storeId;
    if (storeId == _storeId) return;
    _storeId = storeId;
    _overview = null;
    _load();
  }

  Future<void> _load() async {
    final storeId = TerminalConfigRepository.instance.config.storeId;
    final generation = ++_generation;
    bool stale() =>
        !mounted || generation != _generation || TerminalConfigRepository.instance.config.storeId != storeId;

    _storeId = storeId;
    if (_overview == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    PosOverview? local;
    try {
      local = PosOverview.fromJson(await OfflineStore.instance.localPosOverview());
      if (stale()) return;
      setState(() {
        _overview = local;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (stale()) return;
      setState(() {
        _loading = false;
        if (_overview == null) {
          _error = error.toString().replaceFirst('Exception: ', '');
        }
      });
    }

    try {
      final remote = await PosApiService().fetchOverview();
      if (stale()) return;
      // The server only counts sales that have already synced; it must not
      // hide sales still waiting in this terminal's outbox.
      if (local != null && remote.orderCount < local.orderCount) return;
      setState(() {
        _overview = remote;
        _loading = false;
        _error = null;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final config = TerminalConfigRepository.instance.config;
    final name = config.cashierName.trim().isEmpty ? 'Cashier' : config.cashierName.trim();
    final place = config.deviceName.trim().isEmpty
        ? (config.brandName.trim().isEmpty ? 'Store' : config.brandName.trim())
        : config.deviceName.trim();
    final now = DateTime.now();

    return ColoredBox(
      color: AppColors.canvas,
      child: RefreshIndicator(
        color: AppColors.brandInk,
        onRefresh: _load,
        child: ListView(
          padding: PosUi.pagePadding(context),
          children: [
            _GreetingHeader(name: name, place: place, now: now),
            const SizedBox(height: 18),
            if (_loading && _overview == null)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: LoadingView(message: tr('Loading overview…')),
              )
            else if (_error != null && _overview == null)
              ErrorView(message: _error!, onRetry: _load)
            else ...[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(tr(_error!), style: PosUi.caption(color: AppColors.danger)),
                ),
              _OverviewBody(
                overview: _overview,
                name: name,
                money: _money,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.overview,
    required this.name,
    required this.money,
  });

  final PosOverview? overview;
  final String name;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final orders = overview?.orderCount ?? 0;
    final revenue = overview?.revenue ?? 0;
    final average = overview?.averageTicket ?? (orders > 0 ? (revenue / orders).round() : 0);
    final active = overview?.activeOrders ?? 0;
    final payments = overview?.paymentMix ?? const [];
    final days = overview?.dailySummary ?? const [];
    final hours = overview?.salesByHour ?? const [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final statsWide = constraints.maxWidth >= 720;
        final top = [
          _TodaySalesCard(name: name, revenue: revenue, money: money),
          _PaymentsCard(payments: payments, money: money),
          _DailySummaryCard(days: days, money: money),
        ];

        return Column(
          children: [
            if (wide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < top.length; i++) ...[
                      if (i > 0) const SizedBox(width: 14),
                      Expanded(
                        child: AppFadeIn(
                          delay: Duration(milliseconds: 60 * i),
                          child: AppHoverLift(child: top[i]),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              for (var i = 0; i < top.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                AppFadeIn(
                  delay: Duration(milliseconds: 60 * i),
                  child: AppHoverLift(child: top[i]),
                ),
              ],
            const SizedBox(height: 14),
            _StatStrip(
              wide: statsWide,
              orders: orders,
              average: average,
              active: active,
              money: money,
            ),
            const SizedBox(height: 14),
            if (wide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppFadeIn(
                        delay: const Duration(milliseconds: 240),
                        child: AppHoverLift(child: _HourlyCard(hours: hours)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: AppFadeIn(
                        delay: const Duration(milliseconds: 300),
                        child: AppHoverLift(child: _BreakdownCard(payments: payments, money: money)),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              AppFadeIn(
                delay: const Duration(milliseconds: 240),
                child: AppHoverLift(child: _HourlyCard(hours: hours)),
              ),
              const SizedBox(height: 12),
              AppFadeIn(
                delay: const Duration(milliseconds: 300),
                child: AppHoverLift(child: _BreakdownCard(payments: payments, money: money)),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.name,
    required this.place,
    required this.now,
  });

  final String name;
  final String place;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.cashierBlue,
          child: Text(
            tr(_initials(name)),
            style: AppTypography.text(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting(now)}, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.text(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: AppColors.brandInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$place · ${_longDate(now)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.text(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _TodaySalesCard extends StatelessWidget {
  const _TodaySalesCard({required this.name, required this.revenue, required this.money});

  final String name;
  final int revenue;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      title: tr("Today's Sales"),
      icon: Icons.pie_chart_outline_rounded,
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            width: 132,
            height: 132,
            child: CustomPaint(
              painter: _RingPainter(
                track: AppColors.brand100,
                color: AppColors.accent,
                progress: 0,
              ),
              child: Center(
                child: Text(
                  tr(_initials(name)),
                  style: AppTypography.text(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandInk,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tr(name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.text(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          AppCountUp(
            value: revenue,
            format: money,
            style: AppTypography.text(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppColors.brandInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr('No target set'),
            style: AppTypography.text(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsCard extends StatelessWidget {
  const _PaymentsCard({required this.payments, required this.money});

  final List<Map<String, dynamic>> payments;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      title: tr('Payment Methods'),
      icon: Icons.credit_card_outlined,
      child: payments.isEmpty
          ? _EmptyMark(
              icon: Icons.credit_card_outlined,
              label: tr('No payments today'),
            )
          : Column(
              children: [
                for (final row in payments.take(5))
                  _PaymentLine(row: row, money: money),
              ],
            ),
    );
  }
}

class _DailySummaryCard extends StatelessWidget {
  const _DailySummaryCard({required this.days, required this.money});

  final List<PosDaySummary> days;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      title: tr('Daily Summary'),
      icon: Icons.calendar_today_outlined,
      child: Column(
        children: [
          const _SummaryHeader(),
          const SizedBox(height: 6),
          for (final day in days) _SummaryRow(day: day, money: money),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader();

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.text(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: AppColors.textMuted,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(tr('DATE'), style: style)),
          Expanded(flex: 3, child: Text(tr('SALES'), textAlign: TextAlign.right, style: style)),
          Expanded(flex: 2, child: Text(tr('ORDERS'), textAlign: TextAlign.right, style: style)),
          Expanded(flex: 3, child: Text(tr('AVG'), textAlign: TextAlign.right, style: style)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.day, required this.money});

  final PosDaySummary day;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.text(
      fontSize: 13,
      fontWeight: day.isToday ? FontWeight.w700 : FontWeight.w500,
      color: day.isToday ? AppColors.brandInk : AppColors.textPrimary,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: day.isToday ? AppColors.brand100 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (day.isToday) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    tr(day.isToday ? 'Today' : _shortDate(day.date)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 3, child: Text(tr(money(day.sales)), textAlign: TextAlign.right, style: style)),
          Expanded(flex: 2, child: Text('${day.orders}', textAlign: TextAlign.right, style: style)),
          Expanded(flex: 3, child: Text(tr(money(day.average)), textAlign: TextAlign.right, style: style)),
        ],
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({
    required this.wide,
    required this.orders,
    required this.average,
    required this.active,
    required this.money,
  });

  final bool wide;
  final int orders;
  final int average;
  final int active;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatTile(icon: Icons.shopping_bag_outlined, value: orders, format: (n) => '$n', label: tr('Orders Today')),
      _StatTile(icon: Icons.show_chart_rounded, value: average, format: money, label: tr('Average Value')),
      _StatTile(icon: Icons.local_mall_outlined, value: active, format: (n) => '$n', label: tr('Active Orders')),
      _StatTile(icon: Icons.flag_outlined, value: 0, format: (n) => '$n', label: tr('Daily Target')),
    ];
    if (!wide) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.15,
        children: tiles,
      );
    }
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.format,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String Function(int) format;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: _cardBox(),
      child: Row(
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCountUp(
                  value: value,
                  format: format,
                  style: AppTypography.text(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandInk,
                  ),
                ),
                Text(
                  tr(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.text(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HourlyCard extends StatelessWidget {
  const _HourlyCard({required this.hours});

  final List<PosHourPoint> hours;

  @override
  Widget build(BuildContext context) {
    final window = hours.where((point) => point.hour >= 8 && point.hour <= 21).toList();
    return _DashCard(
      title: tr('Hourly Sales'),
      icon: Icons.bar_chart_rounded,
      trailing: Text(tr('Today'), style: PosUi.caption()),
      child: SizedBox(
        height: 150,
        child: window.isEmpty
            ? _EmptyMark(icon: Icons.bar_chart_rounded, label: tr('No sales today'))
            : _HourBars(hours: window),
      ),
    );
  }
}

class _HourBars extends StatelessWidget {
  const _HourBars({required this.hours});

  final List<PosHourPoint> hours;

  @override
  Widget build(BuildContext context) {
    final maxRevenue = hours.fold<int>(0, (max, point) => point.revenue > max ? point.revenue : max);
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final point in hours)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: AppMotion.reduceMotion(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 600),
                        curve: AppMotion.standard,
                        builder: (context, t, _) {
                          final full = maxRevenue == 0 ? 6.0 : 8 + 110 * (point.revenue / maxRevenue);
                          return Container(
                            height: full * t,
                            decoration: BoxDecoration(
                              color: point.revenue == 0 ? AppColors.brand200 : AppColors.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final label in const ['08', '12', '16', '20'])
              Expanded(
                child: Text(
                  tr(label),
                  textAlign: TextAlign.center,
                  style: AppTypography.text(fontSize: 10, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.payments, required this.money});

  final List<Map<String, dynamic>> payments;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      title: tr('Breakdown'),
      icon: Icons.donut_large_outlined,
      child: payments.isEmpty
          ? _EmptyMark(icon: Icons.credit_card_outlined, label: tr('No payments today'))
          : Column(
              children: [
                for (final row in payments.take(6))
                  _PaymentLine(row: row, money: money, showBar: true),
              ],
            ),
    );
  }
}

class _PaymentLine extends StatelessWidget {
  const _PaymentLine({
    required this.row,
    required this.money,
    this.showBar = false,
  });

  final Map<String, dynamic> row;
  final String Function(int) money;
  final bool showBar;

  @override
  Widget build(BuildContext context) {
    final label = _text(row, const ['label', 'payment_method'], fallback: 'Other');
    final amount = _num(row, const ['amount']).round();
    final share = _num(row, const ['share']).clamp(0, 100).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(label),
                  style: AppTypography.text(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                tr(money(amount)),
                style: AppTypography.text(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandInk,
                ),
              ),
            ],
          ),
          if (showBar) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: share / 100,
                minHeight: 6,
                backgroundColor: AppColors.brand100,
                color: AppColors.brandInk,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: _cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.brandInk),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(title),
                  style: AppTypography.text(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandInk,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EmptyMark extends StatelessWidget {
  const _EmptyMark({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(tr(label), style: PosUi.caption()),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.track,
    required this.color,
    required this.progress,
  });

  final Color track;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 10.0;
    final rect = Offset.zero & size;
    final deflated = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(deflated, 0, 6.28318, false, paint);
    if (progress <= 0) return;
    paint.color = color;
    canvas.drawArc(deflated, -1.5708, 6.28318 * progress.clamp(0, 1), false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

BoxDecoration _cardBox() {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppColors.border),
    boxShadow: AppColors.elevationSm,
  );
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'IT';
  if (parts.length == 1) {
    final word = parts.first;
    return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String _greeting(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 18) return 'Good afternoon';
  return 'Good evening';
}

String _longDate(DateTime now) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[now.month - 1]} ${now.day}, ${now.year}';
}

String _shortDate(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[parsed.month - 1]} ${parsed.day}';
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
