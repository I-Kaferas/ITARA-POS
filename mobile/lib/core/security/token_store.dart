import '../config/terminal_config_repository.dart';

/// Access to auth / pair tokens without UI coupling.
class TokenStore {
  TokenStore({TerminalConfigRepository? config})
      : _config = config ?? TerminalConfigRepository.instance;

  final TerminalConfigRepository _config;

  static final TokenStore instance = TokenStore();

  String get authToken => _config.config.authToken;

  String get refreshToken => _config.config.refreshToken;

  String get masterPairToken => _config.config.masterPairToken;

  bool get hasAuthToken => authToken.isNotEmpty;

  bool get hasPairToken => masterPairToken.isNotEmpty;
}
