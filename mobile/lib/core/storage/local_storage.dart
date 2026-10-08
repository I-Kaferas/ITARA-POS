import '../config/terminal_config_repository.dart';
import '../database/database_module.dart';

/// Facade over persistent local storage (SQLite + terminal config).
class LocalStorage {
  LocalStorage({
    LocalDatabase? database,
    TerminalConfigRepository? config,
  })  : _database = database ?? LocalDatabase.instance,
        _config = config ?? TerminalConfigRepository.instance;

  final LocalDatabase _database;
  final TerminalConfigRepository _config;

  static final LocalStorage instance = LocalStorage();

  LocalDatabase get database => _database;

  TerminalConfigRepository get config => _config;

  Future<String> sqlitePath() => _database.sqlitePath();

  Future<void> checkpoint() => _database.checkpoint();
}
