part of 'master_discovery_bloc.dart';

final class MasterDiscoveryState extends Equatable {
  const MasterDiscoveryState({
    this.masters = const [],
    this.searching = false,
    this.statusMessage = 'Searching for ITARA Master...',
  });

  final List<DiscoveredMaster> masters;
  final bool searching;
  final String statusMessage;

  @override
  List<Object?> get props => [masters, searching, statusMessage];
}
