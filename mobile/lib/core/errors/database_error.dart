import 'app_error.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Local SQLite / persistence failure.
final class DatabaseError extends AppError {
  const DatabaseError({
    super.title = 'Enregistrement local impossible.',
    super.detail =
        'Réessayez dans un instant. Si le problème continue, contactez le support.',
    super.cause,
  }) : super(code: 'errors.database');

  factory DatabaseError.corrupt({Object? cause}) => DatabaseError(
        title: tr('Base locale endommagée.'),
        detail:
            tr('Les ventes déjà enregistrées sont protégées. Contactez le support ITARA.'),
        cause: cause,
      );

  factory DatabaseError.writeFailed({Object? cause}) => DatabaseError(
        cause: cause,
      );
}
