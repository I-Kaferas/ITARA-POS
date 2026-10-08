import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/core/config/terminal_config.dart';
import 'package:pos_mobile/core/network/network_bloc.dart';
import 'package:pos_mobile/core/network/network_status.dart';
import 'package:pos_mobile/core/network/operating_mode.dart';
import 'package:pos_mobile/core/network/operation_router.dart';

void main() {
  group('NetworkStatus §17 wire names', () {
    test('matches mobile.md §17', () {
      expect(NetworkStatus.noNetwork.wire, 'NO_NETWORK');
      expect(NetworkStatus.localNetworkOnly.wire, 'LOCAL_NETWORK_ONLY');
      expect(NetworkStatus.masterConnected.wire, 'MASTER_CONNECTED');
      expect(NetworkStatus.internetConnected.wire, 'INTERNET_CONNECTED');
      expect(NetworkStatus.fullyOnline.wire, 'FULLY_ONLINE');
    });

    test('fromWire round-trip', () {
      for (final status in NetworkStatus.values) {
        expect(NetworkStatus.fromWire(status.wire), status);
      }
    });
  });

  group('NetworkStatus.resolve', () {
    test('FULLY_ONLINE when master + internet', () {
      expect(
        NetworkStatus.resolve(
          masterReachable: true,
          internetReachable: true,
          lanVisible: true,
        ),
        NetworkStatus.fullyOnline,
      );
    });

    test('MASTER_CONNECTED when master only', () {
      expect(
        NetworkStatus.resolve(
          masterReachable: true,
          internetReachable: false,
          lanVisible: false,
        ),
        NetworkStatus.masterConnected,
      );
    });

    test('INTERNET_CONNECTED when internet only', () {
      expect(
        NetworkStatus.resolve(
          masterReachable: false,
          internetReachable: true,
          lanVisible: false,
        ),
        NetworkStatus.internetConnected,
      );
    });

    test('LOCAL_NETWORK_ONLY when LAN peers without master/internet', () {
      expect(
        NetworkStatus.resolve(
          masterReachable: false,
          internetReachable: false,
          lanVisible: true,
        ),
        NetworkStatus.localNetworkOnly,
      );
    });

    test('NO_NETWORK when nothing', () {
      expect(
        NetworkStatus.resolve(
          masterReachable: false,
          internetReachable: false,
          lanVisible: false,
        ),
        NetworkStatus.noNetwork,
      );
    });
  });

  group('NetworkStatus capabilities §17', () {
    test('CanSell always true (offline-first)', () {
      for (final status in NetworkStatus.values) {
        expect(status.canSell, isTrue);
      }
    });

    test('CanSyncMaster only MASTER_CONNECTED / FULLY_ONLINE', () {
      expect(NetworkStatus.noNetwork.canSyncMaster, isFalse);
      expect(NetworkStatus.localNetworkOnly.canSyncMaster, isFalse);
      expect(NetworkStatus.internetConnected.canSyncMaster, isFalse);
      expect(NetworkStatus.masterConnected.canSyncMaster, isTrue);
      expect(NetworkStatus.fullyOnline.canSyncMaster, isTrue);
    });

    test('CanSyncCloud only INTERNET_CONNECTED / FULLY_ONLINE', () {
      expect(NetworkStatus.noNetwork.canSyncCloud, isFalse);
      expect(NetworkStatus.localNetworkOnly.canSyncCloud, isFalse);
      expect(NetworkStatus.masterConnected.canSyncCloud, isFalse);
      expect(NetworkStatus.internetConnected.canSyncCloud, isTrue);
      expect(NetworkStatus.fullyOnline.canSyncCloud, isTrue);
    });

    test('CanPrint always true', () {
      for (final status in NetworkStatus.values) {
        expect(status.canPrint, isTrue);
      }
    });

    test('CanUseKitchen when Master path available', () {
      expect(NetworkStatus.noNetwork.canUseKitchen, isFalse);
      expect(NetworkStatus.localNetworkOnly.canUseKitchen, isFalse);
      expect(NetworkStatus.internetConnected.canUseKitchen, isFalse);
      expect(NetworkStatus.masterConnected.canUseKitchen, isTrue);
      expect(NetworkStatus.fullyOnline.canUseKitchen, isTrue);
    });
  });

  group('NetworkState Mode A / B / C', () {
    test('Mode A — FULLY_ONLINE', () {
      const state = NetworkState(
        status: NetworkStatus.fullyOnline,
        mode: OperatingMode.fullOnline,
        masterReachable: true,
        internetReachable: true,
        role: PosRole.slave,
      );
      expect(state.statusWire, 'FULLY_ONLINE');
      expect(state.canSell, isTrue);
      expect(state.canSyncCloud, isTrue);
      expect(state.canSyncMaster, isTrue);
      expect(state.canPrint, isTrue);
      expect(state.canUseKitchen, isTrue);
      expect(state.router.outboundTarget, SyncTargetKind.master);
    });

    test('Mode B — MASTER_CONNECTED', () {
      const state = NetworkState(
        status: NetworkStatus.masterConnected,
        mode: OperatingMode.localOffline,
        masterReachable: true,
        internetReachable: false,
        role: PosRole.slave,
      );
      expect(state.statusWire, 'MASTER_CONNECTED');
      expect(state.canSell, isTrue);
      expect(state.canSyncCloud, isFalse);
      expect(state.canSyncMaster, isTrue);
      expect(state.canUseKitchen, isTrue);
      expect(state.router.outboundTarget, SyncTargetKind.master);
    });

    test('Mode C — NO_NETWORK', () {
      const state = NetworkState(
        status: NetworkStatus.noNetwork,
        mode: OperatingMode.isolatedOffline,
        masterReachable: false,
        internetReachable: false,
        role: PosRole.slave,
      );
      expect(state.statusWire, 'NO_NETWORK');
      expect(state.canSell, isTrue);
      expect(state.canSyncCloud, isFalse);
      expect(state.canSyncMaster, isFalse);
      expect(state.canUseKitchen, isFalse);
      expect(state.router.outboundTarget, SyncTargetKind.localQueue);
    });

    test('Slave INTERNET_CONNECTED without Master cannot sync cloud', () {
      const state = NetworkState(
        status: NetworkStatus.internetConnected,
        mode: OperatingMode.isolatedOffline,
        masterReachable: false,
        internetReachable: true,
        role: PosRole.slave,
      );
      expect(state.canSyncCloud, isFalse);
      expect(state.canSyncMaster, isFalse);
      expect(state.canSell, isTrue);
    });

    test('LOCAL_NETWORK_ONLY — sell yes, master sync no', () {
      const state = NetworkState(
        status: NetworkStatus.localNetworkOnly,
        mode: OperatingMode.isolatedOffline,
        lanVisible: true,
        role: PosRole.slave,
      );
      expect(state.statusWire, 'LOCAL_NETWORK_ONLY');
      expect(state.canSell, isTrue);
      expect(state.canSyncMaster, isFalse);
      expect(state.canUseKitchen, isFalse);
    });
  });
}
