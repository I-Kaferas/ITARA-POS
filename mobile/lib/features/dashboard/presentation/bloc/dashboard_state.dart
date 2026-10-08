part of 'dashboard_bloc.dart';

enum DashboardStatus { initial, loading, ready, failure }

final class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.errorMessage,
  });

  final DashboardStatus status;
  final String? errorMessage;

  bool get isLoading => status == DashboardStatus.loading;

  DashboardState copyWith({
    DashboardStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
