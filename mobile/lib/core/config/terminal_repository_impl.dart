import 'terminal_config.dart';
import 'terminal_config_repository.dart';
import 'terminal_repository.dart';

/// Adapter over the existing ChangeNotifier-backed config store.
class TerminalRepositoryImpl implements TerminalRepository {
  TerminalRepositoryImpl(this._delegate);

  final TerminalConfigRepository _delegate;

  /// Exposed for go_router [refreshListenable].
  TerminalConfigRepository get listenable => _delegate;

  @override
  TerminalConfig get config => _delegate.config;

  @override
  bool get isLoaded => _delegate.isLoaded;

  @override
  bool get isConfigured => _delegate.isConfigured;

  @override
  Future<void> ensureLoaded() => _delegate.ensureLoaded();

  @override
  Future<void> save(TerminalConfig next) => _delegate.save(next);
}
