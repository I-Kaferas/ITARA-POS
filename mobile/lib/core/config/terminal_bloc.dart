import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../logging/app_logger.dart';
import 'terminal_config.dart';
import 'terminal_config_repository.dart';
import 'terminal_repository.dart';

part 'terminal_event.dart';
part 'terminal_state.dart';

class TerminalBloc extends Bloc<TerminalEvent, TerminalState> {
  TerminalBloc({
    required TerminalRepository repository,
    required TerminalConfigRepository configRepository,
    required AppLogger logger,
  })  : _repository = repository,
        _configRepository = configRepository,
        _log = logger.tagged('terminal'),
        super(TerminalState.fromRepo(repository)) {
    _configRepository.addListener(_onConfigChanged);
    on<TerminalLoadRequested>(_onLoad);
    on<TerminalSaveRequested>(_onSave);
    on<TerminalRoleChanged>(_onRoleChanged);
    on<TerminalSynced>(_onSynced);
  }

  final TerminalRepository _repository;
  final TerminalConfigRepository _configRepository;
  final AppLogger _log;

  void _onConfigChanged() => add(const TerminalSynced());

  Future<void> _onLoad(
    TerminalLoadRequested event,
    Emitter<TerminalState> emit,
  ) async {
    await _repository.ensureLoaded();
    emit(TerminalState.fromRepo(_repository));
    _log.debug('loaded configured=${_repository.isConfigured}');
  }

  Future<void> _onSave(
    TerminalSaveRequested event,
    Emitter<TerminalState> emit,
  ) async {
    await _repository.save(event.config);
    emit(TerminalState.fromRepo(_repository));
    _log.info('config saved role=${event.config.posRole.name}');
  }

  Future<void> _onRoleChanged(
    TerminalRoleChanged event,
    Emitter<TerminalState> emit,
  ) async {
    await _repository.save(_repository.config.copyWith(posRole: event.role));
    emit(TerminalState.fromRepo(_repository));
  }

  void _onSynced(
    TerminalSynced event,
    Emitter<TerminalState> emit,
  ) {
    emit(TerminalState.fromRepo(_repository));
  }

  @override
  Future<void> close() {
    _configRepository.removeListener(_onConfigChanged);
    return super.close();
  }
}
