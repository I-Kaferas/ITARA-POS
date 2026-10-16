import 'app_error.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Missing RBAC permission or OS permission.
final class PermissionError extends AppError {
  const PermissionError({
    super.title = 'Action non autorisée.',
    super.detail = 'Demandez à un responsable d’approuver ou de vous attribuer le droit.',
    this.permission,
    super.cause,
  }) : super(code: 'errors.permission');

  final String? permission;

  factory PermissionError.denied(String permission, {Object? cause}) =>
      PermissionError(
        title: tr('Permission insuffisante.'),
        detail:
            trf('Il vous manque le droit « {0} ». Demandez à un administrateur.', [permission]),
        permission: permission,
        cause: cause,
      );

  factory PermissionError.osDenied(String feature, {Object? cause}) =>
      PermissionError(
        title: tr('Accès système refusé.'),
        detail:
            trf('Autorisez « {0} » dans les réglages de l’appareil puis réessayez.', [feature]),
        permission: feature,
        cause: cause,
      );
}
