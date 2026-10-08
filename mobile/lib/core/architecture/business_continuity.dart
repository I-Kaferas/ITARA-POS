import '../config/terminal_config.dart';
import '../network/operating_mode.dart';
import 'architectural_priority.dart';

/// Continuité d’activité (mobile.md §74).
///
/// Règles non négociables :
/// 1. Une panne d’Internet ne doit jamais arrêter le commerce.
/// 2. Une panne du Master ne doit pas empêcher les Slaves de vendre temporairement.
/// 3. Une panne d’imprimante ne doit jamais annuler une vente.
abstract final class BusinessContinuity {
  /// §74 — Internet down ≠ commerce stopped.
  static const bool internetOutageNeverStopsCommerce = true;

  /// §74 — Master down → Slaves continuent en Mode C (file locale).
  static const bool masterOutageAllowsTemporarySlaveSales = true;

  /// §74 / §41 — print est best-effort ; la vente est déjà commitée.
  static const bool printerFailureNeverCancelsSale = true;

  /// Couche §75 qui gouverne la continuité du commerce.
  static const ArchitecturalPriority commercePriority =
      ArchitecturalPriority.offlineFirst;

  /// Mode résolu sans Internet — le commerce doit rester autorisé.
  static OperatingMode modeWithoutInternet({
    required PosRole role,
    required bool masterReachable,
  }) {
    return OperatingModeResolver.resolve(
      role: role,
      masterReachable: masterReachable,
      cloudReachable: false,
    );
  }

  /// Mode résolu sans Master — Slave passe en Mode C, vente locale OK.
  static OperatingMode modeWithoutMaster({
    required PosRole role,
    required bool cloudReachable,
  }) {
    return OperatingModeResolver.resolve(
      role: role,
      masterReachable: false,
      cloudReachable: cloudReachable,
    );
  }

  /// Vente autorisée quel que soit l’état réseau / mode (§74 + offline-first).
  static bool allowsCommerce({
    required PosRole role,
    required bool masterReachable,
    required bool cloudReachable,
  }) {
    final mode = OperatingModeResolver.resolve(
      role: role,
      masterReachable: masterReachable,
      cloudReachable: cloudReachable,
    );
    return mode.canSell;
  }

  /// Slave sans Master : vente temporaire via SQLite + outbox.
  static bool allowsTemporarySlaveSalesWithoutMaster({
    bool cloudReachable = false,
  }) {
    if (!masterOutageAllowsTemporarySlaveSales) return false;
    final mode = modeWithoutMaster(
      role: PosRole.slave,
      cloudReachable: cloudReachable,
    );
    return mode == OperatingMode.isolatedOffline && mode.canSell;
  }

  /// Exécute [printAction] après une vente ; avale toute erreur d’impression.
  ///
  /// La vente ([saleResult]) est toujours retournée intacte.
  static Future<T> afterSalePrint<T>(
    T saleResult,
    Future<void> Function() printAction,
  ) async {
    assert(printerFailureNeverCancelsSale);
    try {
      await printAction();
    } catch (_) {
      // Impression différée / spool — jamais d’annulation de vente.
    }
    return saleResult;
  }

  /// Variante sync pour callbacks void (UI).
  static void ignorePrintError(Object? error, [StackTrace? stack]) {
    assert(printerFailureNeverCancelsSale);
    // Intentionally empty — logged by callers if needed.
  }
}
