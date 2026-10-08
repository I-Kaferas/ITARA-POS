import '../api/api_client.dart';
import 'app_error.dart';
import 'authentication_error.dart';
import 'database_error.dart';
import 'discovery_error.dart';
import 'master_connection_error.dart';
import 'network_error.dart';
import 'pairing_error.dart';
import 'permission_error.dart';
import 'printer_error.dart';
import 'sync_error.dart';
import 'validation_error.dart';

/// Maps any thrown value to a typed [AppError] with a safe user message.
AppError resolveAppError(Object? error, {String? fallbackCode}) {
  if (error is AppError) {
    return error;
  }

  if (error is ApiException) {
    return _fromApiException(error);
  }

  final raw = error?.toString() ?? '';
  final normalized = raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  final lower = normalized.toLowerCase();

  if (_looksLikeNetwork(lower)) {
    return NetworkError(cause: error);
  }
  if (_looksLikeAuth(lower)) {
    return AuthenticationError(cause: error);
  }
  if (_looksLikePermission(lower)) {
    return PermissionError(cause: error);
  }
  if (_looksLikeValidation(lower)) {
    return ValidationError(title: _safeTitle(normalized), cause: error);
  }
  if (_looksLikeDatabase(lower)) {
    return DatabaseError(cause: error);
  }
  if (_looksLikeSync(lower)) {
    return SyncError(cause: error);
  }
  if (_looksLikePrinter(lower)) {
    return PrinterError(cause: error);
  }
  if (_looksLikeMaster(lower)) {
    return MasterConnectionError(cause: error);
  }
  if (_looksLikeDiscovery(lower)) {
    return DiscoveryError(cause: error);
  }
  if (_looksLikePairing(lower)) {
    return PairingError(cause: error);
  }

  return SyncError(
    title: fallbackCode == 'errors.network'
        ? 'Connexion Internet indisponible.'
        : 'Une erreur est survenue.',
    detail: fallbackCode == 'errors.network'
        ? 'La vente est enregistrée localement et sera synchronisée automatiquement.'
        : 'Réessayez. Si le problème continue, contactez le support.',
    cause: error,
  );
}

/// Convenience: user-facing multi-line message only.
String userErrorMessage(Object? error, {String? fallbackCode}) {
  return resolveAppError(error, fallbackCode: fallbackCode).userMessage;
}

AppError _fromApiException(ApiException error) {
  final status = error.statusCode;
  final message = error.message.trim();
  final lower = message.toLowerCase();

  if (status == 401 || lower.contains('errors.unauthenticated') || lower.contains('errors.authentication')) {
    return AuthenticationError(cause: error);
  }
  if (status == 403 || lower.contains('errors.forbidden') || lower.contains('errors.permission')) {
    return PermissionError(cause: error);
  }
  if (status == 422 || lower.contains('errors.validation')) {
    return ValidationError(
      title: _isTechnical(message) ? 'Informations incomplètes ou incorrectes.' : message,
      cause: error,
    );
  }
  if (status == 0 || status >= 502) {
    return NetworkError(cause: error);
  }
  if (lower.startsWith('errors.')) {
    return _fromCode(message, cause: error);
  }
  if (status >= 500) {
    return SyncError(
      title: 'Le serveur a rencontré un problème.',
      detail: 'Réessayez dans un instant. Vos données locales sont conservées.',
      cause: error,
    );
  }

  return ValidationError(
    title: _isTechnical(message) ? 'La demande n’a pas pu être traitée.' : message,
    detail: 'Vérifiez les informations puis réessayez.',
    cause: error,
  );
}

AppError _fromCode(String code, {Object? cause}) {
  return switch (code) {
    'errors.network' || 'errors.connection' || 'errors.offline' => NetworkError(cause: cause),
    'errors.authentication' || 'errors.unauthenticated' => AuthenticationError(cause: cause),
    'errors.validation' => ValidationError(cause: cause),
    'errors.database' => DatabaseError(cause: cause),
    'errors.sync' || 'errors.sync_failed' => SyncError(cause: cause),
    'errors.printer' => PrinterError(cause: cause),
    'errors.permission' || 'errors.forbidden' => PermissionError(cause: cause),
    'errors.master_connection' => MasterConnectionError(cause: cause),
    'errors.discovery' => DiscoveryError(cause: cause),
    'errors.pairing' => PairingError(cause: cause),
    _ => SyncError(cause: cause),
  };
}

bool _looksLikeNetwork(String lower) =>
    lower.contains('socket') ||
    lower.contains('network') ||
    lower.contains('connection refused') ||
    lower.contains('failed host lookup') ||
    lower.contains('connexion') ||
    lower.contains('offline') ||
    lower.contains('unreachable') ||
    lower.contains('timed out') ||
    lower.contains('timeout');

bool _looksLikeAuth(String lower) =>
    lower.contains('unauthenticated') ||
    lower.contains('unauthorized') ||
    lower.contains('session') ||
    lower.contains('token') ||
    lower.contains('identifiant') ||
    lower.contains('password') ||
    lower.contains('pin');

bool _looksLikePermission(String lower) =>
    lower.contains('forbidden') ||
    lower.contains('permission') ||
    lower.contains('not allowed') ||
    lower.contains('non autoris');

bool _looksLikeValidation(String lower) =>
    lower.contains('validation') ||
    lower.contains('invalid') ||
    lower.contains('required') ||
    lower.contains('incorrect');

bool _looksLikeDatabase(String lower) =>
    lower.contains('sqlite') ||
    lower.contains('database') ||
    lower.contains('sqlstate') ||
    lower.contains('db_') ||
    lower.contains('drift');

bool _looksLikeSync(String lower) =>
    lower.contains('sync') ||
    lower.contains('outbox') ||
    lower.contains('conflict');

bool _looksLikePrinter(String lower) =>
    lower.contains('printer') ||
    lower.contains('imprimante') ||
    lower.contains('print ');

bool _looksLikeMaster(String lower) =>
    lower.contains('master') &&
    (lower.contains('connect') || lower.contains('injoignable') || lower.contains('unreachable'));

bool _looksLikeDiscovery(String lower) =>
    lower.contains('discovery') ||
    lower.contains('découverte') ||
    lower.contains('beacon') ||
    lower.contains('mdns');

bool _looksLikePairing(String lower) =>
    lower.contains('pairing') ||
    lower.contains('appairage') ||
    lower.contains('pair ');

bool _isTechnical(String message) {
  final lower = message.toLowerCase();
  return lower.startsWith('http ') ||
      lower.contains('sqlstate') ||
      lower.contains('exception') ||
      lower.contains('stack trace') ||
      RegExp(r'^[A-Z_]+$').hasMatch(message);
}

String _safeTitle(String raw) {
  if (raw.isEmpty || _isTechnical(raw) || raw.length > 180) {
    return 'Informations incomplètes ou incorrectes.';
  }
  return raw;
}
