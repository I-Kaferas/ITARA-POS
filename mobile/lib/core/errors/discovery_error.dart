import 'app_error.dart';

/// LAN Master / printer discovery failure.
final class DiscoveryError extends AppError {
  const DiscoveryError({
    super.title = 'Aucun appareil trouvé sur le réseau.',
    super.detail =
        'Assurez-vous d’être sur le même Wi-Fi que le Master, puis relancez la recherche.',
    super.cause,
  }) : super(code: 'errors.discovery');

  factory DiscoveryError.timeout({Object? cause}) => DiscoveryError(
        title: 'Recherche réseau terminée sans résultat.',
        detail:
            'Vérifiez le Wi-Fi ou saisissez l’adresse du Master manuellement.',
        cause: cause,
      );

  factory DiscoveryError.notSupported({Object? cause}) => DiscoveryError(
        title: 'Découverte réseau indisponible.',
        detail:
            'Cet appareil ne peut pas scanner le réseau. Utilisez le code QR ou l’adresse IP.',
        cause: cause,
      );
}
