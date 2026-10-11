import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'terminal_config.dart';

class TerminalConfigRepository extends ChangeNotifier {
  TerminalConfigRepository._() {
    _loading = _load();
  }

  static final TerminalConfigRepository instance = TerminalConfigRepository._();

  static const _storageKey = 'terminal_config';

  TerminalConfig _config = const TerminalConfig();
  Future<void>? _loading;
  bool isLoaded = false;

  TerminalConfig get config => _config;

  bool get isConfigured => _config.isConfigured;

  Future<void> ensureLoaded() {
    return _loading ??= _load();
  }

  Future<void> save(TerminalConfig next) async {
    await ensureLoaded();
    var value = next;
    if (value.deviceIdentifier.trim().isEmpty) {
      value = value.copyWith(deviceIdentifier: const Uuid().v4());
    }
    _config = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(value.toJson()));
    notifyListeners();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _config = TerminalConfig(deviceIdentifier: const Uuid().v4());
      isLoaded = true;
      notifyListeners();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _config = TerminalConfig.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      _config = const TerminalConfig();
    }

    if (_config.deviceIdentifier.trim().isEmpty) {
      _config = _config.copyWith(deviceIdentifier: const Uuid().v4());
    }

    // The API listens on 127.0.0.1:8001. `localhost` often resolves to IPv6 on Windows and the connection fails.
    final migratedApi = _migrateLocalApi(_config.apiBaseUrl);
    final migratedInternal = _migrateLocalApi(_config.internalApiBaseUrl);
    if (migratedApi != _config.apiBaseUrl || migratedInternal != _config.internalApiBaseUrl) {
      _config = _config.copyWith(
        apiBaseUrl: migratedApi,
        internalApiBaseUrl: migratedInternal,
      );
      await prefs.setString(_storageKey, jsonEncode(_config.toJson()));
    }

    isLoaded = true;
    notifyListeners();
  }

  static String _migrateLocalApi(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return trimmed;
    final host = uri.host.toLowerCase();
    if (host != 'localhost' && host != '127.0.0.1') return trimmed;
    final port = uri.port == 8000 ? 8001 : uri.port;
    return uri.replace(host: '127.0.0.1', port: port).toString();
  }

  Future<void> clear() async {
    await ensureLoaded();
    _config = TerminalConfig(deviceIdentifier: const Uuid().v4());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    isLoaded = true;
    notifyListeners();
  }
}
