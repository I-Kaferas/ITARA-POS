import 'dart:convert';

import '../core/config/terminal_config.dart';
import '../core/config/terminal_config_repository.dart';
import 'offline_store.dart';

/// Shared Master → Slave configuration document (printers, POS, routes…).
class MasterConfigStore {
  MasterConfigStore._();

  static final MasterConfigStore instance = MasterConfigStore._();

  static const _checkpointKey = 'master_shared_config';

  Future<Map<String, dynamic>> document() async {
    final raw = await OfflineStore.instance.checkpoint(_checkpointKey);
    if (raw == null || raw.trim().isEmpty) {
      return buildFromTerminal(TerminalConfigRepository.instance.config);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return buildFromTerminal(TerminalConfigRepository.instance.config);
  }

  Future<Map<String, dynamic>> save(Map<String, dynamic> patch) async {
    final current = await document();
    final next = <String, dynamic>{
      ...current,
      ...patch,
      'updated_at': DateTime.now().toIso8601String(),
      'version': ((current['version'] as num?)?.toInt() ?? 0) + 1,
    };
    if (patch['printers'] is List) next['printers'] = patch['printers'];
    if (patch['printer_routes'] is List) {
      next['printer_routes'] = patch['printer_routes'];
    }
    if (patch['pos_settings'] is Map) {
      next['pos_settings'] = Map<String, dynamic>.from(patch['pos_settings'] as Map);
    }
    if (patch['restaurant_settings'] is Map) {
      next['restaurant_settings'] =
          Map<String, dynamic>.from(patch['restaurant_settings'] as Map);
    }
    await OfflineStore.instance.setCheckpoint(_checkpointKey, jsonEncode(next));
    return next;
  }

  Future<Map<String, dynamic>> publishFromLocalTerminal() async {
    final doc = buildFromTerminal(TerminalConfigRepository.instance.config);
    return save(doc);
  }

  Map<String, dynamic> buildFromTerminal(TerminalConfig config) {
    return {
      'version': 1,
      'updated_at': DateTime.now().toIso8601String(),
      'tenant_id': config.tenantId,
      'store_id': config.storeId,
      'currency_code': config.currencyCode,
      'locale': config.locale,
      'timezone': config.timezone,
      'brand': {
        'name': config.brandName,
        'logo_url': config.brandLogoUrl,
        'primary_color': config.brandPrimaryColor,
        'accent_color': config.brandAccentColor,
      },
      'pos_settings': {
        'company_profile': config.companyProfile,
      },
      'restaurant_settings': const <String, dynamic>{},
      'printers': [
        if (config.printerEnabled ||
            config.printerHost.isNotEmpty ||
            config.printerName.isNotEmpty)
          {
            'id': 'default-cashier',
            'name': config.printerName.isEmpty ? 'Caisse' : config.printerName,
            'group': 'cashier',
            'host': config.printerHost,
            'port': config.printerPort,
            'model': config.printerModel,
            'connection': config.printerConnection,
            'format': config.printerFormat,
            'enabled': config.printerEnabled,
          },
      ],
      'printer_routes': [
        {'category': 'receipt', 'group': 'cashier'},
        {'category': 'kitchen', 'group': 'kitchen'},
        {'category': 'bar', 'group': 'bar'},
      ],
    };
  }

  /// Apply a Master config payload onto the local terminal prefs (Slave).
  Future<void> applyToTerminal(Map<String, dynamic> doc) async {
    final repo = TerminalConfigRepository.instance;
    final config = repo.config;
    final brand = doc['brand'] is Map
        ? Map<String, dynamic>.from(doc['brand'] as Map)
        : const <String, dynamic>{};
    final pos = doc['pos_settings'] is Map
        ? Map<String, dynamic>.from(doc['pos_settings'] as Map)
        : const <String, dynamic>{};

    String? printerHost;
    int? printerPort;
    bool? printerEnabled;
    String? printerModel;
    String? printerConnection;
    String? printerName;
    String? printerFormat;

    final printers = doc['printers'];
    if (printers is List && printers.isNotEmpty) {
      final preferred = printers.cast<dynamic>().whereType<Map>().map(Map<String, dynamic>.from).firstWhere(
            (item) => (item['group']?.toString() ?? '') == 'cashier',
            orElse: () => Map<String, dynamic>.from(printers.first as Map),
          );
      printerHost = preferred['host']?.toString();
      printerPort = (preferred['port'] as num?)?.toInt();
      printerEnabled = preferred['enabled'] == true || preferred['enabled'] == 1;
      printerModel = preferred['model']?.toString();
      printerConnection = preferred['connection']?.toString();
      printerName = preferred['name']?.toString();
      printerFormat = preferred['format']?.toString();
    }

    await repo.save(config.copyWith(
      tenantId: (doc['tenant_id']?.toString().isNotEmpty ?? false)
          ? doc['tenant_id'].toString()
          : null,
      storeId: (doc['store_id']?.toString().isNotEmpty ?? false)
          ? doc['store_id'].toString()
          : null,
      currencyCode: (doc['currency_code']?.toString().isNotEmpty ?? false)
          ? doc['currency_code'].toString()
          : null,
      locale: (doc['locale']?.toString().isNotEmpty ?? false)
          ? doc['locale'].toString()
          : null,
      timezone: (doc['timezone']?.toString().isNotEmpty ?? false)
          ? doc['timezone'].toString()
          : null,
      brandName: brand['name']?.toString(),
      brandLogoUrl: brand['logo_url']?.toString(),
      brandPrimaryColor: brand['primary_color']?.toString(),
      brandAccentColor: brand['accent_color']?.toString(),
      companyProfile: pos['company_profile']?.toString(),
      printerHost: printerHost,
      printerPort: printerPort,
      printerEnabled: printerEnabled,
      printerModel: printerModel,
      printerConnection: printerConnection,
      printerName: printerName,
      printerFormat: printerFormat,
    ));

    await OfflineStore.instance.setCheckpoint(_checkpointKey, jsonEncode(doc));
  }
}
