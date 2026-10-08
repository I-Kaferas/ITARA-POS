import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'theme_controller.dart';

class ThemeState extends Equatable {
  const ThemeState(this.mode);

  final ThemeMode mode;

  bool get isDark {
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  bool get isSystem => mode == ThemeMode.system;

  @override
  List<Object?> get props => [mode];
}

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit(this._controller) : super(ThemeState(_controller.mode)) {
    _controller.addListener(_sync);
  }

  final ThemeController _controller;

  Future<void> load() async {
    await _controller.load();
    emit(ThemeState(_controller.mode));
  }

  Future<void> setMode(ThemeMode mode) async {
    await _controller.setMode(mode);
    emit(ThemeState(_controller.mode));
  }

  Future<void> cycle() async {
    await _controller.cycle();
    emit(ThemeState(_controller.mode));
  }

  Future<void> toggle() async {
    await _controller.toggle();
    emit(ThemeState(_controller.mode));
  }

  void applyFromConfig() {
    _controller.applyFromConfig();
    emit(ThemeState(_controller.mode));
  }

  void _sync() => emit(ThemeState(_controller.mode));

  @override
  Future<void> close() {
    _controller.removeListener(_sync);
    return super.close();
  }
}
