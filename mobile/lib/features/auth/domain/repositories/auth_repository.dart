import '../entities/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> pinLogin(String pin);

  Future<void> persistSession(AuthSession session, {required String pin});

  Future<void> signOut();

  Future<void> restoreSession();

  bool get isSignedIn;
}
