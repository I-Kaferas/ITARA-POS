part of 'authentication_bloc.dart';

enum AuthenticationStatus {
  unknown,
  unauthenticated,
  loading,
  authenticated,
  failure,
}

class AuthenticationState extends Equatable {
  const AuthenticationState({
    required this.status,
    this.session,
    this.errorMessage,
  });

  const AuthenticationState.unknown()
      : this(status: AuthenticationStatus.unknown);

  const AuthenticationState.unauthenticated()
      : this(status: AuthenticationStatus.unauthenticated);

  const AuthenticationState.authenticated({AuthSession? session})
      : this(status: AuthenticationStatus.authenticated, session: session);

  const AuthenticationState.failure(String message)
      : this(status: AuthenticationStatus.failure, errorMessage: message);

  final AuthenticationStatus status;
  final AuthSession? session;
  final String? errorMessage;

  bool get isLoading => status == AuthenticationStatus.loading;
  bool get isAuthenticated => status == AuthenticationStatus.authenticated;

  AuthenticationState copyWith({
    AuthenticationStatus? status,
    AuthSession? session,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthenticationState(
      status: status ?? this.status,
      session: session ?? this.session,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, session, errorMessage];
}
