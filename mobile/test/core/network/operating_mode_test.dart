import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/core/config/terminal_config.dart';
import 'package:pos_mobile/core/network/operating_mode.dart';
import 'package:pos_mobile/core/network/operation_router.dart';

void main() {
  group('OperatingModeResolver — Mode A / B / C', () {
    group('Master', () {
      test('Mode A when cloud reachable', () {
        expect(
          OperatingModeResolver.resolve(
            role: PosRole.master,
            masterReachable: true,
            cloudReachable: true,
          ),
          OperatingMode.fullOnline,
        );
      });

      test('Mode B when cloud down (commerce local continues)', () {
        expect(
          OperatingModeResolver.resolve(
            role: PosRole.master,
            masterReachable: true,
            cloudReachable: false,
          ),
          OperatingMode.localOffline,
        );
      });

      test('Master never enters Mode C', () {
        expect(
          OperatingModeResolver.resolve(
            role: PosRole.master,
            masterReachable: false,
            cloudReachable: false,
          ),
          OperatingMode.localOffline,
        );
      });
    });

    group('Slave', () {
      test('Mode A — Master + Cloud', () {
        expect(
          OperatingModeResolver.resolve(
            role: PosRole.slave,
            masterReachable: true,
            cloudReachable: true,
          ),
          OperatingMode.fullOnline,
        );
      });

      test('Mode B — Master up, Internet down', () {
        expect(
          OperatingModeResolver.resolve(
            role: PosRole.slave,
            masterReachable: true,
            cloudReachable: false,
          ),
          OperatingMode.localOffline,
        );
      });

      test('Mode C — Master lost', () {
        expect(
          OperatingModeResolver.resolve(
            role: PosRole.slave,
            masterReachable: false,
            cloudReachable: false,
          ),
          OperatingMode.isolatedOffline,
        );
      });

      test('Mode C even if Cloud is up but Master is lost', () {
        // Offline-first: Slave must not bypass Master via Internet.
        expect(
          OperatingModeResolver.resolve(
            role: PosRole.slave,
            masterReachable: false,
            cloudReachable: true,
          ),
          OperatingMode.isolatedOffline,
        );
      });
    });

    group('Standalone', () {
      test('Mode A when cloud reachable', () {
        expect(
          OperatingModeResolver.resolve(
            role: PosRole.standalone,
            masterReachable: false,
            cloudReachable: true,
          ),
          OperatingMode.fullOnline,
        );
      });

      test('Mode C when offline (local queue)', () {
        expect(
          OperatingModeResolver.resolve(
            role: PosRole.standalone,
            masterReachable: false,
            cloudReachable: false,
          ),
          OperatingMode.isolatedOffline,
        );
      });
    });
  });

  group('OperatingMode capabilities', () {
    test('canSell always true (offline-first)', () {
      for (final mode in OperatingMode.values) {
        expect(mode.canSell, isTrue, reason: mode.label);
      }
    });

    test('codes A / B / C', () {
      expect(OperatingMode.fullOnline.code, 'A');
      expect(OperatingMode.localOffline.code, 'B');
      expect(OperatingMode.isolatedOffline.code, 'C');
    });

    test('sync paths match architecture', () {
      expect(OperatingMode.fullOnline.syncPath, 'POS → Master → Cloud');
      expect(OperatingMode.localOffline.syncPath, 'POS → Master → Local DB');
      expect(
        OperatingMode.isolatedOffline.syncPath,
        'POS → SQLite → Offline Queue',
      );
    });

    test('canSyncMaster / canSyncCloud', () {
      expect(OperatingMode.fullOnline.canSyncMaster, isTrue);
      expect(OperatingMode.fullOnline.canSyncCloud, isTrue);

      expect(OperatingMode.localOffline.canSyncMaster, isTrue);
      expect(OperatingMode.localOffline.canSyncCloud, isFalse);

      expect(OperatingMode.isolatedOffline.canSyncMaster, isFalse);
      expect(OperatingMode.isolatedOffline.canSyncCloud, isFalse);
    });
  });

  group('OperationRouter — outbound targets', () {
    test('Mode A Slave → Master only (never Cloud direct)', () {
      const router = OperationRouter(
        mode: OperatingMode.fullOnline,
        role: PosRole.slave,
      );
      expect(router.outboundTarget, SyncTargetKind.master);
      expect(router.allowsDirectCloud, isFalse);
      expect(router.shouldDrainQueue, isTrue);
    });

    test('Mode A Master → Cloud', () {
      const router = OperationRouter(
        mode: OperatingMode.fullOnline,
        role: PosRole.master,
      );
      expect(router.outboundTarget, SyncTargetKind.cloud);
      expect(router.allowsDirectCloud, isTrue);
    });

    test('Mode B Slave → Master', () {
      const router = OperationRouter(
        mode: OperatingMode.localOffline,
        role: PosRole.slave,
      );
      expect(router.outboundTarget, SyncTargetKind.master);
      expect(router.shouldDrainQueue, isTrue);
      expect(router.allowsDirectCloud, isFalse);
    });

    test('Mode B Master → local queue (wait for cloud)', () {
      const router = OperationRouter(
        mode: OperatingMode.localOffline,
        role: PosRole.master,
      );
      expect(router.outboundTarget, SyncTargetKind.localQueue);
      expect(router.shouldDrainQueue, isFalse);
    });

    test('Mode C → local queue only', () {
      const router = OperationRouter(
        mode: OperatingMode.isolatedOffline,
        role: PosRole.slave,
      );
      expect(router.outboundTarget, SyncTargetKind.localQueue);
      expect(router.shouldDrainQueue, isFalse);
      expect(router.allowsDirectCloud, isFalse);
    });

    test('Mode C recovery path Slave → Queue → Master → Cloud', () {
      const router = OperationRouter(
        mode: OperatingMode.isolatedOffline,
        role: PosRole.slave,
      );
      expect(
        router.recoveryPath,
        [
          SyncTargetKind.localQueue,
          SyncTargetKind.master,
          SyncTargetKind.cloud,
        ],
      );
    });
  });

  group('Scénarios métier', () {
    test('Internet tombe → Slave passe A → B, ventes autorisées', () {
      final before = OperatingModeResolver.resolve(
        role: PosRole.slave,
        masterReachable: true,
        cloudReachable: true,
      );
      final after = OperatingModeResolver.resolve(
        role: PosRole.slave,
        masterReachable: true,
        cloudReachable: false,
      );
      expect(before, OperatingMode.fullOnline);
      expect(after, OperatingMode.localOffline);
      expect(after.canSell, isTrue);
      expect(
        const OperationRouter(mode: OperatingMode.localOffline, role: PosRole.slave)
            .outboundTarget,
        SyncTargetKind.master,
      );
    });

    test('Master tombe → Slave passe B → C, file locale', () {
      final before = OperatingModeResolver.resolve(
        role: PosRole.slave,
        masterReachable: true,
        cloudReachable: false,
      );
      final after = OperatingModeResolver.resolve(
        role: PosRole.slave,
        masterReachable: false,
        cloudReachable: false,
      );
      expect(before, OperatingMode.localOffline);
      expect(after, OperatingMode.isolatedOffline);
      expect(after.canSell, isTrue);
      expect(
        const OperationRouter(
          mode: OperatingMode.isolatedOffline,
          role: PosRole.slave,
        ).outboundTarget,
        SyncTargetKind.localQueue,
      );
    });

    test('Master revient → Mode C peut rejouer vers Master', () {
      final recovered = OperatingModeResolver.resolve(
        role: PosRole.slave,
        masterReachable: true,
        cloudReachable: false,
      );
      expect(recovered, OperatingMode.localOffline);
      final router = OperationRouter(mode: recovered, role: PosRole.slave);
      expect(router.shouldDrainQueue, isTrue);
      expect(router.outboundTarget, SyncTargetKind.master);
    });
  });
}
