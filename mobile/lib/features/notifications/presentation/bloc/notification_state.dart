part of 'notification_bloc.dart';

enum NotificationStatus { initial, loading, ready, failure }

final class NotificationState extends Equatable {
  const NotificationState({
    this.status = NotificationStatus.initial,
    this.errorMessage,
  });

  final NotificationStatus status;
  final String? errorMessage;

  bool get isLoading => status == NotificationStatus.loading;

  NotificationState copyWith({
    NotificationStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
