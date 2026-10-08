part of 'conflict_resolution_bloc.dart';

sealed class ConflictResolutionEvent extends Equatable {
  const ConflictResolutionEvent();

  @override
  List<Object?> get props => const [];
}

final class ConflictResolutionStarted extends ConflictResolutionEvent {
  const ConflictResolutionStarted();
}

final class ConflictResolutionRefreshed extends ConflictResolutionEvent {
  const ConflictResolutionRefreshed();
}
