import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/core/logging/log_entry.dart';
import 'package:pos_mobile/core/logging/log_type.dart';

void main() {
  test('log channels match the support spec', () {
    expect(
      LogType.values.map((t) => t.label).toList(),
      [
        'INFO',
        'WARNING',
        'ERROR',
        'SYNC',
        'NETWORK',
        'PRINTER',
        'DATABASE',
        'SECURITY',
        'DISCOVERY',
        'PAIRING',
      ],
    );
  });

  test('tags map onto domain channels', () {
    expect(LogType.fromTag('auth'), LogType.security);
    expect(LogType.fromTag('pairing'), LogType.pairing);
    expect(LogType.fromTag('mdns'), LogType.discovery);
    expect(LogType.fromTag('sqlite'), LogType.database);
    expect(LogType.fromTag('print'), LogType.printer);
    expect(LogType.fromTag('sync'), LogType.sync);
    expect(LogType.fromTag('network'), LogType.network);
    expect(LogType.fromTag('di'), LogType.info);
  });

  test('log lines carry channel and severity', () {
    final entry = LogEntry(
      id: '1',
      type: LogType.pairing,
      severity: 'info',
      message: 'Paired with master',
      tag: 'pairing',
      createdAt: DateTime.utc(2026, 10, 7, 12),
    );

    expect(entry.toLine(), contains('[PAIRING/INFO]'));
    expect(entry.toJson()['type'], 'PAIRING');
    expect(entry.toJson()['message'], 'Paired with master');
  });
}
