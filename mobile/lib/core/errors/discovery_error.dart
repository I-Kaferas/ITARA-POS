import 'app_error.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// LAN Master / printer discovery failure.
final class DiscoveryError extends AppError {
  const DiscoveryError({
    super.title = 'Aucun appareil trouvé sur le réseau.',
    super.detail =
        'Assurez-vous d’être sur le même Wi-Fi que le Master, puis relancez la recherche.',
    super.cause,
  }) : super(code: 'errors.discovery');

  factory DiscoveryError.timeout({Object? cause}) => DiscoveryError(
        title: tr('Recherche réseau terminée sans résultat.'),
        detail:
            tr('Vérifiez le Wi-Fi ou saisissez l’adresse du Master manuellement.'),
        cause: cause,
      );

  factory DiscoveryError.notSupported({Object? cause}) => DiscoveryError(
        title: tr('Découverte réseau indisponible.'),
        detail:
            tr('Cet appareil ne peut pas scanner le réseau. Utilisez le code QR ou l’adresse IP.'),
        cause: cause,
      );
}
