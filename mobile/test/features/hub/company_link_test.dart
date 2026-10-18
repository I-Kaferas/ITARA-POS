import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/core/config/terminal_config.dart';
import 'package:pos_mobile/features/hub/domain/company_link.dart';

void main() {
  test('formats a dashboard join key into ITN groups', () {
    expect(CompanyLink.formatJoinKey('itnab12cd34ef56'), 'ITN-AB12-CD34-EF56');
    expect(CompanyLink.formatJoinKey('ITN-AB12-CD34-EF56'), 'ITN-AB12-CD34-EF56');
    expect(CompanyLink.formatJoinKey('ab12cd34ef56'), 'AB12-CD34-EF56');
    expect(CompanyLink.isComplete('ITN-AB12-CD34-EF56'), isTrue);
    expect(CompanyLink.isComplete('ITN-AB12'), isFalse);
  });

  test('a validated join key fills the company fields and keeps the session', () {
    const current = TerminalConfig(
      authToken: 'session-token',
      cashierName: 'Aline',
      deviceName: 'Caisse 1',
      currencyCode: 'USD',
      tenantSlug: '',
      companyProfile: '',
    );

    final next = CompanyLink.applyPair(
      current: current,
      joinKey: 'itnab12cd34ef56',
      data: {
        'id': 'device-1',
        'tenant_id': 'tenant-1',
        'store_id': 'store-1',
        'name': 'Comptoir',
        'pos_role': 'master',
        'company': {
          'name': 'NIC Africa',
          'legal_name': 'NIC Africa Ltd',
          'tax_id': '400123',
          'currency_code': 'bif',
          'locale': 'fr',
          'timezone': 'Africa/Bujumbura',
          'logo_url': 'https://cdn.example/logo.png',
          'tenant_slug': 'nic-africa',
          'phone': '+257 22 000',
          'address': {'city': 'Bujumbura', 'country': 'BI'},
          'store_name': 'Boutique centre',
          'branch_name': 'Bujumbura',
        },
      },
    );

    expect(next.deviceSyncToken, 'ITN-AB12-CD34-EF56');
    expect(next.authToken, 'session-token');
    expect(next.cashierName, 'Aline');
    expect(next.deviceName, 'Caisse 1');
    expect(next.deviceId, 'device-1');
    expect(next.tenantId, 'tenant-1');
    expect(next.tenantSlug, 'nic-africa');
    expect(next.storeId, 'store-1');
    expect(next.brandName, 'NIC Africa');
    expect(next.brandLogoUrl, 'https://cdn.example/logo.png');
    expect(next.currencyCode, 'BIF');
    expect(next.locale, 'fr');
    expect(next.timezone, 'Africa/Bujumbura');
    expect(next.posRole, PosRole.master);
    expect(next.isConfigured, isTrue);
    expect(next.companyProfile, contains('NIC Africa Ltd'));
    expect(next.companyProfile, contains('NIF 400123'));
    expect(next.companyProfile, contains('Bujumbura'));
    expect(next.companyProfile, contains('Boutique centre'));

    final restored = TerminalConfig.fromJson(next.toJson());
    expect(restored.deviceSyncToken, next.deviceSyncToken);
    expect(restored.brandName, 'NIC Africa');
    expect(restored.storeId, 'store-1');
  });

  test('keeps existing company fields when the payload has no company block', () {
    const current = TerminalConfig(
      brandName: 'Déjà là',
      tenantId: 'tenant-keep',
      storeId: 'store-keep',
      companyProfile: 'Profil local',
    );

    final next = CompanyLink.applyPair(
      current: current,
      joinKey: 'ITN-ZZZZ-YYYY-XXXX',
      data: {'device_id': 'device-9'},
    );

    expect(next.deviceId, 'device-9');
    expect(next.brandName, 'Déjà là');
    expect(next.tenantId, 'tenant-keep');
    expect(next.storeId, 'store-keep');
    expect(next.companyProfile, 'Profil local');
    expect(next.deviceName, isEmpty);
  });
}
