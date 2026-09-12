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
    this.isConfigured = false,
    this.isSignedIn = false,
    this.cashierId = '',
    this.cashierName = '',
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
      apiBaseUrl: json['api_base_url'] as String? ?? 'http://localhost:8000/api/v1',
      internalApiBaseUrl: json['internal_api_base_url'] as String? ?? '',
      authToken: json['auth_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      tokenExpiresAt: json['token_expires_at'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      tenantSlug: json['tenant_slug'] as String? ?? '',
      brandName: json['brand_name'] as String? ?? '',
      brandLogoUrl: json['brand_logo_url'] as String? ?? '',
      brandPrimaryColor: json['brand_primary_color'] as String? ?? '',
      brandAccentColor: json['brand_accent_color'] as String? ?? '',
      storeId: json['store_id'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? '',
      deviceIdentifier: json['device_identifier'] as String? ?? '',
      deviceName: json['device_name'] as String? ?? '',
      posRole: PosRole.fromString(json['pos_role'] as String? ?? 'standalone'),
      masterDeviceId: json['master_device_id'] as String? ?? '',
      masterHost: json['master_host'] as String? ?? '',
      currencyCode: json['currency_code'] as String? ?? 'USD',
      isConfigured: json['is_configured'] as bool? ?? false,
      isSignedIn: json['is_signed_in'] as bool? ?? false,
      cashierId: json['cashier_id'] as String? ?? '',
      cashierName: json['cashier_name'] as String? ?? '',
      printerHost: json['printer_host'] as String? ?? '',
      printerPort: json['printer_port'] as int? ?? 9100,
      printerEnabled: json['printer_enabled'] as bool? ?? false,
      printerModel: json['printer_model'] as String? ?? 'generic_80',
      printerConnection: json['printer_connection'] as String? ?? 'system',
      printerName: json['printer_name'] as String? ?? '',
      printerFormat: json['printer_format'] as String? ?? 'thermal_80',
    );
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
  final bool isConfigured;
  final bool isSignedIn;
  final String cashierId;
  final String cashierName;
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
        'is_configured': isConfigured,
        'is_signed_in': isSignedIn,
        'cashier_id': cashierId,
        'cashier_name': cashierName,
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
    bool? isConfigured,
    bool? isSignedIn,
    String? cashierId,
    String? cashierName,
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
      isConfigured: isConfigured ?? this.isConfigured,
      isSignedIn: isSignedIn ?? this.isSignedIn,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
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
