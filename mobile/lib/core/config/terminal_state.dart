part of 'terminal_bloc.dart';

final class TerminalState extends Equatable {
  const TerminalState({
    required this.config,
    required this.isLoaded,
    required this.isConfigured,
  });

  factory TerminalState.fromRepo(TerminalRepository repo) {
    return TerminalState(
      config: repo.config,
      isLoaded: repo.isLoaded,
      isConfigured: repo.isConfigured,
    );
  }

  final TerminalConfig config;
  final bool isLoaded;
  final bool isConfigured;

  PosRole get role => config.posRole;

  TerminalState copyWith({
    TerminalConfig? config,
    bool? isLoaded,
    bool? isConfigured,
  }) {
    return TerminalState(
      config: config ?? this.config,
      isLoaded: isLoaded ?? this.isLoaded,
      isConfigured: isConfigured ?? this.isConfigured,
    );
  }

  @override
  List<Object?> get props => [config, isLoaded, isConfigured];
}
