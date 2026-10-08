/// Application log channels (§57 LOGGING).
enum LogType {
  info,
  warning,
  error,
  sync,
  network,
  printer,
  database,
  security,
  discovery,
  pairing;

  String get label => name.toUpperCase();

  bool get isSeverity =>
      this == LogType.info || this == LogType.warning || this == LogType.error;

  bool get isDomain => !isSeverity;

  static LogType? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final type in LogType.values) {
      if (type.name == normalized) return type;
    }
    return null;
  }

  /// Maps legacy / module tags to a domain channel when possible.
  static LogType fromTag(String? tag, {LogType fallback = LogType.info}) {
    if (tag == null || tag.isEmpty) return fallback;
    final mapped = tryParse(tag);
    if (mapped != null) return mapped;
    return switch (tag.toLowerCase()) {
      'auth' || 'security' || 'token' => LogType.security,
      'db' || 'sqlite' || 'storage' => LogType.database,
      'print' || 'receipt' => LogType.printer,
      'mdns' || 'nsd' || 'beacon' || 'lan' => LogType.discovery,
      'pair' || 'pairing' => LogType.pairing,
      'sync' || 'outbox' || 'offline' => LogType.sync,
      'network' || 'http' || 'api' => LogType.network,
      _ => fallback,
    };
  }
}
