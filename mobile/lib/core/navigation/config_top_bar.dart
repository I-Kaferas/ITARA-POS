import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

import '../../sync/local_master_server.dart';
import '../network/network_bloc.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

const _bg = Color(0xFF0F1524);
const _line = Color(0xFF1F2A3D);
const _violet = Color(0xFF8B7CFF);
const _violetDeep = Color(0xFF5B3DF5);
const _green = Color(0xFF34D399);
const _red = Color(0xFFF87171);
const _muted = Color(0xFF94A3B8);

/// Desktop header shown while the terminal is in configuration mode.
class ConfigTopBar extends StatelessWidget {
  const ConfigTopBar({
    super.key,
    required this.onHome,
    required this.onFeatures,
    required this.onLogout,
  });

  final VoidCallback onHome;
  final VoidCallback onFeatures;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Tooltip(
            message: tr('Retour à la caisse'),
            child: InkWell(
              onTap: onHome,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: SizedBox.square(dimension: 34, child: CustomPaint(painter: _LogoPainter())),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Réglages'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.text(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1.2,
                  ),
                ),
                Text(
                  tr('Mode de configuration'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.text(color: _muted, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _FeaturesButton(onTap: onFeatures),
          const SizedBox(width: 14),
          const _StatusChips(),
          const SizedBox(width: 10),
          _LogoutButton(onTap: onLogout),
        ],
      ),
    );
  }
}

class _FeaturesButton extends StatelessWidget {
  const _FeaturesButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _violet.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: _violet.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.grid_view_rounded, size: 16, color: _violet),
              const SizedBox(width: 8),
              Text(
                tr('Fonctions de l’application'),
                style: AppTypography.text(color: _violet, fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalMasterServer.instance,
      builder: (context, _) {
        return BlocBuilder<NetworkBloc, NetworkState>(
          builder: (context, net) {
            final server = LocalMasterServer.instance.listening || net.masterReachable;
            final online = net.internetReachable;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusChip(
                  icon: online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  label: tr(online ? 'Internet connecté' : 'Hors ligne'),
                  on: online,
                ),
                const SizedBox(width: 10),
                _StatusChip(
                  icon: Icons.cell_tower_rounded,
                  label: tr(server ? 'Serveur actif' : 'Serveur arrêté'),
                  on: server,
                  filled: true,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.on,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final bool on;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = on ? _green : _muted;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: filled ? 12 : 10, vertical: filled ? 8 : 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(filled ? 12 : 6),
        border: Border.all(color: color.withValues(alpha: filled ? 0.45 : 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: AppTypography.text(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: _red,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        textStyle: AppTypography.text(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      icon: const Icon(Icons.logout_rounded, size: 17),
      label: Text(tr('Quitter la session')),
    );
  }
}

/// ITARA "i" mark: a dot and stem wrapped in an open hexagon.
class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shader = const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [_violet, _violetDeep],
    ).createShader(Offset.zero & size);

    final fill = Paint()..shader = shader;
    final stroke = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(w / 2, h / 2);
    final radius = w * 0.44;
    Offset vertex(int i) {
      final angle = math.pi / 6 + i * math.pi / 3;
      return center + Offset(math.cos(angle), math.sin(angle)) * radius;
    }

    final hex = Path()..moveTo(vertex(4).dx, vertex(4).dy);
    for (final i in [3, 2, 1, 0]) {
      hex.lineTo(vertex(i).dx, vertex(i).dy);
    }
    canvas.drawPath(hex, stroke);

    canvas.drawCircle(Offset(w * 0.5, h * 0.27), w * 0.09, fill);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.42, h * 0.42, w * 0.58, h * 0.74),
        Radius.circular(w * 0.08),
      ),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => false;
}
