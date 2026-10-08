import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class PinLogin {
  const PinLogin(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call(String pin) async {
    final normalized = pin.trim();
    if (normalized.length != 4) {
      throw ArgumentError('Le code PIN doit contenir 4 chiffres.');
    }
    final session = await _repository.pinLogin(normalized);
    await _repository.persistSession(session, pin: normalized);
    return session;
  }
}
