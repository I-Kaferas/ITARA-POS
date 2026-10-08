import 'app_error.dart';

/// Secure Master ↔ Slave pairing failure.
final class PairingError extends AppError {
  const PairingError({
    super.title = 'Appairage impossible.',
    super.detail =
        'Vérifiez le code affiché sur le Master et réessayez dans le délai imparti.',
    super.cause,
  }) : super(code: 'errors.pairing');

  factory PairingError.invalidCode({Object? cause}) => PairingError(
        title: 'Code d’appairage incorrect.',
        detail: 'Saisissez le code à 6 chiffres affiché sur le Master.',
        cause: cause,
      );

  factory PairingError.expired({Object? cause}) => PairingError(
        title: 'Code d’appairage expiré.',
        detail: 'Demandez un nouveau code sur le Master puis réessayez.',
        cause: cause,
      );

  factory PairingError.rejected({Object? cause}) => PairingError(
        title: 'Appairage refusé par le Master.',
        detail: 'Demandez au responsable d’accepter la demande sur le Master.',
        cause: cause,
      );

  factory PairingError.alreadyPaired({Object? cause}) => PairingError(
        title: 'Cet appareil est déjà appairé.',
        detail: 'Supprimez l’ancien appairage avant d’en créer un nouveau.',
        cause: cause,
      );
}
