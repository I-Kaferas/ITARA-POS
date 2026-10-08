import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'notification_event.dart';
part 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc() : super(const NotificationState()) {
    on<NotificationStarted>(_onStarted);
    on<NotificationRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    NotificationStarted event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(status: NotificationStatus.loading, clearError: true));
    emit(state.copyWith(status: NotificationStatus.ready));
  }

  Future<void> _onRefreshed(
    NotificationRefreshed event,
    Emitter<NotificationState> emit,
  ) async {
    add(const NotificationStarted());
  }
}
