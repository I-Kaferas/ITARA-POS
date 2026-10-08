part of 'authentication_bloc.dart';

sealed class AuthenticationEvent extends Equatable {
  const AuthenticationEvent();

  @override
  List<Object?> get props => [];
}

final class AuthenticationSessionRestored extends AuthenticationEvent {
  const AuthenticationSessionRestored();
}

final class AuthenticationPinSubmitted extends AuthenticationEvent {
  const AuthenticationPinSubmitted(this.pin);

  final String pin;

  @override
  List<Object?> get props => [pin];
}

final class AuthenticationLogoutRequested extends AuthenticationEvent {
  const AuthenticationLogoutRequested();
}
