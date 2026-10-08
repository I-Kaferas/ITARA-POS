import '../config/terminal_config.dart';
import 'operating_mode.dart';

/// Destination d’une écriture / sync selon le mode (mobile.md §3–§4).
enum SyncTargetKind {
  /// Aucune cible distante — rester en SQLite + file.
  localQueue,

  /// API locale du Master (réseau LAN).
  master,

  /// ITARA ERP Cloud (Laravel).
  cloud,
}

/// Route les opérations selon le mode A / B / C.
///
/// Règle absolue : jamais POS → Internet → Cloud pour une opération
/// réalisable localement (Slave doit passer par le Master).
class OperationRouter {
  const OperationRouter({
    required this.mode,
    required this.role,
  });

  final OperatingMode mode;
  final PosRole role;

  /// Où pousser la file outbound maintenant.
  SyncTargetKind get outboundTarget {
    switch (mode) {
      case OperatingMode.fullOnline:
        return switch (role) {
          PosRole.slave => SyncTargetKind.master,
          PosRole.master || PosRole.standalone => SyncTargetKind.cloud,
        };
      case OperatingMode.localOffline:
        return switch (role) {
          PosRole.slave => SyncTargetKind.master,
          // Master / standalone : pas de cloud — file locale jusqu’au retour.
          PosRole.master || PosRole.standalone => SyncTargetKind.localQueue,
        };
      case OperatingMode.isolatedOffline:
        return SyncTargetKind.localQueue;
    }
  }

  /// Chemin de reprise Mode C → Master → Cloud.
  List<SyncTargetKind> get recoveryPath => switch (mode) {
        OperatingMode.isolatedOffline => const [
            SyncTargetKind.localQueue,
            SyncTargetKind.master,
            SyncTargetKind.cloud,
          ],
        OperatingMode.localOffline => const [
            SyncTargetKind.master,
            SyncTargetKind.cloud,
          ],
        OperatingMode.fullOnline => const [
            SyncTargetKind.master,
            SyncTargetKind.cloud,
          ],
      };

  bool get shouldDrainQueue => outboundTarget != SyncTargetKind.localQueue;

  bool get shouldPullCatalog => outboundTarget != SyncTargetKind.localQueue;

  /// Slave ne doit jamais parler au Cloud directement.
  bool get allowsDirectCloud =>
      role != PosRole.slave && mode == OperatingMode.fullOnline;
}
