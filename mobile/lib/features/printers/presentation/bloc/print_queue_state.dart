part of 'print_queue_bloc.dart';

enum PrintQueueStatus { initial, loading, ready, failure }

final class PrintQueueState extends Equatable {
  const PrintQueueState({
    this.status = PrintQueueStatus.initial,
    this.jobs = const [],
    this.errorMessage,
  });

  final PrintQueueStatus status;
  final List<PrintJob> jobs;
  final String? errorMessage;

  bool get isLoading => status == PrintQueueStatus.loading;

  int get pendingCount =>
      jobs.where((j) => j.status.name == 'pending' || j.status.name == 'retrying').length;

  PrintQueueState copyWith({
    PrintQueueStatus? status,
    List<PrintJob>? jobs,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PrintQueueState(
      status: status ?? this.status,
      jobs: jobs ?? this.jobs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, jobs, errorMessage];
}
