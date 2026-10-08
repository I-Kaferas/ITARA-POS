import '../config/terminal_config.dart';

/// Les trois niveaux de fonctionnement (mobile.md §4 / §74).
///
/// Continuité : Internet down → Mode B ; Master down → Mode C (Slaves).
/// Priorité §75 : OFFLINE-FIRST → LOCAL DB → MASTER/SLAVE → … → CLOUD ERP.
enum OperatingMode {
  /// MODE A — POS → Master → ITARA ERP (tout synchronisé).
  fullOnline,

  /// MODE B — Internet indisponible : POS → Master → base locale.
  /// §74 : une panne d’Internet ne doit jamais arrêter le commerce.
  localOffline,

  /// MODE C — Slave isolé : SQLite local → outbox.
  /// §74 : une panne du Master ne doit pas empêcher les ventes temporaires.
  isolatedOffline,
}

extension OperatingModeX on OperatingMode {
  String get code => switch (this) {
        OperatingMode.fullOnline => 'A',
        OperatingMode.localOffline => 'B',
        OperatingMode.isolatedOffline => 'C',
      };

  String get label => switch (this) {
        OperatingMode.fullOnline => 'Mode A — Full Online',
        OperatingMode.localOffline => 'Mode B — Local Offline',
        OperatingMode.isolatedOffline => 'Mode C — Isolated Offline',
      };

  String get shortLabel => switch (this) {
        OperatingMode.fullOnline => 'Full Online',
        OperatingMode.localOffline => 'Local Offline',
        OperatingMode.isolatedOffline => 'Isolated Offline',
      };

  String get description => switch (this) {
        OperatingMode.fullOnline => 'POS → Master → ITARA ERP — tout est synchronisé.',
        OperatingMode.localOffline =>
          'Internet indisponible — POS → Master → base locale. Le commerce continue.',
        OperatingMode.isolatedOffline =>
          'Master indisponible — SQLite local + file offline. Sync au retour du Master.',
      };

  /// Ventes / panier / impression toujours autorisés (§74 offline-first).
  bool get canSell => true;

  bool get canSyncMaster => this != OperatingMode.isolatedOffline;

  bool get canSyncCloud => this == OperatingMode.fullOnline;

  bool get canPrint => true;

  /// Cuisine partagée nécessite le Master (Mode A/B).
  bool get canUseKitchen => this != OperatingMode.isolatedOffline;

  /// Chemin de sync attendu pour l’UI / logs.
  String get syncPath => switch (this) {
        OperatingMode.fullOnline => 'POS → Master → Cloud',
        OperatingMode.localOffline => 'POS → Master → Local DB',
        OperatingMode.isolatedOffline => 'POS → SQLite → Offline Queue',
      };
}

/// Résout le mode opérationnel à partir du rôle et de la connectivité réelle.
class OperatingModeResolver {
  const OperatingModeResolver._();

  static OperatingMode resolve({
    required PosRole role,
    required bool masterReachable,
    required bool cloudReachable,
  }) {
    switch (role) {
      case PosRole.master:
        // Master = edge local. Cloud up → A, sinon B (commerce local).
        if (cloudReachable) return OperatingMode.fullOnline;
        return OperatingMode.localOffline;

      case PosRole.slave:
        if (masterReachable && cloudReachable) return OperatingMode.fullOnline;
        if (masterReachable) return OperatingMode.localOffline;
        return OperatingMode.isolatedOffline;

      case PosRole.standalone:
        // Autonome : cloud = A, sinon file locale (C).
        if (cloudReachable) return OperatingMode.fullOnline;
        return OperatingMode.isolatedOffline;
    }
  }
}
