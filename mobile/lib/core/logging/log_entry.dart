import 'log_type.dart';

class LogEntry {
  const LogEntry({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    required this.createdAt,
    this.tag,
    this.error,
    this.stackTrace,
    this.context,
  });

  final String id;
  final LogType type;

  /// `info` | `warning` | `error`
  final String severity;
  final String message;
  final String? tag;
  final String? error;
  final String? stackTrace;
  final Map<String, dynamic>? context;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.label,
        'severity': severity,
        'message': message,
        if (tag != null) 'tag': tag,
        if (error != null) 'error': error,
        if (stackTrace != null) 'stack_trace': stackTrace,
        if (context != null) 'context': context,
        'created_at': createdAt.toIso8601String(),
      };

  String toLine() {
    final buffer = StringBuffer()
      ..write(createdAt.toIso8601String())
      ..write(' [')
      ..write(type.label)
      ..write('/')
      ..write(severity.toUpperCase())
      ..write('] ')
      ..write(message);
    if (tag != null && tag!.isNotEmpty) {
      buffer.write(' {$tag}');
    }
    if (error != null) {
      buffer.write(' error=$error');
    }
    return buffer.toString();
  }
}
