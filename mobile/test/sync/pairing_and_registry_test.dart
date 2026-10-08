import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/sync/device_registry.dart';
import 'package:pos_mobile/sync/local_realtime.dart';
import 'package:pos_mobile/sync/pairing_service.dart';

void main() {
  group('DeviceRegistry.hashToken', () {
    test('is stable and non-empty', () {
      final a = DeviceRegistry.hashToken('abc');
      final b = DeviceRegistry.hashToken('abc');
      final c = DeviceRegistry.hashToken('xyz');
      expect(a, b);
      expect(a, isNot(c));
      expect(a.length, greaterThan(20));
    });
  });

  group('PairingService code validation', () {
    test('rejects expired or missing code', () {
      final pairing = PairingService();
      expect(pairing.validateCode('123456'), isFalse);
      pairing.refreshCode();
      final code = pairing.activeCode;
      expect(code, isNotNull);
      expect(code!.length, 6);
      expect(pairing.validateCode(code), isTrue);
      expect(pairing.validateCode('000000'), isFalse);
      pairing.stopMasterSession();
      expect(pairing.validateCode(code), isFalse);
    });
  });

  group('LanDeviceStatus', () {
    test('parses known values', () {
      expect(LanDeviceStatus.fromString('online'), LanDeviceStatus.online);
      expect(LanDeviceStatus.fromString('blocked'), LanDeviceStatus.blocked);
      expect(LanDeviceStatus.fromString('nope'), LanDeviceStatus.offline);
    });
  });

  group('Realtime DeviceCommand wire (§45)', () {
    test('deviceCommand has stable wire name', () {
      expect(RealtimeEventType.deviceCommand.wire, 'DeviceCommand');
      final event = RealtimeEvent(
        type: RealtimeEventType.deviceCommand,
        payload: {'action': 'sync', 'device_id': 'POS-01'},
      );
      expect(event.toJson()['type'], 'DeviceCommand');
      expect(
        RealtimeEvent.fromJson(event.toJson()).type,
        RealtimeEventType.deviceCommand,
      );
    });
  });

  group('LanDevice §9 fields', () {
    test('toJson exposes registry fields', () {
      final device = LanDevice(
        id: 'POS-01',
        name: 'POS-01',
        deviceType: 'pos',
        os: 'android',
        ip: '192.168.1.10',
        tenantId: 'tenant-1',
        branchId: 'branch-1',
        storeId: 'store-1',
        userId: 'user-1',
        userName: 'Alice',
        role: 'slave',
        version: '0.1.0',
        status: LanDeviceStatus.online,
        lastSeen: DateTime.parse('2026-10-07T12:00:00Z'),
        pairedAt: DateTime.parse('2026-10-07T11:00:00Z'),
        approved: true,
      );
      final json = device.toJson();
      expect(json['device_id'], 'POS-01');
      expect(json['name'], 'POS-01');
      expect(json['type'], 'pos');
      expect(json['os'], 'android');
      expect(json['ip'], '192.168.1.10');
      expect(json['tenant'], 'tenant-1');
      expect(json['branch'], 'branch-1');
      expect(json['user'], {'id': 'user-1', 'name': 'Alice'});
      expect(json['role'], 'slave');
      expect(json['version'], '0.1.0');
      expect(json['status'], 'online');
      expect(json['last_seen'], isNotEmpty);
    });

    test('fromRow falls back branch_id to store_id', () {
      final device = LanDevice.fromRow({
        'device_id': 'Kitchen-01',
        'name': 'Kitchen-01',
        'device_type': 'pos',
        'os': 'Android',
        'ip': '10.0.0.5',
        'tenant_id': 't1',
        'store_id': 's1',
        'role': 'slave',
        'version': '0.1.0',
        'status': 'idle',
        'last_seen': '2026-10-07T12:00:00Z',
        'approved': 1,
        'pending': 0,
      });
      expect(device.branchId, 's1');
      expect(device.status, LanDeviceStatus.idle);
    });
  });
}
