import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Windows / desktop POS keyboard map (spec §19).
abstract final class PosDesktopShortcutKeys {
  static const search = SingleActivator(LogicalKeyboardKey.f1);
  static const newSale = SingleActivator(LogicalKeyboardKey.f2);
  static const customer = SingleActivator(LogicalKeyboardKey.f3);
  static const payment = SingleActivator(LogicalKeyboardKey.f4);
  static const hold = SingleActivator(LogicalKeyboardKey.f5);
  static const retrieve = SingleActivator(LogicalKeyboardKey.f6);
  static const cancel = SingleActivator(LogicalKeyboardKey.escape);

  static const hints = <(String, String)>[
    ('F1', 'Recherche'),
    ('F2', 'Nouvelle'),
    ('F3', 'Client'),
    ('F4', 'Paiement'),
    ('F5', 'Attente'),
    ('F6', 'Récup.'),
    ('ESC', 'Annuler'),
  ];
}

/// Wraps the POS workspace so F1–F6 / ESC reach handlers even when a
/// HID scanner field holds primary focus (scanner ignores these keys).
class PosDesktopShortcuts extends StatelessWidget {
  const PosDesktopShortcuts({
    super.key,
    required this.onSearch,
    required this.onNewSale,
    required this.onCustomer,
    required this.onPayment,
    required this.onHold,
    required this.onRetrieve,
    required this.onCancel,
    required this.child,
  });

  final VoidCallback onSearch;
  final VoidCallback onNewSale;
  final VoidCallback onCustomer;
  final VoidCallback onPayment;
  final VoidCallback onHold;
  final VoidCallback onRetrieve;
  final VoidCallback onCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        PosDesktopShortcutKeys.search: onSearch,
        PosDesktopShortcutKeys.newSale: onNewSale,
        PosDesktopShortcutKeys.customer: onCustomer,
        PosDesktopShortcutKeys.payment: onPayment,
        PosDesktopShortcutKeys.hold: onHold,
        PosDesktopShortcutKeys.retrieve: onRetrieve,
        PosDesktopShortcutKeys.cancel: onCancel,
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        child: child,
      ),
    );
  }
}

class PosShortcutHintBar extends StatelessWidget {
  const PosShortcutHintBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        children: [
          for (final hint in PosDesktopShortcutKeys.hints)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: hint.$1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  TextSpan(
                    text: ' ${hint.$2}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).hintColor,
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
