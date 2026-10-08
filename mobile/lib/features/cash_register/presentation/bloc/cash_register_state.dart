part of 'cash_register_bloc.dart';

enum CashRegisterStatus { initial, loading, ready, failure }

final class CashRegisterState extends Equatable {
  const CashRegisterState({
    this.status = CashRegisterStatus.initial,
    this.registers = const [],
    this.selectedRegisterId,
    this.summary,
    this.reconciliation,
    this.busy = false,
    this.errorMessage,
    this.message,
  });

  final CashRegisterStatus status;
  final List<CashRegister> registers;
  final String? selectedRegisterId;
  final RegisterSummary? summary;
  final Reconciliation? reconciliation;
  final bool busy;
  final String? errorMessage;
  final String? message;

  bool get isLoading => status == CashRegisterStatus.loading;

  CashRegister? get selectedRegister {
    if (selectedRegisterId == null) return null;
    for (final register in registers) {
      if (register.id == selectedRegisterId) return register;
    }
    return null;
  }

  CashRegisterState copyWith({
    CashRegisterStatus? status,
    List<CashRegister>? registers,
    String? selectedRegisterId,
    RegisterSummary? summary,
    Reconciliation? reconciliation,
    bool? busy,
    String? errorMessage,
    String? message,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return CashRegisterState(
      status: status ?? this.status,
      registers: registers ?? this.registers,
      selectedRegisterId: selectedRegisterId ?? this.selectedRegisterId,
      summary: summary ?? this.summary,
      reconciliation: reconciliation ?? this.reconciliation,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => [
        status,
        registers,
        selectedRegisterId,
        summary,
        reconciliation,
        busy,
        errorMessage,
        message,
      ];
}
