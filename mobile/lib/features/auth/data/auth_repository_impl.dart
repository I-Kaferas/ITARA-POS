import 'dart:convert';

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/entities/auth_session.dart';
import '../domain/repositories/auth_repository.dart';
import 'pin_auth_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required PinAuthService pinAuthService,
    required TerminalConfigRepository configRepository,
    required AppLogger logger,
  })  : _auth = pinAuthService,
        _config = configRepository,
        _log = logger.tagged('auth');

  final PinAuthService _auth;
  final TerminalConfigRepository _config;
  final AppLogger _log;

  @override
  bool get isSignedIn {
    final c = _config.config;
    return c.isSignedIn && c.authToken.trim().isNotEmpty;
  }

  @override
  Future<AuthSession> pinLogin(String pin) async {
    _log.info('PIN login attempt');
    final raw = await _auth.login(pin);
    final profile = await _auth.downloadCompanyProfile(
      token: raw.token,
      tenantId: _config.config.tenantId,
    );
    final currency = (profile?['currency_code'] as String?)?.trim();
    final locale = (profile?['locale'] as String?)?.trim();
    final timezone = (profile?['timezone'] as String?)?.trim();

    return AuthSession(
      id: raw.id,
      name: raw.name,
      token: raw.token,
      refreshToken: raw.refreshToken,
      expiresIn: raw.expiresIn,
      permissions: raw.permissions,
      roles: raw.roles,
      companyProfile: profile,
      currencyCode: currency == null || currency.isEmpty ? null : currency,
      locale: locale == null || locale.isEmpty ? null : locale,
      timezone: timezone == null || timezone.isEmpty ? null : timezone,
    );
  }

  @override
  Future<void> persistSession(AuthSession session, {required String pin}) async {
    final repo = _config;
    await repo.save(repo.config.copyWith(
      authToken: session.token,
      refreshToken: session.refreshToken,
      tokenExpiresAt:
          DateTime.now().add(Duration(seconds: session.expiresIn)).toIso8601String(),
      cashierId: session.id,
      cashierName: session.name,
      permissions: session.permissions,
      roles: session.roles,
      pinVerifier: PinAuthService.pinVerifier(session.id, pin),
      isSignedIn: true,
      currencyCode: session.currencyCode ?? repo.config.currencyCode,
      locale: session.locale ?? repo.config.locale,
      timezone: session.timezone ?? repo.config.timezone,
      companyProfile: session.companyProfile == null
          ? repo.config.companyProfile
          : jsonEncode(session.companyProfile),
    ));
    _log.info('Session persisted for cashier=${session.id}');
  }

  @override
  Future<void> signOut() async {
    _log.info('Sign out');
    await PinAuthService.signOut();
  }

  @override
  Future<void> restoreSession() async {
    await _config.ensureLoaded();
    _log.debug('Session restore isSignedIn=$isSignedIn');
  }
}
