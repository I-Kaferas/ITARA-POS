enum HealthLevel { ok, warn, down }

class HealthRow {
  const HealthRow(this.label, this.level);

  final String label;
  final HealthLevel level;
}

/// POS health lights from probes the terminal already has.
class PosHealth {
  const PosHealth({
    required this.database,
    required this.master,
    required this.internet,
    required this.cloud,
    required this.printer,
    required this.sync,
  });

  final HealthLevel database;
  final HealthLevel master;
  final HealthLevel internet;
  final HealthLevel cloud;
  final HealthLevel printer;
  final HealthLevel sync;

  List<HealthRow> get rows => [
        HealthRow('Base locale', database),
        HealthRow('Master', master),
        HealthRow('Internet', internet),
        HealthRow('Cloud', cloud),
        HealthRow('Imprimante', printer),
        HealthRow('Sync', sync),
      ];

  static PosHealth resolve({
    required bool databaseOpen,
    required bool isMaster,
    required bool masterReachable,
    required bool internetReachable,
    required bool cloudReachable,
    required int printersKnown,
    required int printersOnline,
    required int syncFailed,
    required int syncPending,
  }) {
    final master = isMaster || masterReachable ? HealthLevel.ok : HealthLevel.warn;
    final internet = internetReachable ? HealthLevel.ok : HealthLevel.warn;
    final cloud = cloudReachable
        ? HealthLevel.ok
        : (internetReachable ? HealthLevel.warn : HealthLevel.down);
    final printer = printersKnown == 0
        ? HealthLevel.warn
        : (printersOnline > 0 ? HealthLevel.ok : HealthLevel.down);
    final sync = !databaseOpen
        ? HealthLevel.down
        : syncFailed > 0
            ? HealthLevel.down
            : syncPending > 0
                ? HealthLevel.warn
                : HealthLevel.ok;
    return PosHealth(
      database: databaseOpen ? HealthLevel.ok : HealthLevel.down,
      master: master,
      internet: internet,
      cloud: cloud,
      printer: printer,
      sync: sync,
    );
  }
}
