import 'terminal_config.dart';

abstract class TerminalRepository {
  TerminalConfig get config;

  bool get isLoaded;

  bool get isConfigured;

  Future<void> ensureLoaded();

  Future<void> save(TerminalConfig next);
}
