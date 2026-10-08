part of 'terminal_bloc.dart';

sealed class TerminalEvent extends Equatable {
  const TerminalEvent();

  @override
  List<Object?> get props => const [];
}

final class TerminalLoadRequested extends TerminalEvent {
  const TerminalLoadRequested();
}

final class TerminalSaveRequested extends TerminalEvent {
  const TerminalSaveRequested(this.config);

  final TerminalConfig config;

  @override
  List<Object?> get props => [config];
}

final class TerminalRoleChanged extends TerminalEvent {
  const TerminalRoleChanged(this.role);

  final PosRole role;

  @override
  List<Object?> get props => [role];
}

final class TerminalSynced extends TerminalEvent {
  const TerminalSynced();
}
