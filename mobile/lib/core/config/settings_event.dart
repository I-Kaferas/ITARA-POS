part of 'settings_bloc.dart';

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => const [];
}

final class SettingsSynced extends SettingsEvent {
  const SettingsSynced();
}

final class SettingsRoleChanged extends SettingsEvent {
  const SettingsRoleChanged(this.role);

  final PosRole role;

  @override
  List<Object?> get props => [role];
}

final class SettingsThemeToggled extends SettingsEvent {
  const SettingsThemeToggled();
}
