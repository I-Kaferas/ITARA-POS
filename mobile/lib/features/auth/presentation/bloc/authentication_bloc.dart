import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/pin_login.dart';
import '../../domain/usecases/sign_out.dart';

part 'authentication_event.dart';
part 'authentication_state.dart';

class AuthenticationBloc extends Bloc<AuthenticationEvent, AuthenticationState> {
  AuthenticationBloc({
    required PinLogin pinLogin,
    required SignOut signOut,
    required AuthRepository authRepository,
  })  : _pinLogin = pinLogin,
        _signOut = signOut,
        _authRepository = authRepository,
        super(const AuthenticationState.unknown()) {
    on<AuthenticationSessionRestored>(_onRestore);
    on<AuthenticationPinSubmitted>(_onPinSubmitted);
    on<AuthenticationLogoutRequested>(_onLogout);
  }

  final PinLogin _pinLogin;
  final SignOut _signOut;
  final AuthRepository _authRepository;

  Future<void> _onRestore(
    AuthenticationSessionRestored event,
    Emitter<AuthenticationState> emit,
  ) async {
    await _authRepository.restoreSession();
    if (_authRepository.isSignedIn) {
      emit(const AuthenticationState.authenticated());
    } else {
      emit(const AuthenticationState.unauthenticated());
    }
  }

  Future<void> _onPinSubmitted(
    AuthenticationPinSubmitted event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(state.copyWith(status: AuthenticationStatus.loading, clearError: true));
    try {
      final session = await _pinLogin(event.pin);
      emit(AuthenticationState.authenticated(session: session));
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      emit(AuthenticationState.failure(message));
    }
  }

  Future<void> _onLogout(
    AuthenticationLogoutRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(state.copyWith(status: AuthenticationStatus.loading, clearError: true));
    try {
      await _signOut();
      emit(const AuthenticationState.unauthenticated());
    } catch (error) {
      emit(AuthenticationState.failure(
        error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }
}
