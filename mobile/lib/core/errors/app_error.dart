/// Typed application errors with user-friendly messages (mobile.md §56).
///
/// Always expose a short [title] and optional reassuring [detail] so cashiers
/// understand what happened and what to do next — never stack traces.
sealed class AppError implements Exception {
  const AppError({
    required this.code,
    required this.title,
    this.detail,
    this.cause,
  });

  /// Stable machine code (e.g. `errors.network`) for logging / analytics.
  final String code;

  /// First line shown to the user.
  final String title;

  /// Optional second line — next step or reassurance.
  final String? detail;

  /// Underlying technical cause (logs only — never shown in UI).
  final Object? cause;

  /// Full user-facing text (title + detail).
  String get userMessage {
    final extra = detail?.trim();
    if (extra == null || extra.isEmpty) {
      return title;
    }
    return '$title\n$extra';
  }

  @override
  String toString() => userMessage;
}
