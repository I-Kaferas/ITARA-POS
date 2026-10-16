import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/features/printers/services/raw_printer_output.dart';

void main() {
  test('network target receives the raw bytes on its port', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<List<int>>();
    server.listen((client) {
      final data = <int>[];
      client.listen(data.addAll, onDone: () => received.complete(data));
    });

    final payload = [0x1B, 0x40, 0x41, 0x42, 0x0A, 0x1D, 0x56, 0x42, 0x00];
    await RawPrinterOutput.instance.send(
      RawPrinterTarget.network('127.0.0.1', port: server.port),
      payload,
    );

    expect(await received.future.timeout(const Duration(seconds: 5)), payload);
    await server.close();
  });

  test('probe reports an unreachable printer', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();

    await expectLater(
      RawPrinterOutput.instance.probeNetwork('127.0.0.1', port),
      throwsA(isA<SocketException>()),
    );
  });

  test('mac addresses are normalized and validated', () {
    expect(RawPrinterOutput.normalizeMac(' 66-02-bd-06-18-7b '), '66:02:BD:06:18:7B');
    expect(RawPrinterOutput.isValidMac('66:02:BD:06:18:7B'), isTrue);
    expect(RawPrinterOutput.isValidMac('66:02:BD:06:18'), isFalse);
  });
}
