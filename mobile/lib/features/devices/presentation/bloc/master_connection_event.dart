part of 'master_connection_bloc.dart';

sealed class MasterConnectionEvent extends Equatable {
  const MasterConnectionEvent();

  @override
  List<Object?> get props => const [];
}

final class MasterConnectionSynced extends MasterConnectionEvent {
  const MasterConnectionSynced();
}
