import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/sync/discovery/master_beacon.dart';

void main() {
  group('MasterBeacon constants (§6)', () {
    test('mDNS service type is _itara-pos._tcp', () {
      expect(MasterBeacon.mdnsServiceType, '_itara-pos._tcp');
    });

    test('mDNS instance name is ITARA-POS-MASTER', () {
      expect(MasterBeacon.mdnsInstanceName, 'ITARA-POS-MASTER');
    });

    test('UDP beacon port is 8002', () {
      expect(MasterBeacon.udpPort, 8002);
    });
  });

  group('MasterBeaconCodec — response (§7)', () {
    test('builds ITARA_MASTER_RESPONSE payload (§7)', () {
      final body = MasterBeaconCodec.buildResponse(
        masterId: 'master-001',
        name: 'ITARA POS Gitega',
        ip: '192.168.1.10',
        port: 8765,
        tenantId: 'tenant-1',
        branchId: 'branch-1',
        version: '1.0.0',
      );

      expect(body['type'], 'ITARA_MASTER_RESPONSE');
      expect(body['master_id'], 'master-001');
      expect(body['name'], 'ITARA POS Gitega');
      expect(body['ip'], '192.168.1.10');
      expect(body['port'], 8765);
      expect(body['tenant_id'], 'tenant-1');
      expect(body['branch_id'], 'branch-1');
      expect(body['version'], '1.0.0');
    });

    test('toResponseJson matches §7 schema exactly', () {
      final found = MasterBeaconCodec.parseResponse(
        MasterBeaconCodec.buildResponse(
          masterId: 'master-001',
          name: 'ITARA POS Gitega',
          ip: '192.168.1.10',
          port: 8765,
          tenantId: '...',
          branchId: '...',
          version: '1.0.0',
        ),
      )!;
      expect(found.toResponseJson(), {
        'type': 'ITARA_MASTER_RESPONSE',
        'master_id': 'master-001',
        'name': 'ITARA POS Gitega',
        'ip': '192.168.1.10',
        'port': 8765,
        'tenant_id': '...',
        'branch_id': '...',
        'version': '1.0.0',
      });
      expect(found.displayHost, '192.168.1.10');
      expect(found.isOnline, isTrue);
    });

    test('encode / decode round-trip', () {
      final body = MasterBeaconCodec.buildResponse(
        masterId: 'm1',
        name: 'Master',
        ip: '10.0.0.5',
        port: 8001,
        tenantId: 't',
        branchId: 'b',
        version: '0.1.0',
      );
      final bytes = MasterBeaconCodec.encode(body);
      final decoded = MasterBeaconCodec.decode(bytes);
      expect(decoded, isNotNull);
      expect(decoded!['ip'], '10.0.0.5');
      expect(MasterBeaconCodec.isResponse(decoded), isTrue);
    });

    test('parseResponse yields DiscoveredMaster', () {
      final body = MasterBeaconCodec.buildResponse(
        masterId: 'master-001',
        name: 'ITARA POS Gitega',
        ip: '192.168.1.10',
        port: 8765,
        tenantId: 'tenant-x',
        branchId: 'store-y',
        version: '1.0.0',
      );
      final found = MasterBeaconCodec.parseResponse(body);
      expect(found, isNotNull);
      expect(found!.host, '192.168.1.10');
      expect(found.port, 8765);
      expect(found.name, 'ITARA POS Gitega');
      expect(found.masterId, 'master-001');
      expect(found.tenantId, 'tenant-x');
      expect(found.storeId, 'store-y');
      expect(found.displayHost, '192.168.1.10');
      expect(found.displayEndpoint, '192.168.1.10:8765');
      expect(found.transport, DiscoveryTransport.udp);
    });

    test('ignores self LAN address', () {
      final body = MasterBeaconCodec.buildResponse(
        masterId: 'm1',
        name: 'Self',
        ip: '192.168.1.10',
        port: 8001,
        tenantId: '',
        branchId: '',
        version: '1',
      );
      expect(
        MasterBeaconCodec.parseResponse(
          body,
          selfLanAddress: '192.168.1.10',
        ),
        isNull,
      );
    });

    test('rejects non-response packets', () {
      expect(
        MasterBeaconCodec.parseResponse({'type': 'OTHER'}),
        isNull,
      );
      expect(MasterBeaconCodec.decode(utf8.encode('not-json')), isNull);
    });
  });

  group('MasterBeaconCodec — UDP query', () {
    test('builds ITARA_MASTER_QUERY', () {
      final query = MasterBeaconCodec.buildQuery(
        tenantId: 't1',
        storeId: 's1',
        deviceId: 'd1',
      );
      expect(query['type'], 'ITARA_MASTER_QUERY');
      expect(MasterBeaconCodec.isQuery(query), isTrue);
      expect(MasterBeaconCodec.isResponse(query), isFalse);
    });
  });

  group('TXT records for mDNS', () {
    test('encodes and decodes UTF-8 TXT', () {
      final txt = MasterBeaconCodec.txtRecords(
        masterId: 'master-001',
        name: 'ITARA POS Gitega',
        tenantId: 'tenant-1',
        branchId: 'branch-1',
        version: '1.0.0',
        ip: '192.168.1.10',
      );
      expect(MasterBeaconCodec.txtString(txt, 'master_id'), 'master-001');
      expect(MasterBeaconCodec.txtString(txt, 'ip'), '192.168.1.10');
      expect(MasterBeaconCodec.txtString(txt, 'type'), 'ITARA_MASTER_RESPONSE');
      expect(MasterBeaconCodec.txtString(txt, 'missing'), isNull);
    });
  });
}
