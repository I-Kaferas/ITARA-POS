part of 'printer_configuration_bloc.dart';

enum PrinterConfigurationStatus { initial, loading, ready, failure }

final class PrinterConfigurationState extends Equatable {
  const PrinterConfigurationState({
    this.status = PrinterConfigurationStatus.initial,
    this.errorMessage,
  });

  final PrinterConfigurationStatus status;
  final String? errorMessage;

  bool get isLoading => status == PrinterConfigurationStatus.loading;

  PrinterConfigurationState copyWith({
    PrinterConfigurationStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PrinterConfigurationState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
