import '../core/network/operating_mode.dart';
import 'offline_store.dart';
import 'sync_engine.dart';

/// File offline Mode C — opérations locales jusqu’au retour du Master.
///
/// La persistence est dans `sync_outbox` SQLite (via [OfflineStore]).
/// Ce facade expose le cycle Slave → Outbox → Master → Cloud.
class SyncQueue {
  SyncQueue({
    OfflineStore? store,
    SyncEngine? engine,
  })  : _store = store ?? OfflineStore.instance,
        _engine = engine ?? SyncEngine.instance;

  final OfflineStore _store;
  final SyncEngine _engine;

  Future<Map<String, int>> counts() => _store.counts();

  Future<List<Map<String, dynamic>>> pending({int limit = 100}) =>
      _store.pendingQueue(limit: limit);

  Future<List<Map<String, dynamic>>> details({int limit = 80}) =>
      _store.queueDetails(limit: limit);

  /// True quand le terminal est en Mode C (file locale seule).
  bool get isIsolated =>
      _engine.operatingMode == OperatingMode.isolatedOffline;

  /// Rejoue la file dès que le Master (ou Cloud autorisé) est de nouveau joignable.
  Future<int> flushWhenReachable() async {
    if (!_engine.router.shouldDrainQueue) return 0;
    await _store.releaseStuck();
    await _store.retryAllFailed();
    final report = await _engine.sendStock();
    return report.sent;
  }
}
