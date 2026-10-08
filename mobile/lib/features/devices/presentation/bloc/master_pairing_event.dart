part of 'master_pairing_bloc.dart';

sealed class MasterPairingEvent extends Equatable {
  const MasterPairingEvent();

  @override
  List<Object?> get props => const [];
}

final class MasterPairingSynced extends MasterPairingEvent {
  const MasterPairingSynced();
}

final class MasterPairingCodeRefreshRequested extends MasterPairingEvent {
  const MasterPairingCodeRefreshRequested();
}

final class MasterPairingAcceptRequested extends MasterPairingEvent {
  const MasterPairingAcceptRequested(this.requestId);

  final String requestId;

  @override
  List<Object?> get props => [requestId];
}

final class MasterPairingRejectRequested extends MasterPairingEvent {
  const MasterPairingRejectRequested(this.requestId);

  final String requestId;

  @override
  List<Object?> get props => [requestId];
}

final class MasterPairingSlaveRequested extends MasterPairingEvent {
  const MasterPairingSlaveRequested({
    required this.master,
    required this.code,
  });

  final DiscoveredMaster master;
  final String code;

  @override
  List<Object?> get props => [master, code];
}

final class MasterPairingQrRequested extends MasterPairingEvent {
  const MasterPairingQrRequested(this.raw);

  final String raw;

  @override
  List<Object?> get props => [raw];
}
