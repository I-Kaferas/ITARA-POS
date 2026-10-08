import 'app_error.dart';

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
        title: 'Permission insuffisante.',
        detail:
            'Il vous manque le droit « $permission ». Demandez à un administrateur.',
        permission: permission,
        cause: cause,
      );

  factory PermissionError.osDenied(String feature, {Object? cause}) =>
      PermissionError(
        title: 'Accès système refusé.',
        detail:
            'Autorisez « $feature » dans les réglages de l’appareil puis réessayez.',
        permission: feature,
        cause: cause,
      );
}
