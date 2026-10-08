import 'app_error.dart';

/// No usable Internet / cloud connection.
final class NetworkError extends AppError {
  const NetworkError({
    super.title = 'Connexion Internet indisponible.',
    super.detail =
        'La vente est enregistrée localement et sera synchronisée automatiquement.',
    super.cause,
  }) : super(code: 'errors.network');

  /// Generic unreachable server (cloud or Master).
  factory NetworkError.unreachable({Object? cause}) => NetworkError(
        title: 'Serveur injoignable.',
        detail: 'Vérifiez le réseau puis réessayez. Les données locales sont conservées.',
        cause: cause,
      );

  /// Offline sale already queued for sync.
  factory NetworkError.saleQueuedLocally({Object? cause}) => NetworkError(
        cause: cause,
      );
}
