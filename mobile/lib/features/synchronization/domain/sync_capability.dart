import '../../../core/architecture/business_continuity.dart';
import '../../../core/network/operating_mode.dart';

/// Domain view of what sync is allowed in the current network state.
class SyncCapability {
  const SyncCapability({
    required this.canSyncMaster,
    required this.canSyncCloud,
    required this.canSellOffline,
  });

  final bool canSyncMaster;
  final bool canSyncCloud;

  /// §74 — always true when derived from [OperatingMode] (offline-first).
  final bool canSellOffline;

  factory SyncCapability.fromMode(OperatingMode mode) {
    assert(BusinessContinuity.internetOutageNeverStopsCommerce);
    return SyncCapability(
      canSyncMaster: mode.canSyncMaster,
      canSyncCloud: mode.canSyncCloud,
      canSellOffline: mode.canSell,
    );
  }
}
