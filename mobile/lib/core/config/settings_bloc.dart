import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../theme/theme_controller.dart';
import 'terminal_bloc.dart';
import 'terminal_config.dart';

part 'settings_event.dart';
part 'settings_state.dart';

/// Thin settings façade over [TerminalBloc] + [ThemeController].
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({
    required TerminalBloc terminalBloc,
    required ThemeController themeController,
  })  : _terminal = terminalBloc,
        _theme = themeController,
        super(SettingsState(
          role: terminalBloc.state.role,
          themeMode: themeController.mode,
          currencyCode: terminalBloc.state.config.currencyCode,
          locale: terminalBloc.state.config.locale,
        )) {
    _terminalSub = _terminal.stream.listen((_) => add(const SettingsSynced()));
    _theme.addListener(_onThemeChanged);
    on<SettingsSynced>(_onSynced);
    on<SettingsRoleChanged>(_onRoleChanged);
    on<SettingsThemeToggled>(_onThemeToggled);
  }

  final TerminalBloc _terminal;
  final ThemeController _theme;
  StreamSubscription<TerminalState>? _terminalSub;

  void _onThemeChanged() => add(const SettingsSynced());

  void _onSynced(
    SettingsSynced event,
    Emitter<SettingsState> emit,
  ) {
    emit(SettingsState(
      role: _terminal.state.role,
      themeMode: _theme.mode,
      currencyCode: _terminal.state.config.currencyCode,
      locale: _terminal.state.config.locale,
    ));
  }

  Future<void> _onRoleChanged(
    SettingsRoleChanged event,
    Emitter<SettingsState> emit,
  ) async {
    _terminal.add(TerminalRoleChanged(event.role));
  }

  Future<void> _onThemeToggled(
    SettingsThemeToggled event,
    Emitter<SettingsState> emit,
  ) async {
    await _theme.cycle();
  }

  @override
  Future<void> close() {
    _terminalSub?.cancel();
    _theme.removeListener(_onThemeChanged);
    return super.close();
  }
}
