import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/sync/pairing_models.dart';
import 'package:pos_mobile/sync/pairing_service.dart';

void main() {
  group('PairingPhase (§8)', () {
    test('pipeline labels', () {
      expect(PairingPhase.discovery.label, 'Discovery');
      expect(PairingPhase.authorization.label, 'Authorization');
      expect(PairingPhase.registered.label, 'Registered');
    });
  });

  group('PairingQrPayload', () {
    test('encode / parse round-trip', () {
      const payload = PairingQrPayload(
        masterId: 'master-001',
        ip: '192.168.1.10',
        port: 8001,
        name: 'ITARA POS Gitega',
        code: '739421',
        tenantId: 't1',
        branchId: 'b1',
      );
      final raw = payload.encode();
      final parsed = PairingQrPayload.tryParse(raw);
      expect(parsed, isNotNull);
      expect(parsed!.masterId, 'master-001');
      expect(parsed.ip, '192.168.1.10');
      expect(parsed.port, 8001);
      expect(parsed.code, '739421');
      expect(parsed.hostEndpoint, '192.168.1.10:8001');
    });

    test('rejects non ITARA_PAIR', () {
      expect(PairingQrPayload.tryParse('{"type":"OTHER"}'), isNull);
      expect(PairingQrPayload.tryParse('not-json'), isNull);
    });
  });

  group('PairingRequest', () {
    test('wants to connect label', () {
      final req = PairingRequest(
        id: 'r1',
        deviceId: 'd1',
        deviceName: 'POS-ANDROID-004',
        deviceType: 'pos',
        os: 'android',
        ip: '192.168.1.20',
        role: 'slave',
        version: '0.1.0',
        code: '739421',
      );
      expect(req.wantsToConnectLabel, 'POS-ANDROID-004 wants to connect.');
      expect(req.phase, PairingPhase.authorization);
      expect(req.code, '739421');
    });
  });

  group('PairingService — code + approval', () {
    test('invalid code rejected before pending', () async {
      final pairing = PairingService();
      expect(
        () => pairing.submitPairRequest(
          code: '000000',
          deviceId: 'd1',
          deviceName: 'POS-1',
          deviceType: 'pos',
          os: 'android',
          ip: '10.0.0.2',
          role: 'slave',
          version: '1',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('valid code creates pending authorization request', () async {
      final pairing = PairingService();
      pairing.refreshCode();
      final code = pairing.activeCode!;
      expect(code.length, 6);

      final decisionFuture = pairing.submitPairRequest(
        code: code,
        deviceId: 'pos-android-004',
        deviceName: 'POS-ANDROID-004',
        deviceType: 'pos',
        os: 'android',
        ip: '192.168.1.44',
        role: 'slave',
        version: '0.1.0',
        timeout: const Duration(seconds: 2),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(pairing.pendingRequests, isNotEmpty);
      final pending = pairing.pendingRequests.first;
      expect(pending.wantsToConnectLabel, 'POS-ANDROID-004 wants to connect.');
      expect(pending.code, code);
      expect(pending.phase, PairingPhase.authorization);

      // Master REJECT in this unit test (ACCEPT hits SQLite — covered by integration).
      pairing.rejectRequest(pending.id);
      final decision = await decisionFuture;
      expect(decision.accepted, isFalse);
      expect(pairing.pendingRequests, isEmpty);
    });

    test('REJECT returns rejected decision', () async {
      final pairing = PairingService();
      pairing.refreshCode();
      final code = pairing.activeCode!;

      final rejectFuture = () async {
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          if (pairing.pendingRequests.isNotEmpty) {
            pairing.rejectRequest(pairing.pendingRequests.first.id);
            break;
          }
        }
      }();

      final decisionFuture = pairing.submitPairRequest(
        code: code,
        deviceId: 'pos-2',
        deviceName: 'POS-2',
        deviceType: 'pos',
        os: 'windows',
        ip: '192.168.1.50',
        role: 'slave',
        version: '0.1.0',
        timeout: const Duration(seconds: 5),
      );

      await rejectFuture;
      final decision = await decisionFuture;
      expect(decision.accepted, isFalse);
      expect(decision.reason, contains('Refusé'));
    });

    test('validateCode after stopMasterSession fails', () {
      final pairing = PairingService();
      pairing.refreshCode();
      final code = pairing.activeCode!;
      expect(pairing.validateCode(code), isTrue);
      pairing.stopMasterSession();
      expect(pairing.validateCode(code), isFalse);
    });
  });
}
