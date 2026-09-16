import 'package:flutter/foundation.dart';

/// Cross-screen intent: open a held sale on the POS.
enum PosHoldAction { modify, addArticles, split, pay }

class PosPendingIntent {
  PosPendingIntent._();

  static final ValueNotifier<PosHoldIntent?> notifier = ValueNotifier(null);

  static void retrieveHold(String holdId, {PosHoldAction action = PosHoldAction.modify}) {
    notifier.value = PosHoldIntent(holdId: holdId, action: action);
  }

  static PosHoldIntent? take() {
    final value = notifier.value;
    notifier.value = null;
    return value;
  }
}

class PosHoldIntent {
  const PosHoldIntent({
    required this.holdId,
    required this.action,
    this.tableId,
  });

  final String holdId;
  final PosHoldAction action;
  final String? tableId;

  bool get openSplit => action == PosHoldAction.split;
  bool get openPay => action == PosHoldAction.pay;
}
