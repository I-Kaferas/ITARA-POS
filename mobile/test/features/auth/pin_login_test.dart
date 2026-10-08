import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:pos_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:pos_mobile/features/auth/domain/usecases/pin_login.dart';

class _FakeAuthRepository implements AuthRepository {
  AuthSession? lastSession;
  String? lastPin;
  bool signedIn = false;

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<AuthSession> pinLogin(String pin) async {
    return AuthSession(
      id: 'u1',
      name: 'Cashier',
      token: 'tok',
      refreshToken: 'ref',
      expiresIn: 3600,
      permissions: const ['pos.sell'],
      roles: const ['cashier'],
    );
  }

  @override
  Future<void> persistSession(AuthSession session, {required String pin}) async {
    lastSession = session;
    lastPin = pin;
    signedIn = true;
  }

  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> signOut() async {
    signedIn = false;
  }
}

void main() {
  test('PinLogin rejects non-4-digit PIN', () async {
    final useCase = PinLogin(_FakeAuthRepository());
    expect(() => useCase('12'), throwsA(isA<ArgumentError>()));
  });

  test('PinLogin persists session after successful login', () async {
    final repo = _FakeAuthRepository();
    final useCase = PinLogin(repo);
    final session = await useCase('1234');
    expect(session.id, 'u1');
    expect(repo.lastPin, '1234');
    expect(repo.signedIn, isTrue);
  });
}
