part of 'shift_bloc.dart';

enum ShiftStatus { initial, loading, ready, failure }

final class ShiftState extends Equatable {
  const ShiftState({
    this.status = ShiftStatus.initial,
    this.errorMessage,
  });

  final ShiftStatus status;
  final String? errorMessage;

  bool get isLoading => status == ShiftStatus.loading;

  ShiftState copyWith({
    ShiftStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ShiftState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
