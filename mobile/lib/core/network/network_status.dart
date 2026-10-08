import 'operating_mode.dart';

/// État réseau global (mobile.md §17).
enum NetworkStatus {
  noNetwork,
  localNetworkOnly,
  masterConnected,
  internetConnected,
  fullyOnline;

  /// Nom filaire §17.
  String get wire => switch (this) {
        NetworkStatus.noNetwork => 'NO_NETWORK',
        NetworkStatus.localNetworkOnly => 'LOCAL_NETWORK_ONLY',
        NetworkStatus.masterConnected => 'MASTER_CONNECTED',
        NetworkStatus.internetConnected => 'INTERNET_CONNECTED',
        NetworkStatus.fullyOnline => 'FULLY_ONLINE',
      };

  String get label => switch (this) {
        NetworkStatus.noNetwork => 'Hors réseau',
        NetworkStatus.localNetworkOnly => 'Réseau local seul',
        NetworkStatus.masterConnected => 'Master connecté',
        NetworkStatus.internetConnected => 'Internet connecté',
        NetworkStatus.fullyOnline => 'Pleinement en ligne',
      };

  static NetworkStatus fromWire(String? value) {
    final key = (value ?? '').trim().toUpperCase();
    return NetworkStatus.values.firstWhere(
      (item) => item.wire == key || item.name.toUpperCase() == key,
      orElse: () => NetworkStatus.noNetwork,
    );
  }

  /// Résolution pure §17 à partir des sondes.
  static NetworkStatus resolve({
    required bool masterReachable,
    required bool internetReachable,
    required bool lanVisible,
  }) {
    if (masterReachable && internetReachable) return NetworkStatus.fullyOnline;
    if (masterReachable) return NetworkStatus.masterConnected;
    if (internetReachable) return NetworkStatus.internetConnected;
    if (lanVisible) return NetworkStatus.localNetworkOnly;
    return NetworkStatus.noNetwork;
  }
}

extension NetworkStatusX on NetworkStatus {
  /// §74 — une panne réseau ne doit jamais arrêter le commerce.
  bool get canSell => true;

  /// Sync vers le Master LAN.
  bool get canSyncMaster =>
      this == NetworkStatus.masterConnected ||
      this == NetworkStatus.fullyOnline;

  /// Sync vers ITARA ERP Cloud.
  bool get canSyncCloud =>
      this == NetworkStatus.internetConnected ||
      this == NetworkStatus.fullyOnline;

  /// Impression locale toujours possible ; spooler Master si master up.
  bool get canPrint => true;

  /// Cuisine partagée / KDS via Master.
  bool get canUseKitchen =>
      this == NetworkStatus.masterConnected ||
      this == NetworkStatus.fullyOnline;

  /// Mapping indicatif vers Mode A/B/C (le rôle affine via [OperatingModeResolver]).
  OperatingMode get operatingModeHint => switch (this) {
        NetworkStatus.fullyOnline ||
        NetworkStatus.internetConnected =>
          OperatingMode.fullOnline,
        NetworkStatus.masterConnected => OperatingMode.localOffline,
        NetworkStatus.localNetworkOnly ||
        NetworkStatus.noNetwork =>
          OperatingMode.isolatedOffline,
      };
}
