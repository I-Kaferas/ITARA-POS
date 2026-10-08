part of 'printer_discovery_bloc.dart';

enum PrinterDiscoveryStatus { initial, loading, ready, failure }

final class PrinterDiscoveryState extends Equatable {
  const PrinterDiscoveryState({
    this.status = PrinterDiscoveryStatus.initial,
    this.errorMessage,
  });

  final PrinterDiscoveryStatus status;
  final String? errorMessage;

  bool get isLoading => status == PrinterDiscoveryStatus.loading;

  PrinterDiscoveryState copyWith({
    PrinterDiscoveryStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PrinterDiscoveryState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
