/// Shared app-wide constants (Clean Architecture — core/constants).
abstract final class AppConstants {
  static const String appName = 'ITARA POS';
  static const String apiVersion = 'v1';
  static const int defaultPrinterPort = 9100;
  static const Duration masterHeartbeatInterval = Duration(seconds: 5);
  static const Duration printQueueTick = Duration(seconds: 2);
  static const int printMaxAttempts = 5;
}
