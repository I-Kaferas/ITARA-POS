part of 'refund_bloc.dart';

sealed class RefundEvent extends Equatable {
  const RefundEvent();

  @override
  List<Object?> get props => const [];
}

final class RefundStarted extends RefundEvent {
  const RefundStarted();
}

final class RefundRefreshed extends RefundEvent {
  const RefundRefreshed();
}
