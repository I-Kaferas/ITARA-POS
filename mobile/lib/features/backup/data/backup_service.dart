import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/terminal_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../data/local/local_database.dart';

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  Future<Map<String, dynamic>> create({bool upload = true}) async {
    final db = await LocalDatabase.instance.database;
    final events = await db.query('sync_events', orderBy: 'sequence ASC');
    final failed = await db.query('sync_queue', where: "status IN ('failed', 'retrying', 'conflict')", limit: 40);
    final sales = _count(await db.rawQuery('SELECT COUNT(*) AS c FROM sales'));
    await LocalDatabase.instance.checkpoint();

    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final root = await _root();
    final dir = Directory(p.join(root.path, stamp));
    await dir.create(recursive: true);
    await LocalDatabase.instance.close();
    try {
      final sqlite = File(await LocalDatabase.instance.sqlitePath());
      final databaseFile = File(p.join(dir.path, 'database', 'pos_offline.sqlite'));
      await databaseFile.parent.create(recursive: true);
      if (await sqlite.exists()) await sqlite.copy(databaseFile.path);

      final config = TerminalConfigRepository.instance.config;
      await File(p.join(dir.path, 'configuration.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(config.toJson()),
      );
      await File(p.join(dir.path, 'sync_events.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(events),
      );

      final filesDir = Directory(p.join(dir.path, 'files'));
      await filesDir.create();
      final support = await getApplicationSupportDirectory();
      var fileCount = 0;
      await for (final entity in support.list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (entity is! File || name.startsWith('pos_offline.sqlite') || name == 'backups') continue;
        await entity.copy(p.join(filesDir.path, name));
        fileCount++;
      }

      final logsDir = Directory(p.join(dir.path, 'logs'));
      await logsDir.create();
      final log = StringBuffer()
        ..writeln('${DateTime.now().toIso8601String()} backup $stamp')
        ..writeln('platform ${_platform()}')
        ..writeln('sales $sales')
        ..writeln('sync_events ${events.length}')
        ..writeln('files $fileCount');
      await File(p.join(logsDir.path, 'backup.log')).writeAsString(log.toString());
      await File(p.join(logsDir.path, 'sync_failures.json')).writeAsString(jsonEncode(failed));

      final manifest = {
        'id': stamp,
        'created_at': DateTime.now().toIso8601String(),
        'platform': _platform(),
        'includes': ['cloud', 'database', 'files', 'logs', 'backups', 'sqlite', 'sync_events', 'configuration'],
        'sales': sales,
        'sync_events': events.length,
        'files': fileCount,
        'cloud': false,
      };
      await File(p.join(dir.path, 'manifest.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
      );
      await _prune(root);

      var cloud = false;
      String? cloudError;
      if (upload) {
        try {
          cloud = await _upload(dir, config);
          manifest['cloud'] = cloud;
          await File(p.join(dir.path, 'manifest.json')).writeAsString(
            const JsonEncoder.withIndent('  ').convert(manifest),
          );
        } catch (error) {
          cloudError = error.toString().replaceFirst('Exception: ', '');
        }
      }
      return {'id': stamp, 'cloud': cloud, 'cloud_error': cloudError, 'sync_events': events.length};
    } finally {
      await LocalDatabase.instance.database;
    }
  }

  Future<List<Map<String, dynamic>>> localBackups() async {
    final root = await _root();
    if (!await root.exists()) return [];
    final dirs = await root.list().where((entity) => entity is Directory).cast<Directory>().toList();
    dirs.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    final rows = <Map<String, dynamic>>[];
    for (final dir in dirs.take(12)) {
      final manifest = File(p.join(dir.path, 'manifest.json'));
      if (!await manifest.exists()) continue;
      final decoded = jsonDecode(await manifest.readAsString());
      if (decoded is Map<String, dynamic>) rows.add(decoded);
    }
    return rows;
  }

  Future<void> restoreLocal(String id) async {
    final dir = Directory(p.join((await _root()).path, id));
    if (!await dir.exists()) throw Exception('Sauvegarde introuvable');
    await _restoreFrom(dir);
  }

  Future<List<Map<String, dynamic>>> cloudBackups() async {
    final config = TerminalConfigRepository.instance.config;
    if (config.authToken.isEmpty || config.apiBaseUrl.isEmpty) return [];
    final response = await http
        .get(Uri.parse('${config.apiBaseUrl}/terminal-backups'), headers: _headers(config))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Cloud injoignable (${response.statusCode})');
    }
    final body = jsonDecode(response.body);
    final data = body is Map<String, dynamic> ? body['data'] : null;
    if (data is! List) return [];
    return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<void> restoreCloud(String id) async {
    final config = TerminalConfigRepository.instance.config;
    final dir = Directory(p.join((await _root()).path, 'cloud-$id'));
    await dir.create(recursive: true);
    await Directory(p.join(dir.path, 'database')).create();
    await _download(config, id, 'database', File(p.join(dir.path, 'database', 'pos_offline.sqlite')));
    await _download(config, id, 'configuration', File(p.join(dir.path, 'configuration.json')));
    try {
      await _download(config, id, 'sync-events', File(p.join(dir.path, 'sync_events.json')));
    } catch (_) {}
    await _restoreFrom(dir, keepToken: true);
  }

  Future<void> _restoreFrom(Directory dir, {bool keepToken = false}) async {
    final sqlite = File(p.join(dir.path, 'database', 'pos_offline.sqlite'));
    if (!await sqlite.exists()) throw Exception('Base SQLite absente de la sauvegarde');
    await LocalDatabase.instance.checkpoint();
    await LocalDatabase.instance.close();
    try {
      final live = File(await LocalDatabase.instance.sqlitePath());
      final safety = Directory(p.join((await _root()).path, 'pre-restore'));
      if (await safety.exists()) await safety.delete(recursive: true);
      await safety.create(recursive: true);
      if (await live.exists()) {
        await Directory(p.join(safety.path, 'database')).create();
        await live.copy(p.join(safety.path, 'database', 'pos_offline.sqlite'));
      }
      await File(p.join(safety.path, 'configuration.json')).writeAsString(
        jsonEncode(TerminalConfigRepository.instance.config.toJson()),
      );
      await _deleteSidecars(live.path);
      await live.parent.create(recursive: true);
      await sqlite.copy(live.path);

      final configFile = File(p.join(dir.path, 'configuration.json'));
      if (await configFile.exists()) {
        final decoded = jsonDecode(await configFile.readAsString());
        if (decoded is Map) {
          var next = TerminalConfig.fromJson(Map<String, dynamic>.from(decoded));
          if (keepToken) {
            next = next.copyWith(authToken: TerminalConfigRepository.instance.config.authToken);
          }
          await TerminalConfigRepository.instance.save(next);
        }
      }
    } finally {
      await LocalDatabase.instance.database;
    }
  }

  Future<bool> _upload(Directory dir, TerminalConfig config) async {
    if (config.authToken.isEmpty || config.apiBaseUrl.isEmpty) return false;
    final request = http.MultipartRequest('POST', Uri.parse('${config.apiBaseUrl}/terminal-backups'));
    request.headers.addAll(_headers(config)..remove('Content-Type'));
    Future<void> add(String field, String name) async {
      final file = File(p.join(dir.path, name));
      if (await file.exists()) {
        request.files.add(await http.MultipartFile.fromPath(field, file.path));
      }
    }

    await add('manifest', 'manifest.json');
    await add('database', p.join('database', 'pos_offline.sqlite'));
    final publicConfig = Map<String, dynamic>.from(config.toJson())..remove('auth_token');
    request.files.add(http.MultipartFile.fromString('configuration', jsonEncode(publicConfig), filename: 'configuration.json'));
    await add('sync_events', 'sync_events.json');
    await add('logs', p.join('logs', 'backup.log'));
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    if (streamed.statusCode != 201 && streamed.statusCode != 200) {
      throw Exception('Envoi cloud refusé (${streamed.statusCode})');
    }
    return true;
  }

  Future<void> _download(TerminalConfig config, String id, String name, File target) async {
    final response = await http
        .get(Uri.parse('${config.apiBaseUrl}/terminal-backups/$id/file/$name'), headers: _headers(config))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) throw Exception('Fichier cloud $name introuvable');
    await target.parent.create(recursive: true);
    await target.writeAsBytes(response.bodyBytes);
  }

  Map<String, String> _headers(TerminalConfig config) {
    return ApiClient(authToken: config.authToken, tenantId: config.tenantId, storeId: config.storeId, deviceId: config.deviceId).headers;
  }

  Future<Directory> _root() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _prune(Directory root) async {
    final dirs = await root.list().where((entity) => entity is Directory).cast<Directory>().toList();
    dirs.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    for (final dir in dirs.skip(8)) {
      if (p.basename(dir.path) == 'pre-restore') continue;
      await dir.delete(recursive: true);
    }
  }

  Future<void> _deleteSidecars(String sqlitePath) async {
    for (final suffix in ['-wal', '-shm']) {
      final file = File('$sqlitePath$suffix');
      if (await file.exists()) await file.delete();
    }
  }

  String _platform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    return Platform.operatingSystem;
  }
}

int _count(List<Map<String, Object?>> rows) {
  final value = rows.isEmpty ? 0 : rows.first['c'];
  return value is num ? value.toInt() : 0;
}
