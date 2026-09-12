class AppConfig {
  static const String appName = 'POS Mobile';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );
  static const String authToken = String.fromEnvironment('AUTH_TOKEN');
  static const String tenantId = String.fromEnvironment('TENANT_ID');
  static const String storeId = String.fromEnvironment('STORE_ID');
  static const String currencyCode = String.fromEnvironment(
    'CURRENCY_CODE',
    defaultValue: 'USD',
  );
  static const String appVersion = '0.1.0';
}
