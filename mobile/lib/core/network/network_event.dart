part of 'network_bloc.dart';

sealed class NetworkEvent extends Equatable {
  const NetworkEvent();

  @override
  List<Object?> get props => const [];
}

final class NetworkSynced extends NetworkEvent {
  const NetworkSynced();
}

final class NetworkRefreshRequested extends NetworkEvent {
  const NetworkRefreshRequested();
}
