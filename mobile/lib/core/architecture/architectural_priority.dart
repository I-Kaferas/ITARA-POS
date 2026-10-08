/// Ordre de priorité architecturale (mobile.md §75).
///
/// En cas de conflit entre couches, la priorité la plus haute (rang le plus bas)
/// l’emporte. Ex. : offline-first > sync cloud ; vente locale > realtime.
enum ArchitecturalPriority {
  offlineFirst(1, 'OFFLINE-FIRST'),
  localDatabase(2, 'LOCAL DATABASE'),
  masterSlave(3, 'MASTER / SLAVE'),
  networkDiscovery(4, 'NETWORK DISCOVERY'),
  synchronization(5, 'SYNCHRONIZATION'),
  printerManagement(6, 'PRINTER MANAGEMENT'),
  posTransactions(7, 'POS TRANSACTIONS'),
  security(8, 'SECURITY'),
  realtime(9, 'REALTIME'),
  cloudErp(10, 'CLOUD ERP');

  const ArchitecturalPriority(this.rank, this.label);

  /// 1 = plus haute priorité, 10 = plus basse.
  final int rank;
  final String label;

  /// Ordre §75 exact (1 → 10).
  static const List<ArchitecturalPriority> ordered = [
    ArchitecturalPriority.offlineFirst,
    ArchitecturalPriority.localDatabase,
    ArchitecturalPriority.masterSlave,
    ArchitecturalPriority.networkDiscovery,
    ArchitecturalPriority.synchronization,
    ArchitecturalPriority.printerManagement,
    ArchitecturalPriority.posTransactions,
    ArchitecturalPriority.security,
    ArchitecturalPriority.realtime,
    ArchitecturalPriority.cloudErp,
  ];

  /// `true` si [this] a priorité sur [other] (rang plus petit).
  bool outranks(ArchitecturalPriority other) => rank < other.rank;

  /// Le gagnant d’un conflit entre deux priorités.
  static ArchitecturalPriority prefer(
    ArchitecturalPriority a,
    ArchitecturalPriority b,
  ) =>
      a.outranks(b) ? a : b;
}
