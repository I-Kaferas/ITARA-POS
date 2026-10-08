part of 'printer_connection_bloc.dart';

enum PrinterConnectionStatus { initial, loading, ready, failure }

final class PrinterConnectionState extends Equatable {
  const PrinterConnectionState({
    this.status = PrinterConnectionStatus.initial,
    this.errorMessage,
  });

  final PrinterConnectionStatus status;
  final String? errorMessage;

  bool get isLoading => status == PrinterConnectionStatus.loading;

  PrinterConnectionState copyWith({
    PrinterConnectionStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PrinterConnectionState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
