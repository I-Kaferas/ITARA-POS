import 'package:equatable/equatable.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.id,
    required this.name,
    required this.token,
    required this.refreshToken,
    required this.expiresIn,
    required this.permissions,
    required this.roles,
    this.companyProfile,
    this.currencyCode,
    this.locale,
    this.timezone,
  });

  final String id;
  final String name;
  final String token;
  final String refreshToken;
  final int expiresIn;
  final List<String> permissions;
  final List<String> roles;
  final Map<String, dynamic>? companyProfile;
  final String? currencyCode;
  final String? locale;
  final String? timezone;

  @override
  List<Object?> get props => [
        id,
        name,
        token,
        refreshToken,
        expiresIn,
        permissions,
        roles,
        companyProfile,
        currencyCode,
        locale,
        timezone,
      ];
}
