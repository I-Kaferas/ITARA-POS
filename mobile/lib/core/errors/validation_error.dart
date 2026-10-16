import 'app_error.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// User input failed business or form rules.
final class ValidationError extends AppError {
  const ValidationError({
    super.title = 'Informations incomplètes ou incorrectes.',
    super.detail = 'Vérifiez les champs indiqués puis réessayez.',
    this.fields = const {},
    super.cause,
  }) : super(code: 'errors.validation');

  /// Field → first human message (already localized when possible).
  final Map<String, String> fields;

  factory ValidationError.field(
    String field,
    String message, {
    Object? cause,
  }) =>
      ValidationError(
        title: message,
        detail: trf('Corrigez « {0} » puis réessayez.', [field]),
        fields: {field: message},
        cause: cause,
      );
}
