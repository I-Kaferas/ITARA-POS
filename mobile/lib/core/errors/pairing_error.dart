import 'app_error.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Secure Master ↔ Slave pairing failure.
final class PairingError extends AppError {
  const PairingError({
    super.title = 'Appairage impossible.',
    super.detail =
        'Vérifiez le code affiché sur le Master et réessayez dans le délai imparti.',
    super.cause,
  }) : super(code: 'errors.pairing');

  factory PairingError.invalidCode({Object? cause}) => PairingError(
        title: tr('Code d’appairage incorrect.'),
        detail: tr('Saisissez le code à 6 chiffres affiché sur le Master.'),
        cause: cause,
      );

  factory PairingError.expired({Object? cause}) => PairingError(
        title: tr('Code d’appairage expiré.'),
        detail: tr('Demandez un nouveau code sur le Master puis réessayez.'),
        cause: cause,
      );

  factory PairingError.rejected({Object? cause}) => PairingError(
        title: tr('Appairage refusé par le Master.'),
        detail: tr('Demandez au responsable d’accepter la demande sur le Master.'),
        cause: cause,
      );

  factory PairingError.alreadyPaired({Object? cause}) => PairingError(
        title: tr('Cet appareil est déjà appairé.'),
        detail: tr('Supprimez l’ancien appairage avant d’en créer un nouveau.'),
        cause: cause,
      );
}
