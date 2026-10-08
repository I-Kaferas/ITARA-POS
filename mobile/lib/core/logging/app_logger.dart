import 'dart:async';

import 'package:logger/logger.dart';

import 'log_store.dart';
import 'log_type.dart';

/// Structured logger with persistent channels (§57 LOGGING).
///
/// Channels: INFO, WARNING, ERROR, SYNC, NETWORK, PRINTER, DATABASE,
/// SECURITY, DISCOVERY, PAIRING.
class AppLogger {
  AppLogger({Logger? logger, LogStore? store})
      : _logger = logger ??
            Logger(
              printer: PrettyPrinter(
                methodCount: 0,
                errorMethodCount: 6,
                lineLength: 100,
                colors: false,
                printEmojis: false,
              ),
            ),
        _store = store,
        _defaultTag = null,
        _defaultType = null;

  AppLogger._scoped(
    this._logger,
    this._store,
    this._defaultTag,
    this._defaultType,
  );

  final Logger _logger;
  LogStore? _store;
  final String? _defaultTag;
  final LogType? _defaultType;

  /// Attach / replace the persistent store (called after DI boot).
  void attachStore(LogStore store) => _store = store;

  void debug(String message, {String? tag, LogType? type, Map<String, dynamic>? context}) {
    final effectiveTag = tag ?? _defaultTag;
    _logger.d(_format(effectiveTag, message));
    // Debug stays console-only to avoid flooding the diagnostic buffer.
  }

  void info(
    String message, {
    String? tag,
    LogType? type,
    Map<String, dynamic>? context,
  }) {
    _write(
      type: type ?? _defaultType ?? LogType.fromTag(tag ?? _defaultTag),
      severity: 'info',
      message: message,
      tag: tag ?? _defaultTag,
      context: context,
    );
  }

  void warn(
    String message, {
    String? tag,
    LogType? type,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    warning(
      message,
      tag: tag,
      type: type,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  void warning(
    String message, {
    String? tag,
    LogType? type,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final resolved = type ??
        _defaultType ??
        LogType.fromTag(tag ?? _defaultTag, fallback: LogType.warning);
    _write(
      type: resolved.isSeverity ? LogType.warning : resolved,
      severity: 'warning',
      message: message,
      tag: tag ?? _defaultTag,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  void error(
    String message, {
    String? tag,
    LogType? type,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final resolved = type ??
        _defaultType ??
        LogType.fromTag(tag ?? _defaultTag, fallback: LogType.error);
    _write(
      type: resolved.isSeverity ? LogType.error : resolved,
      severity: 'error',
      message: message,
      tag: tag ?? _defaultTag,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  void sync(String message, {Map<String, dynamic>? context}) =>
      info(message, type: LogType.sync, tag: 'sync', context: context);

  void network(String message, {Map<String, dynamic>? context}) =>
      info(message, type: LogType.network, tag: 'network', context: context);

  void printer(String message, {Map<String, dynamic>? context}) =>
      info(message, type: LogType.printer, tag: 'printer', context: context);

  void database(String message, {Map<String, dynamic>? context}) =>
      info(message, type: LogType.database, tag: 'database', context: context);

  void security(String message, {Map<String, dynamic>? context}) =>
      info(message, type: LogType.security, tag: 'security', context: context);

  void discovery(String message, {Map<String, dynamic>? context}) =>
      info(message, type: LogType.discovery, tag: 'discovery', context: context);

  void pairing(String message, {Map<String, dynamic>? context}) =>
      info(message, type: LogType.pairing, tag: 'pairing', context: context);

  AppLogger tagged(String tag) => AppLogger._scoped(
        _logger,
        _store,
        tag,
        LogType.fromTag(tag),
      );

  AppLogger channel(LogType type) => AppLogger._scoped(
        _logger,
        _store,
        type.name,
        type,
      );

  void _write({
    required LogType type,
    required String severity,
    required String message,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final formatted = _format(tag, message);
    switch (severity) {
      case 'warning':
        _logger.w(formatted, error: error, stackTrace: stackTrace);
      case 'error':
        _logger.e(formatted, error: error, stackTrace: stackTrace);
      default:
        _logger.i(formatted);
    }

    final store = _store;
    if (store == null) return;
    unawaited(() async {
      try {
        await store.append(
          type: type,
          severity: severity,
          message: message,
          tag: tag,
          error: error,
          stackTrace: stackTrace,
          context: context,
        );
      } catch (_) {
        // Persistence must never break the call site.
      }
    }());
  }

  String _format(String? tag, String message) {
    final effective = tag ?? _defaultTag;
    if (effective == null || effective.isEmpty) return message;
    return '[$effective] $message';
  }
}
