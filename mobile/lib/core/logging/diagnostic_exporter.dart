import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/terminal_config.dart';
import '../config/terminal_config_repository.dart';
import '../../data/local/local_database.dart';
import 'log_store.dart';
import 'log_type.dart';

/// Builds an exportable diagnostic package for ITARA support (§57).
class DiagnosticExporter {
  DiagnosticExporter({
    required LogStore logStore,
    TerminalConfigRepository? configRepository,
    LocalDatabase? database,
  })  : _logs = logStore,
        _config = configRepository ?? TerminalConfigRepository.instance,
        _database = database ?? LocalDatabase.instance;

  final LogStore _logs;
  final TerminalConfigRepository _config;
  final LocalDatabase _database;

  /// Creates a ZIP under the app support `diagnostics/` folder.
  ///
  /// Returns the absolute path of the generated archive.
  Future<DiagnosticExportResult> export({
    int logLimit = 2000,
    bool includeSyncOutbox = true,
  }) async {
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final root = await _diagnosticsRoot();
    final workDir = Directory(p.join(root.path, 'itara-diagnostic-$stamp'));
    await workDir.create(recursive: true);

    try {
      final config = _config.config;
      final entries = await _logs.recent(limit: logLimit);
      final counts = await _logs.countsByType();

      final manifest = {
        'format': 'itara-pos-diagnostic',
        'version': 1,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'platform': _platform(),
        'app': 'pos_mobile',
        'purpose': 'ITARA support diagnostic export',
        'log_count': entries.length,
        'log_counts_by_type': counts,
        'channels': [for (final t in LogType.values) t.label],
      };

      await File(p.join(workDir.path, 'manifest.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
      );

      await File(p.join(workDir.path, 'terminal.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(_sanitizeConfig(config)),
      );

      await File(p.join(workDir.path, 'device.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'platform': _platform(),
          'operating_system': Platform.operatingSystem,
          'operating_system_version': Platform.operatingSystemVersion,
          'locale': Platform.localeName,
          'number_of_processors': Platform.numberOfProcessors,
          'local_hostname': _safeHostname(),
        }),
      );

      await File(p.join(workDir.path, 'logs.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(
          entries.reversed.map((e) => e.toJson()).toList(),
        ),
      );

      final lines = entries.reversed.map((e) => e.toLine()).join('\n');
      await File(p.join(workDir.path, 'logs.txt')).writeAsString('$lines\n');

      if (includeSyncOutbox) {
        await _writeSyncSnapshot(workDir);
      }

      final zipPath = p.join(root.path, 'itara-diagnostic-$stamp.zip');
      await _zipDirectory(workDir, zipPath);
      await _prune(root);

      return DiagnosticExportResult(
        zipPath: zipPath,
        directoryPath: workDir.path,
        logCount: entries.length,
        createdAt: DateTime.now().toUtc(),
      );
    } catch (_) {
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  Map<String, dynamic> _sanitizeConfig(TerminalConfig config) {
    final json = config.toJson();
    const redact = {
      'auth_token',
      'refresh_token',
      'pin_verifier',
      'master_pair_token',
      'token',
      'password',
      'secret',
    };
    for (final key in redact) {
      final value = json[key];
      if (value is String && value.isNotEmpty) {
        json[key] = '***REDACTED***';
      }
    }
    return json;
  }

  Future<void> _writeSyncSnapshot(Directory workDir) async {
    try {
      final db = await _database.database;
      final outbox = await db.query(
        'sync_outbox',
        orderBy: 'created_at DESC',
        limit: 100,
      );
      final failed = await db.query(
        'sync_outbox',
        where: "status IN ('FAILED', 'CONFLICT', 'failed', 'conflict')",
        limit: 50,
      );
      final conflicts = await db.query(
        'sync_conflicts',
        orderBy: 'created_at DESC',
        limit: 50,
      );

      await File(p.join(workDir.path, 'sync_outbox.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(outbox),
      );
      await File(p.join(workDir.path, 'sync_failures.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(failed),
      );
      await File(p.join(workDir.path, 'sync_conflicts.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(conflicts),
      );
    } catch (error) {
      await File(p.join(workDir.path, 'sync_snapshot_error.txt'))
          .writeAsString(error.toString());
    }
  }

  Future<Directory> _diagnosticsRoot() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'diagnostics'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _zipDirectory(Directory source, String zipPath) async {
    final archive = Archive();
    await for (final entity in source.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: source.path);
      final bytes = await entity.readAsBytes();
      archive.addFile(ArchiveFile(relative.replaceAll('\\', '/'), bytes.length, bytes));
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('Failed to encode diagnostic ZIP.');
    }
    await File(zipPath).writeAsBytes(encoded, flush: true);
  }

  Future<void> _prune(Directory root, {int keep = 10}) async {
    final zips = root
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final file in zips.skip(keep)) {
      try {
        await file.delete();
      } catch (_) {}
    }
    final dirs = root
        .listSync()
        .whereType<Directory>()
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final dir in dirs.skip(keep)) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  String _platform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return Platform.operatingSystem;
  }

  String _safeHostname() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'unknown';
    }
  }
}

class DiagnosticExportResult {
  const DiagnosticExportResult({
    required this.zipPath,
    required this.directoryPath,
    required this.logCount,
    required this.createdAt,
  });

  final String zipPath;
  final String directoryPath;
  final int logCount;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'zip_path': zipPath,
        'directory_path': directoryPath,
        'log_count': logCount,
        'created_at': createdAt.toIso8601String(),
      };
}
