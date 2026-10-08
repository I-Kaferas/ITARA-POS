part of 'print_queue_bloc.dart';

sealed class PrintQueueEvent extends Equatable {
  const PrintQueueEvent();

  @override
  List<Object?> get props => const [];
}

final class PrintQueueStarted extends PrintQueueEvent {
  const PrintQueueStarted();
}

final class PrintQueueRefreshed extends PrintQueueEvent {
  const PrintQueueRefreshed();
}

final class PrintQueueProcessRequested extends PrintQueueEvent {
  const PrintQueueProcessRequested();
}
