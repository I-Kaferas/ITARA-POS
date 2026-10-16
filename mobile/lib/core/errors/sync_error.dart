import 'app_error.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Catalog / outbox / cloud synchronization failure.
final class SyncError extends AppError {
  const SyncError({
    super.title = 'Synchronisation interrompue.',
    super.detail =
        'Vous pouvez continuer à vendre. La synchro reprendra automatiquement.',
    super.cause,
  }) : super(code: 'errors.sync');

  factory SyncError.conflict({Object? cause}) => SyncError(
        title: tr('Conflit de synchronisation.'),
        detail:
            tr('Une donnée a changé ailleurs. Actualisez ou choisissez la version à conserver.'),
        cause: cause,
      );

  factory SyncError.queueFull({Object? cause}) => SyncError(
        title: tr('File hors-ligne saturée.'),
        detail: tr('Reconnectez-vous au réseau pour synchroniser avant de continuer.'),
        cause: cause,
      );
}
