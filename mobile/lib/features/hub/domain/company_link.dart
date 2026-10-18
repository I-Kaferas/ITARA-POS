import '../../../core/config/terminal_config.dart';

/// Join key from the SaaS dashboard and the company fields it fills.
abstract final class CompanyLink {
  /// `ITN-XXXX-XXXX-XXXX`, or `XXXX-XXXX-XXXX` when the prefix is absent.
  static String formatJoinKey(String raw) {
    var compact = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.isEmpty) return '';
    if (compact.startsWith('ITN')) {
      var body = compact.substring(3);
      if (body.length > 12) body = body.substring(0, 12);
      return body.isEmpty ? 'ITN' : 'ITN-${_chunks(body, 4)}';
    }
    if (compact.length > 12) compact = compact.substring(0, 12);
    return _chunks(compact, 4);
  }

  static bool isComplete(String formatted) {
    final compact = formatted.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.startsWith('ITN')) return compact.length == 15;
    return compact.length == 12;
  }

  /// Writes the device link and the company profile returned with the key.
  static TerminalConfig applyPair({
    required TerminalConfig current,
    required String joinKey,
    required Map<String, dynamic> data,
  }) {
    final company = _asMap(data['company']);
    final store = _asMap(data['store']);

    String keep(String incoming, String fallback) => incoming.isEmpty ? fallback : incoming;

    final currency = _field(company, 'currency_code').toUpperCase();
    final profile = profileText(company);
    final deviceId = keep(_field(data, 'id'), keep(_field(data, 'device_id'), current.deviceId));
    final serverName = _field(data, 'name');
    final roleRaw = _field(data, 'pos_role');

    return current.copyWith(
      deviceSyncToken: formatJoinKey(joinKey),
      tenantId: keep(_field(data, 'tenant_id'), keep(_field(company, 'tenant_id'), current.tenantId)),
      tenantSlug: keep(_field(company, 'tenant_slug'), current.tenantSlug),
      storeId: keep(
        _field(data, 'store_id'),
        keep(_field(store, 'id'), keep(_field(company, 'store_id'), current.storeId)),
      ),
      brandName: keep(_field(company, 'name'), keep(_field(company, 'tenant_name'), current.brandName)),
      brandLogoUrl: keep(_field(company, 'logo_url'), current.brandLogoUrl),
      currencyCode: keep(currency, current.currencyCode),
      locale: keep(_field(company, 'locale'), current.locale),
      timezone: keep(_field(company, 'timezone'), current.timezone),
      companyProfile: keep(profile, current.companyProfile),
      deviceId: deviceId,
      deviceName: current.deviceName.trim().isEmpty ? keep(serverName, current.deviceName) : current.deviceName,
      posRole: roleRaw.isEmpty ? current.posRole : PosRole.fromString(roleRaw),
      isConfigured: true,
    );
  }

  static String profileText(Map<String, dynamic> company) {
    final address = _asMap(company['address']);
    final city = [
      _field(address, 'city'),
      _field(address, 'commune'),
      _field(address, 'country'),
    ].where((part) => part.isNotEmpty).join(', ');
    final tax = _field(company, 'tax_id');
    return [
      _field(company, 'legal_name'),
      if (tax.isNotEmpty) 'NIF $tax',
      _field(company, 'phone'),
      _field(company, 'email'),
      city,
      _field(company, 'branch_name'),
      _field(company, 'store_name'),
    ].where((part) => part.isNotEmpty).join(' · ');
  }

  static String _chunks(String value, int size) {
    final parts = <String>[];
    for (var i = 0; i < value.length; i += size) {
      final end = i + size > value.length ? value.length : i + size;
      parts.add(value.substring(i, end));
    }
    return parts.join('-');
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static String _field(Map<String, dynamic> map, String key) => map[key]?.toString().trim() ?? '';
}
