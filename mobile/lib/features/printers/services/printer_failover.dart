import '../domain/printer.dart';

/// Result of attempting Printer 1 → OFFLINE → Printer 2 → PRINT (mobile.md §41).
class PrinterFailoverResult {
  const PrinterFailoverResult({
    required this.success,
    required this.attempts,
    this.printer,
    this.error,
  });

  final bool success;
  final List<PrinterFailoverAttempt> attempts;
  final Printer? printer;
  final Object? error;

  bool get usedFailover =>
      success && attempts.length > 1 && attempts.any((a) => !a.success);

  List<String> get failedPrinterIds => attempts
      .where((a) => !a.success)
      .map((a) => a.printer.id)
      .toList(growable: false);
}

class PrinterFailoverAttempt {
  const PrinterFailoverAttempt({
    required this.printer,
    required this.success,
    this.error,
  });

  final Printer printer;
  final bool success;
  final Object? error;
}

/// Pure §41 policy: ordered candidates, skip disabled, try until one prints.
class PrinterFailover {
  const PrinterFailover();

  /// Build failover chain: primary first, then other group members by priority.
  /// Ready printers are preferred; offline ones stay as last-resort retries.
  static List<Printer> chain({
    required List<Printer> groupPrinters,
    Printer? preferred,
  }) {
    final enabled = groupPrinters.where((p) => p.enabled).toList();
    if (enabled.isEmpty) return const [];

    final ordered = <Printer>[];
    void addUnique(Printer printer) {
      if (ordered.any((p) => p.id == printer.id)) return;
      ordered.add(printer);
    }

    if (preferred != null && preferred.enabled) {
      addUnique(preferred);
    }

    final ready = enabled.where((p) => p.isReady).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    final offline = enabled.where((p) => !p.isReady).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    for (final printer in ready) {
      addUnique(printer);
    }
    for (final printer in offline) {
      addUnique(printer);
    }
    return ordered;
  }

  /// Execute [printFn] across [candidates] until one succeeds.
  Future<PrinterFailoverResult> run({
    required List<Printer> candidates,
    required Future<void> Function(Printer printer) printFn,
  }) async {
    final attempts = <PrinterFailoverAttempt>[];
    Object? lastError;

    for (final printer in candidates) {
      if (!printer.enabled) continue;
      try {
        await printFn(printer);
        attempts.add(PrinterFailoverAttempt(printer: printer, success: true));
        return PrinterFailoverResult(
          success: true,
          attempts: attempts,
          printer: printer,
        );
      } catch (error) {
        lastError = error;
        attempts.add(
          PrinterFailoverAttempt(
            printer: printer,
            success: false,
            error: error,
          ),
        );
        // Printer 1 OFFLINE → try Printer 2 (never abort the sale).
      }
    }

    return PrinterFailoverResult(
      success: false,
      attempts: attempts,
      error: lastError ?? StateError('Aucune imprimante disponible'),
    );
  }
}
