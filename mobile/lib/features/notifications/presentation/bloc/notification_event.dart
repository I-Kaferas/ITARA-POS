part of 'notification_bloc.dart';

sealed class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => const [];
}

final class NotificationStarted extends NotificationEvent {
  const NotificationStarted();
}

final class NotificationRefreshed extends NotificationEvent {
  const NotificationRefreshed();
}
