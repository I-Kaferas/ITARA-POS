enum ConnectivityState {
  offline,
  online,
  syncing,
  syncError,
  localAvailable,
  cloudAvailable,
}

enum SyncQueueStatus {
  pending,
  processing,
  synced,
  retrying,
  failed,
  conflict,
}

class SyncSnapshot {
  const SyncSnapshot({
    required this.connectivity,
    required this.pending,
    required this.failed,
    required this.synced,
    required this.conflicts,
    this.lastSyncAt,
    this.lastError,
    this.target,
  });

  final ConnectivityState connectivity;
  final int pending;
  final int failed;
  final int synced;
  final int conflicts;
  final DateTime? lastSyncAt;
  final String? lastError;
  final String? target;

  String get label => switch (connectivity) {
        ConnectivityState.syncing => 'Synchronisation',
        ConnectivityState.offline => 'Hors ligne',
        ConnectivityState.syncError => 'Erreur de synchro',
        ConnectivityState.localAvailable => 'Réseau local',
        ConnectivityState.cloudAvailable => 'Cloud',
        ConnectivityState.online => 'En ligne',
      };
}
