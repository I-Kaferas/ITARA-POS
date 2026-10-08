part of 'network_bloc.dart';

/// Snapshot réseau global §17 + Mode A/B/C.
final class NetworkState extends Equatable {
  const NetworkState({
    this.status = NetworkStatus.noNetwork,
    this.mode = OperatingMode.isolatedOffline,
    this.masterReachable = false,
    this.internetReachable = false,
    this.lanVisible = false,
    this.role = PosRole.standalone,
  });

  final NetworkStatus status;
  final OperatingMode mode;
  final bool masterReachable;
  final bool internetReachable;

  /// Au moins un Master / peer LAN découvert (sans session Master).
  final bool lanVisible;
  final PosRole role;

  OperationRouter get router => OperationRouter(mode: mode, role: role);

  // §17 capabilities — source of truth = [NetworkStatus].
  bool get canSell => status.canSell;
  bool get canSyncMaster => status.canSyncMaster;
  bool get canSyncCloud {
    if (!status.canSyncCloud) return false;
    // Slave : cloud uniquement via Master.
    if (role == PosRole.slave) return status.canSyncMaster;
    return true;
  }

  bool get canPrint => status.canPrint;
  bool get canUseKitchen => status.canUseKitchen;

  /// Impression via spooler Master (sinon impression locale).
  bool get canPrintViaMaster => status.canSyncMaster;

  String get statusWire => status.wire;

  NetworkState copyWith({
    NetworkStatus? status,
    OperatingMode? mode,
    bool? masterReachable,
    bool? internetReachable,
    bool? lanVisible,
    PosRole? role,
  }) {
    return NetworkState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      masterReachable: masterReachable ?? this.masterReachable,
      internetReachable: internetReachable ?? this.internetReachable,
      lanVisible: lanVisible ?? this.lanVisible,
      role: role ?? this.role,
    );
  }

  @override
  List<Object?> get props => [
        status,
        mode,
        masterReachable,
        internetReachable,
        lanVisible,
        role,
      ];
}
