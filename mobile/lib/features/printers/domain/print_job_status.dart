/// Print queue lifecycle (mobile.md §42).
enum PrintJobStatus {
  pending,
  printing,
  printed,
  failed,
  retrying,
  cancelled;

  static PrintJobStatus fromString(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    // Legacy spooler statuses.
    switch (raw) {
      case 'queued':
        return PrintJobStatus.pending;
      case 'done':
        return PrintJobStatus.printed;
    }
    return PrintJobStatus.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => PrintJobStatus.pending,
    );
  }

  bool get isTerminal =>
      this == PrintJobStatus.printed || this == PrintJobStatus.cancelled;

  bool get isActive =>
      this == PrintJobStatus.pending ||
      this == PrintJobStatus.printing ||
      this == PrintJobStatus.retrying;
}
