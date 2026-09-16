import 'package:flutter/material.dart';

enum PosRole {
  master,
  slave,
  standalone;

  static PosRole fromString(String value) {
    return PosRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => PosRole.standalone,
    );
  }

  String get label => switch (this) {
        PosRole.master => 'Master',
        PosRole.slave => 'Esclave',
        PosRole.standalone => 'Autonome',
      };

  String get description => switch (this) {
        PosRole.master =>
          'Terminal principal — gère les shifts, synchronise les esclaves',
        PosRole.slave =>
          'Terminal secondaire — ventes relayées au master',
        PosRole.standalone =>
          'Terminal indépendant — fonctionne seul',
      };

  IconData get icon => switch (this) {
        PosRole.master => Icons.hub,
        PosRole.slave => Icons.devices_other,
        PosRole.standalone => Icons.point_of_sale,
      };
}

class TerminalConfig {
  const TerminalConfig({
    this.apiBaseUrl = 'http://localhost:8000/api/v1',
    this.internalApiBaseUrl = '',
    this.authToken = '',
    this.refreshToken = '',
    this.tokenExpiresAt = '',
    this.tenantId = '',
    this.tenantSlug = '',
    this.brandName = '',
    this.brandLogoUrl = '',
    this.brandPrimaryColor = '',
    this.brandAccentColor = '',
    this.storeId = '',
    this.deviceId = '',
    this.deviceIdentifier = '',
    this.deviceName = '',
    this.posRole = PosRole.standalone,
    this.masterDeviceId = '',
    this.masterHost = '',
    this.currencyCode = 'USD',
    this.locale = 'fr',
    this.timezone = 'Africa/Bujumbura',
    this.companyProfile = '',
    this.isConfigured = false,
    this.isSignedIn = false,
    this.cashierId = '',
    this.cashierName = '',
    this.cashRegisterId = '',
    this.cashSessionId = '',
    this.permissions = const [],
    this.roles = const [],
    this.pinVerifier = '',
    this.printerHost = '',
    this.printerPort = 9100,
    this.printerEnabled = false,
    this.printerModel = 'generic_80',
    this.printerConnection = 'system',
    this.printerName = '',
    this.printerFormat = 'thermal_80',
  });

  factory TerminalConfig.fromJson(Map<String, dynamic> json) {
    return TerminalConfig(
      apiBaseUrl: _string(json['api_base_url'], 'http://localhost:8000/api/v1'),
      internalApiBaseUrl: _string(json['internal_api_base_url']),
      authToken: _string(json['auth_token']),
      refreshToken: _string(json['refresh_token']),
      tokenExpiresAt: _string(json['token_expires_at']),
      tenantId: _string(json['tenant_id']),
      tenantSlug: _string(json['tenant_slug']),
      brandName: _string(json['brand_name']),
      brandLogoUrl: _string(json['brand_logo_url']),
      brandPrimaryColor: _string(json['brand_primary_color']),
      brandAccentColor: _string(json['brand_accent_color']),
      storeId: _string(json['store_id']),
      deviceId: _string(json['device_id']),
      deviceIdentifier: _string(json['device_identifier']),
      deviceName: _string(json['device_name']),
      posRole: PosRole.fromString(_string(json['pos_role'], 'standalone')),
      masterDeviceId: _string(json['master_device_id']),
      masterHost: _string(json['master_host']),
      currencyCode: _string(json['currency_code'], 'USD'),
      locale: _string(json['locale'], 'fr'),
      timezone: _string(json['timezone'], 'Africa/Bujumbura'),
      companyProfile: _string(json['company_profile']),
      isConfigured: _bool(json['is_configured']),
      isSignedIn: _bool(json['is_signed_in']),
      cashierId: _string(json['cashier_id']),
      cashierName: _string(json['cashier_name']),
      cashRegisterId: _string(json['cash_register_id']),
      cashSessionId: _string(json['cash_session_id']),
      permissions: (json['permissions'] as List?)?.map((item) => item.toString()).toList() ?? const [],
      roles: (json['roles'] as List?)?.map((item) => item.toString()).toList() ?? const [],
      pinVerifier: _string(json['pin_verifier']),
      printerHost: _string(json['printer_host']),
      printerPort: _int(json['printer_port'], 9100),
      printerEnabled: _bool(json['printer_enabled']),
      printerModel: _string(json['printer_model'], 'generic_80'),
      printerConnection: _string(json['printer_connection'], 'system'),
      printerName: _string(json['printer_name']),
      printerFormat: _string(json['printer_format'], 'thermal_80'),
    );
  }

