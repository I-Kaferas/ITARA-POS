import 'app_error.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Slave ↔ Master LAN link failure.
final class MasterConnectionError extends AppError {
  const MasterConnectionError({
    super.title = 'Connexion au Master perdue.',
    super.detail =
        'La caisse continue en mode hors-ligne. La synchro reprendra dès que le Master sera joignable.',
    super.cause,
  }) : super(code: 'errors.master_connection');

  factory MasterConnectionError.unreachable({Object? cause}) =>
      MasterConnectionError(
        title: tr('Master injoignable sur le réseau local.'),
        detail:
            tr('Vérifiez que le Master est allumé et sur le même Wi-Fi, puis réessayez.'),
        cause: cause,
      );

  factory MasterConnectionError.refused({Object? cause}) =>
      MasterConnectionError(
        title: tr('Connexion au Master refusée.'),
        detail: tr('Cet appareil n’est peut-être plus appairé. Relancez l’appairage.'),
        cause: cause,
      );
}
