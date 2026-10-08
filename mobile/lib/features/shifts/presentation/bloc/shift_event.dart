part of 'shift_bloc.dart';

sealed class ShiftEvent extends Equatable {
  const ShiftEvent();

  @override
  List<Object?> get props => const [];
}

final class ShiftStarted extends ShiftEvent {
  const ShiftStarted();
}

final class ShiftRefreshed extends ShiftEvent {
  const ShiftRefreshed();
}
