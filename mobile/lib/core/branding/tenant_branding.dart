import 'package:flutter/material.dart';

class TenantBranding {
  const TenantBranding({
    required this.tenantId,
    required this.slug,
    required this.brandName,
    required this.tagline,
    this.logoUrl,
    required this.primaryColor,
    required this.accentColor,
  });

  factory TenantBranding.fromJson(Map<String, dynamic> json) {
    return TenantBranding(
      tenantId: json['tenant_id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      brandName: json['brand_name'] as String? ?? 'POS',
      tagline: json['tagline'] as String? ?? '',
      logoUrl: json['logo_url'] as String?,
      primaryColor: json['primary_color'] as String? ?? '#3D5C73',
      accentColor: json['accent_color'] as String? ?? '#E39B2B',
    );
  }

  final String tenantId;
  final String slug;
  final String brandName;
  final String tagline;
  final String? logoUrl;
  final String primaryColor;
  final String accentColor;

  Color get primary => parseHex(primaryColor) ?? const Color(0xFF3D5C73);
  Color get accent => parseHex(accentColor) ?? const Color(0xFFE39B2B);

  static Color? parseHex(String? value) {
    if (value == null) return null;
    var hex = value.trim();
    if (hex.isEmpty) return null;
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length != 6) return null;
    final intValue = int.tryParse(hex, radix: 16);
    if (intValue == null) return null;
    return Color(0xFF000000 | intValue);
  }
}
