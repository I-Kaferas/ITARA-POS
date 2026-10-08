import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/core/architecture/architectural_priority.dart';
import 'package:pos_mobile/core/architecture/business_continuity.dart';
import 'package:pos_mobile/core/config/terminal_config.dart';
import 'package:pos_mobile/core/network/operating_mode.dart';

void main() {
  group('BusinessContinuity (§74)', () {
    test('invariants are locked', () {
      expect(BusinessContinuity.internetOutageNeverStopsCommerce, isTrue);
      expect(BusinessContinuity.masterOutageAllowsTemporarySlaveSales, isTrue);
      expect(BusinessContinuity.printerFailureNeverCancelsSale, isTrue);
    });

    test('Internet outage never stops commerce (all roles)', () {
      for (final role in PosRole.values) {
        for (final masterUp in [true, false]) {
          final mode = BusinessContinuity.modeWithoutInternet(
            role: role,
            masterReachable: masterUp,
          );
          expect(
            mode.canSell,
            isTrue,
            reason: '${role.name} master=$masterUp → ${mode.code}',
          );
          expect(
            BusinessContinuity.allowsCommerce(
              role: role,
              masterReachable: masterUp,
              cloudReachable: false,
            ),
            isTrue,
          );
        }
      }
    });

    test('Master outage → Slave Mode C still sells', () {
      expect(
        BusinessContinuity.allowsTemporarySlaveSalesWithoutMaster(),
        isTrue,
      );
      expect(
        BusinessContinuity.allowsTemporarySlaveSalesWithoutMaster(
          cloudReachable: true,
        ),
        isTrue,
      );

      final mode = BusinessContinuity.modeWithoutMaster(
        role: PosRole.slave,
        cloudReachable: false,
      );
      expect(mode, OperatingMode.isolatedOffline);
      expect(mode.canSell, isTrue);
    });

    test('Master without Internet stays Mode B and sells', () {
      final mode = BusinessContinuity.modeWithoutInternet(
        role: PosRole.master,
        masterReachable: true,
      );
      expect(mode, OperatingMode.localOffline);
      expect(mode.canSell, isTrue);
    });

    test('afterSalePrint swallows printer errors', () async {
      final sale = await BusinessContinuity.afterSalePrint(
        {'id': 'sale-1', 'ok': true},
        () async => throw Exception('printer offline'),
      );
      expect(sale['id'], 'sale-1');
      expect(sale['ok'], isTrue);
    });

    test('afterSalePrint returns sale when print succeeds', () async {
      var printed = false;
      final sale = await BusinessContinuity.afterSalePrint(
        'committed',
        () async => printed = true,
      );
      expect(sale, 'committed');
      expect(printed, isTrue);
    });

    test('commerce priority is offline-first (outranks cloud)', () {
      expect(
        BusinessContinuity.commercePriority,
        ArchitecturalPriority.offlineFirst,
      );
      expect(
        BusinessContinuity.commercePriority.outranks(
          ArchitecturalPriority.cloudErp,
        ),
        isTrue,
      );
    });
  });

  group('ArchitecturalPriority (§75)', () {
    test('exact order 1→10', () {
      expect(
        ArchitecturalPriority.ordered.map((p) => p.label).toList(),
        [
          'OFFLINE-FIRST',
          'LOCAL DATABASE',
          'MASTER / SLAVE',
          'NETWORK DISCOVERY',
          'SYNCHRONIZATION',
          'PRINTER MANAGEMENT',
          'POS TRANSACTIONS',
          'SECURITY',
          'REALTIME',
          'CLOUD ERP',
        ],
      );
      for (var i = 0; i < ArchitecturalPriority.ordered.length; i++) {
        expect(ArchitecturalPriority.ordered[i].rank, i + 1);
      }
    });

    test('offline-first outranks everything else', () {
      for (final other in ArchitecturalPriority.values) {
        if (other == ArchitecturalPriority.offlineFirst) continue;
        expect(
          ArchitecturalPriority.offlineFirst.outranks(other),
          isTrue,
          reason: other.label,
        );
      }
    });

    test('cloud ERP loses to every higher layer', () {
      for (final other in ArchitecturalPriority.values) {
        if (other == ArchitecturalPriority.cloudErp) continue;
        expect(other.outranks(ArchitecturalPriority.cloudErp), isTrue);
      }
    });

    test('prefer picks the higher priority', () {
      expect(
        ArchitecturalPriority.prefer(
          ArchitecturalPriority.cloudErp,
          ArchitecturalPriority.localDatabase,
        ),
        ArchitecturalPriority.localDatabase,
      );
      expect(
        ArchitecturalPriority.prefer(
          ArchitecturalPriority.synchronization,
          ArchitecturalPriority.offlineFirst,
        ),
        ArchitecturalPriority.offlineFirst,
      );
    });
  });
}
