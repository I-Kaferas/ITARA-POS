import 'cloud_sync_entity.dart';
import '../sync_models.dart';

class CloudSyncReport {
  const CloudSyncReport({
    this.ok = true,
    this.message = '',
    this.pushed = const {},
    this.pulled = const {},
    this.failed = 0,
    this.cloudReachable = false,
  });

  final bool ok;
  final String message;
  final Map<CloudSyncEntity, int> pushed;
  final Map<CloudSyncEntity, int> pulled;
  final int failed;
  final bool cloudReachable;

  int get totalPushed => pushed.values.fold(0, (a, b) => a + b);

  int get totalPulled => pulled.values.fold(0, (a, b) => a + b);

  SyncReport toSyncReport() {
    return SyncReport(
      ok: ok,
      message: message,
      products: pulled[CloudSyncEntity.products] ?? 0,
      customers: (pulled[CloudSyncEntity.customers] ?? 0) +
          (pushed[CloudSyncEntity.customers] ?? 0),
      users: pulled[CloudSyncEntity.users] ?? 0,
      sent: totalPushed,
    );
  }

  CloudSyncReport copyWith({
    bool? ok,
    String? message,
    Map<CloudSyncEntity, int>? pushed,
    Map<CloudSyncEntity, int>? pulled,
    int? failed,
    bool? cloudReachable,
  }) {
    return CloudSyncReport(
      ok: ok ?? this.ok,
      message: message ?? this.message,
      pushed: pushed ?? this.pushed,
      pulled: pulled ?? this.pulled,
      failed: failed ?? this.failed,
      cloudReachable: cloudReachable ?? this.cloudReachable,
    );
  }
}
