import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'conflict_resolution_event.dart';
part 'conflict_resolution_state.dart';

class ConflictResolutionBloc extends Bloc<ConflictResolutionEvent, ConflictResolutionState> {
  ConflictResolutionBloc() : super(const ConflictResolutionState()) {
    on<ConflictResolutionStarted>(_onStarted);
    on<ConflictResolutionRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    ConflictResolutionStarted event,
    Emitter<ConflictResolutionState> emit,
  ) async {
    emit(state.copyWith(status: ConflictResolutionStatus.loading, clearError: true));
    emit(state.copyWith(status: ConflictResolutionStatus.ready));
  }

  Future<void> _onRefreshed(
    ConflictResolutionRefreshed event,
    Emitter<ConflictResolutionState> emit,
  ) async {
    add(const ConflictResolutionStarted());
  }
}
