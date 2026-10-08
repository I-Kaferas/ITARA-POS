part of 'settings_bloc.dart';

final class SettingsState extends Equatable {
  const SettingsState({
    required this.role,
    required this.themeMode,
    required this.currencyCode,
    required this.locale,
  });

  final PosRole role;
  final ThemeMode themeMode;
  final String currencyCode;
  final String locale;

  @override
  List<Object?> get props => [role, themeMode, currencyCode, locale];
}
