import 'app_error.dart';

/// Session expired or credentials rejected.
final class AuthenticationError extends AppError {
  const AuthenticationError({
    super.title = 'Session expirée.',
    super.detail = 'Reconnectez-vous pour continuer.',
    super.cause,
  }) : super(code: 'errors.authentication');

  factory AuthenticationError.invalidCredentials({Object? cause}) =>
      AuthenticationError(
        title: 'Identifiants incorrects.',
        detail: 'Vérifiez votre e-mail, mot de passe ou code PIN puis réessayez.',
        cause: cause,
      );

  factory AuthenticationError.pinRequired({Object? cause}) =>
      AuthenticationError(
        title: 'Code PIN requis.',
        detail: 'Saisissez votre code PIN pour déverrouiller la caisse.',
        cause: cause,
      );
}
