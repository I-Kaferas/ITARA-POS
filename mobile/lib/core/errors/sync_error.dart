import 'app_error.dart';

/// Catalog / outbox / cloud synchronization failure.
final class SyncError extends AppError {
  const SyncError({
    super.title = 'Synchronisation interrompue.',
    super.detail =
        'Vous pouvez continuer à vendre. La synchro reprendra automatiquement.',
    super.cause,
  }) : super(code: 'errors.sync');

  factory SyncError.conflict({Object? cause}) => SyncError(
        title: 'Conflit de synchronisation.',
        detail:
            'Une donnée a changé ailleurs. Actualisez ou choisissez la version à conserver.',
        cause: cause,
      );

  factory SyncError.queueFull({Object? cause}) => SyncError(
        title: 'File hors-ligne saturée.',
        detail: 'Reconnectez-vous au réseau pour synchroniser avant de continuer.',
        cause: cause,
      );
}