  static String _string(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static int _int(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _bool(dynamic value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return fallback;
  }

  final String apiBaseUrl;
  final String internalApiBaseUrl;
  final String authToken;
  final String refreshToken;
  final String tokenExpiresAt;
  final String tenantId;
  final String tenantSlug;
  final String brandName;
  final String brandLogoUrl;
  final String brandPrimaryColor;
  final String brandAccentColor;
  final String storeId;
  final String deviceId;
  final String deviceIdentifier;
  final String deviceName;
  final PosRole posRole;
  final String masterDeviceId;
  final String masterHost;
  final String currencyCode;
  final String locale;
  final String timezone;
  final String companyProfile;
  final bool isConfigured;
  final bool isSignedIn;
  final String cashierId;
  final String cashierName;
  final String cashRegisterId;
  final String cashSessionId;
  final List<String> permissions;
  final List<String> roles;
  final String pinVerifier;

  bool get canWorkOffline => pinVerifier.isNotEmpty && permissions.isNotEmpty && authToken.isNotEmpty;
  final String printerHost;
  final int printerPort;
  final bool printerEnabled;
  final String printerModel;
  final String printerConnection;
  final String printerName;
  final String printerFormat;

  bool get isMaster => posRole == PosRole.master;
  bool get isSlave => posRole == PosRole.slave;
  bool get canManageShifts => !isSlave;
  bool get canManageOrders => !isSlave;

  Map<String, dynamic> toJson() => {
        'api_base_url': apiBaseUrl,
        'internal_api_base_url': internalApiBaseUrl,
        'auth_token': authToken,
        'refresh_token': refreshToken,
        'token_expires_at': tokenExpiresAt,
        'tenant_id': tenantId,
        'tenant_slug': tenantSlug,
        'brand_name': brandName,
        'brand_logo_url': brandLogoUrl,
        'brand_primary_color': brandPrimaryColor,
        'brand_accent_color': brandAccentColor,
        'store_id': storeId,
        'device_id': deviceId,
        'device_identifier': deviceIdentifier,
        'device_name': deviceName,
        'pos_role': posRole.name,
        'master_device_id': masterDeviceId,
        'master_host': masterHost,
        'currency_code': currencyCode,
        'locale': locale,
        'timezone': timezone,
        'company_profile': companyProfile,
        'is_configured': isConfigured,
        'is_signed_in': isSignedIn,
        'cashier_id': cashierId,
        'cashier_name': cashierName,
        'cash_register_id': cashRegisterId,
        'cash_session_id': cashSessionId,
        'permissions': permissions,
        'roles': roles,
        'pin_verifier': pinVerifier,
        'printer_host': printerHost,
        'printer_port': printerPort,
        'printer_enabled': printerEnabled,
        'printer_model': printerModel,
        'printer_connection': printerConnection,
        'printer_name': printerName,
        'printer_format': printerFormat,
      };

  TerminalConfig copyWith({
    String? apiBaseUrl,
    String? internalApiBaseUrl,
    String? authToken,
    String? refreshToken,
    String? tokenExpiresAt,
    String? tenantId,
    String? tenantSlug,
    String? brandName,
    String? brandLogoUrl,
    String? brandPrimaryColor,
    String? brandAccentColor,
    String? storeId,
    String? deviceId,
    String? deviceIdentifier,
    String? deviceName,
    PosRole? posRole,
    String? masterDeviceId,
    String? masterHost,
    String? currencyCode,
    String? locale,
    String? timezone,
    String? companyProfile,
    bool? isConfigured,
    bool? isSignedIn,
    String? cashierId,
    String? cashierName,
    String? cashRegisterId,
    String? cashSessionId,
    List<String>? permissions,
    List<String>? roles,
    String? pinVerifier,
    String? printerHost,
    int? printerPort,
    bool? printerEnabled,
    String? printerModel,
    String? printerConnection,
    String? printerName,
    String? printerFormat,
  }) {
    return TerminalConfig(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      internalApiBaseUrl: internalApiBaseUrl ?? this.internalApiBaseUrl,
      authToken: authToken ?? this.authToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      tenantId: tenantId ?? this.tenantId,
      tenantSlug: tenantSlug ?? this.tenantSlug,
      brandName: brandName ?? this.brandName,
      brandLogoUrl: brandLogoUrl ?? this.brandLogoUrl,
      brandPrimaryColor: brandPrimaryColor ?? this.brandPrimaryColor,
      brandAccentColor: brandAccentColor ?? this.brandAccentColor,
      storeId: storeId ?? this.storeId,
      deviceId: deviceId ?? this.deviceId,
      deviceIdentifier: deviceIdentifier ?? this.deviceIdentifier,
      deviceName: deviceName ?? this.deviceName,
      posRole: posRole ?? this.posRole,
      masterDeviceId: masterDeviceId ?? this.masterDeviceId,
      masterHost: masterHost ?? this.masterHost,
      currencyCode: currencyCode ?? this.currencyCode,
      locale: locale ?? this.locale,
      timezone: timezone ?? this.timezone,
      companyProfile: companyProfile ?? this.companyProfile,
      isConfigured: isConfigured ?? this.isConfigured,
      isSignedIn: isSignedIn ?? this.isSignedIn,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      cashRegisterId: cashRegisterId ?? this.cashRegisterId,
      cashSessionId: cashSessionId ?? this.cashSessionId,
      permissions: permissions ?? this.permissions,
      roles: roles ?? this.roles,
      pinVerifier: pinVerifier ?? this.pinVerifier,
      printerHost: printerHost ?? this.printerHost,
      printerPort: printerPort ?? this.printerPort,
      printerEnabled: printerEnabled ?? this.printerEnabled,
      printerModel: printerModel ?? this.printerModel,
      printerConnection: printerConnection ?? this.printerConnection,
      printerName: printerName ?? this.printerName,
      printerFormat: printerFormat ?? this.printerFormat,
    );
  }
}
