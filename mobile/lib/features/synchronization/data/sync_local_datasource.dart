import '../../../core/sync/sync.dart';

/// Data layer access to the offline sync engine / queue.
class SyncLocalDataSource {
  SyncLocalDataSource({
    OfflineStore? store,
    SyncQueue? queue,
    SyncEngine? engine,
  })  : store = store ?? OfflineStore.instance,
        engine = engine ?? SyncEngine.instance,
        _injectedQueue = queue;

  final OfflineStore store;
  final SyncEngine engine;
  final SyncQueue? _injectedQueue;

  SyncQueue get queue =>
      _injectedQueue ?? SyncQueue(store: store, engine: engine);
}
