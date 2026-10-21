import 'package:flutter/material.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

/// Asks whether a held order should also print a kitchen ticket.
///
/// Returns `true` to hold and print, `false` to hold only, or `null` to cancel.
Future<bool?> showHoldOrderDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierColor: const Color(0xB30B1220),
    builder: (context) => const HoldOrderDialog(),
  );
}

class HoldOrderDialog extends StatefulWidget {
  const HoldOrderDialog({super.key});

  @override
  State<HoldOrderDialog> createState() => _HoldOrderDialogState();
}

class _HoldOrderDialogState extends State<HoldOrderDialog> {
  bool _printKitchen = true;

  static const _sheet = Color(0xFF252E3E);
  static const _well = Color(0xFF1B2433);
  static const _amber = Color(0xFFF5A524);
  static const _body = Color(0xFFC5CEDA);
  static const _line = Color(0xFF6E7A8C);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Dialog(
      backgroundColor: _sheet,
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      shadowColor: const Color(0x99000000),
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width < 480 ? width : 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _PauseBadge(),
              const SizedBox(height: 18),
              Text(
                tr('Mettre la commande en attente ?'),
                textAlign: TextAlign.center,
                style: AppTypography.jakarta(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr('Cette commande sera enregistrée mais PAS envoyée en cuisine. Vous pourrez la retrouver et la gérer depuis la page Commandes.'),
                textAlign: TextAlign.center,
                style: AppTypography.plex(
                  color: _body,
                  fontSize: 14.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Material(
                color: _well,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _printKitchen = !_printKitchen),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(
                      children: [
                        _PrintCheck(checked: _printKitchen),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr('Imprimer le bon de cuisine'),
                            style: AppTypography.plex(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.transparent,
                        side: const BorderSide(color: _line, width: 1.4),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: AppTypography.plex(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      child: Text(tr('Annuler')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _printKitchen),
                      style: FilledButton.styleFrom(
                        backgroundColor: _amber,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: AppTypography.plex(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      child: Text(tr('Attente')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PauseBadge extends StatelessWidget {
  const _PauseBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: const BoxDecoration(
        color: Color(0xFF3A3124),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PauseBar(),
          SizedBox(width: 5),
          _PauseBar(),
        ],
      ),
    );
  }
}

class _PauseBar extends StatelessWidget {
  const _PauseBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 18,
      decoration: BoxDecoration(
        color: const Color(0xFFF5A524),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _PrintCheck extends StatelessWidget {
  const _PrintCheck({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? const Color(0xFFF5A524) : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFF5A524), width: 1.8),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 16, color: Color(0xFF1B2433))
          : null,
    );
  }
}
