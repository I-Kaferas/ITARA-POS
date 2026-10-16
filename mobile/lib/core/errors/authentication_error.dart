import 'app_error.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Session expired or credentials rejected.
final class AuthenticationError extends AppError {
  const AuthenticationError({
    super.title = 'Session expirée.',
    super.detail = 'Reconnectez-vous pour continuer.',
    super.cause,
  }) : super(code: 'errors.authentication');

  factory AuthenticationError.invalidCredentials({Object? cause}) =>
      AuthenticationError(
        title: tr('Identifiants incorrects.'),
        detail: tr('Vérifiez votre e-mail, mot de passe ou code PIN puis réessayez.'),
        cause: cause,
      );

  factory AuthenticationError.pinRequired({Object? cause}) =>
      AuthenticationError(
        title: tr('Code PIN requis.'),
        detail: tr('Saisissez votre code PIN pour déverrouiller la caisse.'),
        cause: cause,
      );
}
