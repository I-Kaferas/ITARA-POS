part of 'master_discovery_bloc.dart';

sealed class MasterDiscoveryEvent extends Equatable {
  const MasterDiscoveryEvent();

  @override
  List<Object?> get props => const [];
}

final class MasterDiscoveryStarted extends MasterDiscoveryEvent {
  const MasterDiscoveryStarted();
}

final class MasterDiscoverySearchRequested extends MasterDiscoveryEvent {
  const MasterDiscoverySearchRequested();
}

final class MasterDiscoveryStopped extends MasterDiscoveryEvent {
  const MasterDiscoveryStopped();
}

final class MasterDiscoverySynced extends MasterDiscoveryEvent {
  const MasterDiscoverySynced();
}
