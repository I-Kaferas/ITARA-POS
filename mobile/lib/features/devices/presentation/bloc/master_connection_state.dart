part of 'master_connection_bloc.dart';

enum MasterConnectionStatus {
  disconnected,
  searching,
  connectedLocal,
  connectedCloud,
  reconnecting,
  error,
}

final class MasterConnectionState extends Equatable {
  const MasterConnectionState({
    this.status = MasterConnectionStatus.disconnected,
    this.activeTarget,
    this.errorMessage,
  });

  final MasterConnectionStatus status;
  final String? activeTarget;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, activeTarget, errorMessage];
}
