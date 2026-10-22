import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../services/customer_display_bus.dart';
import 'widgets/pos_ui.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

/// Bundled produce hero — must stay visible on every form factor.
const _kProduceAsset = 'assets/images/customer_display_vegetables.jpg';

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

/// Customer-facing order screen — PosUi desk tokens, fruit/produce always on screen.
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
      color: PosUi.deskNight,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 24 : 14,
                    onClose == null ? (wide ? 24 : 14) : 12,
                    wide ? 24 : 14,
                    wide ? 24 : 14,
                  ),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _HeroPanel(snapshot: snapshot, wide: true),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 6,
                              child: _OrderPanel(snapshot: snapshot, wide: true),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _HeroPanel(
                              snapshot: snapshot,
                              wide: false,
                              imageHeight: constraints.maxHeight < 560 ? 120 : 168,
                            ),
                            const SizedBox(height: 12),
                            Expanded(child: _OrderPanel(snapshot: snapshot, wide: false)),
                          ],
                        ),
                ),
                if (onClose != null)
                  Positioned(
                    top: 8,
                    right: 10,
                    child: _CloseChip(onTap: onClose!),
                  ),
              ],
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

class _CloseChip extends StatelessWidget {
  const _CloseChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosUi.deskPanel.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PosUi.deskLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close_rounded, size: 16, color: PosUi.deskText),
              const SizedBox(width: 6),
              Text(
                tr('Fermer'),
                style: AppTypography.text(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: PosUi.deskText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.snapshot,
    required this.wide,
    this.imageHeight = 168,
  });

  final CustomerDisplaySnapshot snapshot;
  final bool wide;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _ProduceImage(fill: true),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    PosUi.deskInk.withValues(alpha: 0.15),
                    PosUi.deskInk.withValues(alpha: 0.72),
                    PosUi.deskInk.withValues(alpha: 0.92),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BrandBadge(name: snapshot.brandName, large: true),
                  const Spacer(),
                  Text(
                    tr('Bienvenue'),
                    style: AppTypography.text(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: PosUi.deskAccent,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('Merci pour votre visite'),
                    style: AppTypography.text(
                      fontSize: 36,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    trf('chez {0} !', [snapshot.brandName]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.text(
                      fontSize: 28,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr(snapshot.tagline),
                    style: AppTypography.text(
                      fontSize: 14,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _GlassTile(
                    icon: Icons.person_rounded,
                    label: tr('Client'),
                    value: _customerLabel(snapshot),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: imageHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _ProduceImage(fill: true),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        PosUi.deskInk.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Row(
                    children: [
                      _BrandBadge(name: snapshot.brandName, large: false),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              snapshot.brandName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.text(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              tr(snapshot.tagline),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.text(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: PosUi.deskPanel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PosUi.deskLine),
          ),
          child: Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 18, color: PosUi.deskAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _customerLabel(snapshot),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.text(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: PosUi.deskText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.name, required this.large});

  final String name;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 56.0 : 40.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PosUi.deskAccent,
        borderRadius: BorderRadius.circular(large ? 16 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        _initials(name),
        style: AppTypography.text(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          color: PosUi.deskInk,
        ),
      ),
    );
  }
}

class _GlassTile extends StatelessWidget {
  const _GlassTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PosUi.deskAccent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: PosUi.deskAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.text(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.text(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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

class _ProduceImage extends StatelessWidget {
  const _ProduceImage({this.fill = false});

  final bool fill;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      _kProduceAsset,
      fit: BoxFit.cover,
      width: double.infinity,
      height: fill ? double.infinity : null,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => const _ProduceFallback(),
    );
    if (fill) return image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: image,
    );
  }
}

class _ProduceFallback extends StatelessWidget {
  const _ProduceFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PosUi.deskAccent.withValues(alpha: 0.55),
            AppColors.success.withValues(alpha: 0.45),
            PosUi.deskInk,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.eco_rounded,
          size: 64,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _OrderPanel extends StatelessWidget {
  const _OrderPanel({required this.snapshot, required this.wide});

  final CustomerDisplaySnapshot snapshot;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final count = _itemCount(snapshot);
    final active = !snapshot.isEmpty;
    return Container(
      decoration: BoxDecoration(
        color: PosUi.deskPanel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PosUi.deskLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: PosUi.deskAccent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.shopping_bag_outlined, color: PosUi.deskAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Votre commande'),
                        style: AppTypography.text(
                          fontSize: wide ? 18 : 16,
                          fontWeight: FontWeight.w800,
                          color: PosUi.deskText,
                        ),
                      ),
                      Text(
                        count == 1 ? tr('1 article') : trf('{0} articles', [count]),
                        style: AppTypography.text(fontSize: 13, color: PosUi.deskMuted),
                      ),
                    ],
                  ),
                ),
                _StatusPill(active: active),
              ],
            ),
          ),
          Divider(height: 1, color: PosUi.deskLine),
          Expanded(
            child: active
                ? ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    itemCount: snapshot.lines.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              tr('Merci et à bientôt !'),
              textAlign: TextAlign.center,
              style: AppTypography.text(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PosUi.deskMuted,
              ),
            ),
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
    final color = active ? PosUi.deskPay : PosUi.deskMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
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
            style: AppTypography.text(
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
    final fontSize = large ? 16.0 : 14.5;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: latest ? PosUi.deskRaised : PosUi.deskField,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: latest
              ? PosUi.deskAccent.withValues(alpha: 0.45)
              : PosUi.deskLine,
        ),
      ),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 42),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PosUi.deskAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${line.quantity}×',
              style: AppTypography.text(
                fontSize: fontSize - 1,
                fontWeight: FontWeight.w800,
                color: PosUi.deskInk,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              line.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.text(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: PosUi.deskText,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            MoneyFormatter.format(line.price, currencyCode: currencyCode),
            style: AppTypography.text(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: PosUi.deskText,
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PosUi.deskAccent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_cart_outlined, size: 32, color: PosUi.deskAccent),
            ),
            const SizedBox(height: 14),
            Text(
              tr('Votre commande apparaîtra ici'),
              textAlign: TextAlign.center,
              style: AppTypography.text(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: PosUi.deskText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('Le caissier ajoute vos articles un par un.'),
              textAlign: TextAlign.center,
              style: AppTypography.text(fontSize: 13, color: PosUi.deskMuted),
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
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: PosUi.deskPay,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Total à payer'),
                style: AppTypography.text(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                count == 1 ? tr('1 article') : trf('{0} articles', [count]),
                style: AppTypography.text(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    amount,
                    key: ValueKey(amount),
                    style: AppTypography.text(
                      fontSize: 30,
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
