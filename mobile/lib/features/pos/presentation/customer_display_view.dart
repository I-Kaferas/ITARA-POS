import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/money_formatter.dart';
import '../services/customer_display_bus.dart';

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

class CustomerDisplayView extends StatelessWidget {
  const CustomerDisplayView({
    super.key,
    required this.snapshot,
    this.onClose,
  });

  final CustomerDisplaySnapshot snapshot;
  final VoidCallback? onClose;

  static const _purple = Color(0xFF7C3AED);
  static const _ink = Color(0xFF171923);
  static const _muted = Color(0xFF98A2B3);
  static const _canvas = Color(0xFFF3F5F9);
  static const _line = Color(0xFFE7EAF1);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _canvas,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 980;
          final brand = _BrandPane(snapshot: snapshot, compact: stacked);
          final order = _OrderCard(snapshot: snapshot);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (stacked)
                Column(
                  children: [
                    SizedBox(height: constraints.maxHeight * 0.38, child: brand),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: order,
                      ),
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(36, 28, 28, 28),
                  child: Row(
                    children: [
                      Expanded(flex: 5, child: brand),
                      const SizedBox(width: 8),
                      Expanded(flex: 6, child: order),
                    ],
                  ),
                ),
              if (onClose != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, color: _muted),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BrandPane extends StatelessWidget {
  const _BrandPane({required this.snapshot, required this.compact});

  final CustomerDisplaySnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: CustomerDisplayView._purple,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snapshot.brandName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: CustomerDisplayView._ink,
                      ),
                    ),
                    Text(
                      snapshot.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        color: CustomerDisplayView._muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Thank you for shopping',
            style: GoogleFonts.ibmPlexSans(
              fontSize: compact ? 28 : 40,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: CustomerDisplayView._ink,
            ),
          ),
          Text(
            'with us!',
            style: GoogleFonts.ibmPlexSans(
              fontSize: compact ? 28 : 40,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: CustomerDisplayView._purple,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Quality products, for a better tomorrow.',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 16,
              color: const Color(0xFF8B93A7),
            ),
          ),
          const Spacer(),
          const Expanded(
            flex: 5,
            child: _GroceryArt(),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.snapshot});

  final CustomerDisplaySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final money = MoneyFormatter.format(snapshot.total, currencyCode: snapshot.currencyCode);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Color(0x140F172A), blurRadius: 40, offset: Offset(0, 18)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(flex: 6, child: _col('ITEM')),
                Expanded(flex: 2, child: _col('QTY', align: TextAlign.center)),
                Expanded(flex: 3, child: _col('PRICE', align: TextAlign.right)),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: CustomerDisplayView._line),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                snapshot.customerName,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3A4154),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: CustomerDisplayView._line),
            Expanded(
              child: snapshot.isEmpty
                  ? Center(
                      child: Text(
                        'Your order will appear here',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 16,
                          color: const Color(0xFFB0B7C6),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: snapshot.lines.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: CustomerDisplayView._line),
                      itemBuilder: (context, index) {
                        final line = snapshot.lines[index];
                        final price = MoneyFormatter.format(line.price, currencyCode: snapshot.currencyCode);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 6,
                                child: Text(
                                  line.name,
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: CustomerDisplayView._ink,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${line.quantity}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: CustomerDisplayView._ink,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  price,
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: CustomerDisplayView._ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (!snapshot.isEmpty) ...[
              const Divider(height: 1, color: CustomerDisplayView._line),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Text(
                      'Total',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: CustomerDisplayView._muted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      money,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: CustomerDisplayView._purple,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sentiment_satisfied_alt_rounded, color: CustomerDisplayView._purple, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Have a great day!',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CustomerDisplayView._purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Powered by',
                  style: GoogleFonts.ibmPlexSans(fontSize: 12, color: CustomerDisplayView._muted),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: CustomerDisplayView._purple,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    snapshot.brandName.isEmpty ? 'I' : snapshot.brandName.substring(0, 1).toUpperCase(),
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  snapshot.brandName,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CustomerDisplayView._purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _col(String label, {TextAlign align = TextAlign.left}) {
    return Text(
      label,
      textAlign: align,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: const Color(0xFFB0B7C6),
      ),
    );
  }
}

class _GroceryArt extends StatelessWidget {
  const _GroceryArt();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _GroceryPainter(),
      child: SizedBox.expand(),
    );
  }
}

class _GroceryPainter extends CustomPainter {
  const _GroceryPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final basket = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.08, size.height * 0.42, size.width * 0.84, size.height * 0.5),
      const Radius.circular(28),
    );
    canvas.drawRRect(basket, Paint()..color = const Color(0xFF2C3444));
    final rim = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.04, size.height * 0.36, size.width * 0.92, size.height * 0.12),
      const Radius.circular(18),
    );
    canvas.drawRRect(rim, Paint()..color = const Color(0xFF3A4356));

    void blob(double x, double y, double w, double h, Color color) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width * x, size.height * y), width: size.width * w, height: size.height * h),
        Paint()..color = color,
      );
    }

    blob(0.22, 0.28, 0.28, 0.22, const Color(0xFFF3D7A1));
    blob(0.38, 0.22, 0.22, 0.16, const Color(0xFF7CB342));
    blob(0.52, 0.3, 0.16, 0.14, const Color(0xFFE23D3D));
    blob(0.62, 0.24, 0.14, 0.12, const Color(0xFFEF5350));
    blob(0.72, 0.32, 0.18, 0.16, const Color(0xFFFFC107));
    blob(0.84, 0.26, 0.2, 0.12, const Color(0xFFFFE082));
    blob(0.46, 0.18, 0.12, 0.1, const Color(0xFF66BB6A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
