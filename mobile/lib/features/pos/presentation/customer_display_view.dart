import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../services/customer_display_bus.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

Color get _brand => AppColors.brandInk;
const _brandFill = AppColors.brand700;
const _accent = AppColors.accent;
Color get _ink => AppColors.textPrimary;
Color get _text => AppColors.textSecondary;
Color get _muted => AppColors.textMuted;
Color get _canvas => AppColors.canvas;
Color get _line => AppColors.border;
Color get _surface => AppColors.surface;

class CustomerDisplayPage extends StatelessWidget {
  const CustomerDisplayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CustomerDisplayBus.instance,
      builder: (context, _) => CustomerDisplayView(
        snapshot: CustomerDisplayBus.instance.snapshot,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// Customer-facing order screen, styled like the cashier settings page.
class CustomerDisplayView extends StatelessWidget {
  const CustomerDisplayView({
    super.key,
    required this.snapshot,
    this.onClose,
  });

  final CustomerDisplaySnapshot snapshot;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _canvas,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final pad = wide ? 28.0 : 16.0;
            final compactImage = constraints.maxHeight >= 760
                ? 170.0
                : constraints.maxHeight >= 600
                    ? 120.0
                    : 0.0;
            final hero = _HeroCard(snapshot: snapshot, wide: wide, compactImage: compactImage);
            final order = _OrderPanel(snapshot: snapshot, wide: wide);
            return Padding(
              padding: EdgeInsets.fromLTRB(pad, onClose == null ? pad : 12, pad, pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (onClose != null) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: _PillButton(
                        icon: Icons.close_rounded,
                        label: tr('Fermer'),
                        onTap: onClose!,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 5, child: hero),
                              const SizedBox(width: 24),
                              Expanded(flex: 6, child: order),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              hero,
                              const SizedBox(height: 16),
                              Expanded(child: order),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _customerLabel(CustomerDisplaySnapshot snapshot) {
  final name = snapshot.customerName.trim();
  if (name.isEmpty || name == 'Walk-in customer') return tr('Client de passage');
  return name;
}

int _itemCount(CustomerDisplaySnapshot snapshot) =>
    snapshot.lines.fold(0, (sum, line) => sum + line.quantity);

String _initials(String name) {
  final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'I';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: AppColors.elevationMd,
      ),
      child: child,
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, this.size = 40});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, size: size * 0.5, color: AppColors.violet600),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _brand),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _brand,
          ),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _brand.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: _brand),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _brand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Brand / welcome ─────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.snapshot, required this.wide, this.compactImage = 0});

  final CustomerDisplaySnapshot snapshot;
  final bool wide;

  /// Height of the produce photo in the narrow layout; 0 hides it.
  final double compactImage;

  @override
  Widget build(BuildContext context) {
    final bannerHeight = wide ? 150.0 : 84.0;
    final avatar = wide ? 84.0 : 60.0;
    final header = Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              child: SizedBox(height: bannerHeight, child: const _Banner()),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(avatar + 40, 14, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.brandName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: wide ? 24 : 19,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr(snapshot.tagline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _brand,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          left: 20,
          top: bannerHeight - avatar * 0.55,
          child: Container(
            width: avatar,
            height: avatar,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _brandFill,
              border: Border.all(color: _accent, width: 3),
            ),
            child: Text(
              _initials(snapshot.brandName),
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: avatar * 0.32,
              ),
            ),
          ),
        ),
      ],
    );

    final customer = _InfoTile(
      icon: Icons.person_rounded,
      label: tr('Client'),
      value: _customerLabel(snapshot),
    );

    if (!wide) {
      return _Card(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 14),
            if (compactImage > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(height: compactImage, child: const _ProduceImage(padded: false)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: customer,
            ),
          ],
        ),
      );
    }

    return _Card(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(icon: Icons.waving_hand_rounded, text: tr('Bienvenue')),
                  const SizedBox(height: 10),
                  Text(
                    tr('Merci pour votre visite'),
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 38,
                      height: 1.08,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: _ink,
                    ),
                  ),
                  Text(
                    trf('chez {0} !', [snapshot.brandName]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 38,
                      height: 1.08,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: AppColors.violet600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('Vos articles s’affichent ici au fur et à mesure.'),
                    style: GoogleFonts.ibmPlexSans(fontSize: 15, height: 1.4, color: _muted),
                  ),
                  const Expanded(child: _ProduceImage()),
                  customer,
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.verified_user_rounded,
                          label: tr('Paiement'),
                          value: tr('Sécurisé'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.receipt_long_rounded,
                          label: tr('Reçu'),
                          value: tr('Remis à la caisse'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProduceImage extends StatelessWidget {
  const _ProduceImage({this.padded = true});

  final bool padded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 90) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.symmetric(vertical: padded ? 18 : 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/customer_display_vegetables.jpg',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: _brandFill);
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          _IconBadge(icon: icon, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.ibmPlexSans(fontSize: 12, color: _muted),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Order ───────────────────────────────────────────────────────────────────

class _OrderPanel extends StatelessWidget {
  const _OrderPanel({required this.snapshot, required this.wide});

  final CustomerDisplaySnapshot snapshot;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final count = _itemCount(snapshot);
    final active = !snapshot.isEmpty;
    return LayoutBuilder(
      builder: (context, constraints) => _card(count, active, showFooter: constraints.maxHeight >= 360),
    );
  }

  Widget _card(int count, bool active, {required bool showFooter}) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                const _IconBadge(icon: Icons.shopping_bag_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Votre commande'),
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      Text(
                        count == 1 ? tr('1 article') : trf('{0} articles', [count]),
                        style: GoogleFonts.ibmPlexSans(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
                ),
                _StatusPill(active: active),
              ],
            ),
          ),
          Divider(height: 1, color: _line),
          if (active)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Expanded(child: _ColumnLabel(tr('ARTICLE'))),
                  _ColumnLabel(tr('MONTANT')),
                ],
              ),
            ),
          Expanded(
            child: active
                ? ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    itemCount: snapshot.lines.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) => _LineRow(
                      line: snapshot.lines[index],
                      currencyCode: snapshot.currencyCode,
                      latest: index == snapshot.lines.length - 1,
                      large: wide,
                    ),
                  )
                : const _EmptyOrder(),
          ),
          _TotalBlock(snapshot: snapshot, count: count),
          if (showFooter)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: const _Footer(),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? _brand : _muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            active ? tr('En cours') : tr('En attente'),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnLabel extends StatelessWidget {
  const _ColumnLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: _muted,
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.currencyCode,
    required this.latest,
    required this.large,
  });

  final CustomerDisplayLine line;
  final String currencyCode;
  final bool latest;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final fontSize = large ? 17.0 : 15.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: latest ? _brand.withValues(alpha: 0.07) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: latest ? _brand.withValues(alpha: 0.25) : Colors.transparent),
      ),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${line.quantity}×',
              style: GoogleFonts.ibmPlexSans(
                fontSize: fontSize - 2,
                fontWeight: FontWeight.w800,
                color: _brand,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              line.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.ibmPlexSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            MoneyFormatter.format(line.price, currencyCode: currencyCode),
            style: GoogleFonts.ibmPlexSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrder extends StatelessWidget {
  const _EmptyOrder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _brand.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_cart_outlined, size: 34, color: _brand),
            ),
            const SizedBox(height: 16),
            Text(
              tr('Votre commande apparaîtra ici'),
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('Le caissier ajoute vos articles un par un.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(fontSize: 13.5, color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalBlock extends StatelessWidget {
  const _TotalBlock({required this.snapshot, required this.count});

  final CustomerDisplaySnapshot snapshot;
  final int count;

  @override
  Widget build(BuildContext context) {
    final amount = MoneyFormatter.format(snapshot.total, currencyCode: snapshot.currencyCode);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _brandFill,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Total à payer'),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                count == 1 ? tr('1 article') : trf('{0} articles', [count]),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.94, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    amount,
                    key: ValueKey(amount),
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sentiment_satisfied_alt_rounded, color: _brand, size: 18),
            const SizedBox(width: 6),
            Text(
              tr('Merci et à bientôt !'),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: _brand,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('Propulsé par'),
              style: GoogleFonts.ibmPlexSans(fontSize: 12, color: _muted),
            ),
            const SizedBox(width: 6),
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _brand,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'I',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'ITARA POS',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _brand,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
