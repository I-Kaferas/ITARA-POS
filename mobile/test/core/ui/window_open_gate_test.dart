import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/core/ui/window_open_gate.dart';

void main() {
  test('clicks queued by a freeze share one window open', () async {
    final windows = <String>[];
    var creates = 0;
    final gate = WindowOpenGate();

    Future<void> open() {
      return gate.run(() => openSingleWindow(
            isOpen: () async => windows.isNotEmpty,
            focus: () async {},
            create: () async {
              creates++;
              await Future<void>.delayed(const Duration(milliseconds: 30));
              windows.add('customer');
            },
          ));
    }

    await Future.wait([for (var i = 0; i < 8; i++) open()]);

    expect(creates, 1);
    expect(windows, ['customer']);
    expect(gate.busy.value, isFalse);
  });

  test('an existing window is focused and not created again', () async {
    var creates = 0;
    var focuses = 0;
    final gate = WindowOpenGate();

    Future<void> open() {
      return gate.run(() => openSingleWindow(
            isOpen: () async => true,
            focus: () async {
              focuses++;
            },
            create: () async {
              creates++;
            },
          ));
    }

    await Future.wait([open(), open(), open()]);
    await open();

    expect(creates, 0);
    expect(focuses, 2);
    expect(gate.busy.value, isFalse);
  });

  test('a failed focus does not open a second copy', () async {
    var creates = 0;
    await openSingleWindow(
      isOpen: () async => true,
      focus: () async {
        throw StateError('window thread is frozen');
      },
      create: () async {
        creates++;
      },
    );
    expect(creates, 0);
  });

  test('a create that dies after the window exists reuses that window', () async {
    var visible = false;
    var creates = 0;
    var focuses = 0;
    await openSingleWindow(
      isOpen: () async => visible,
      focus: () async {
        focuses++;
      },
      create: () async {
        creates++;
        visible = true;
        throw StateError('engine died after the window existed');
      },
    );
    expect(creates, 1);
    expect(focuses, 1);
    expect(visible, isTrue);
  });

  test('an error resets the button so the next click can open', () async {
    var calls = 0;
    final gate = WindowOpenGate();
    await gate.run(() async {
      calls++;
      throw StateError('frozen');
    });
    expect(gate.busy.value, isFalse);

    await gate.run(() async {
      calls++;
    });
    expect(calls, 2);
    expect(gate.busy.value, isFalse);
  });

  test('a new gate after a crash is not stuck and still opens once', () async {
    final hung = Completer<void>();
    final crashed = WindowOpenGate();
    final pending = crashed.run(() => hung.future);
    expect(crashed.busy.value, isTrue);

    final windows = <String>[];
    var creates = 0;
    final restarted = WindowOpenGate();
    await Future.wait([
      for (var i = 0; i < 5; i++)
        restarted.run(() => openSingleWindow(
              isOpen: () async => windows.isNotEmpty,
              focus: () async {},
              create: () async {
                creates++;
                windows.add('customer');
              },
            )),
    ]);

    expect(creates, 1);
    expect(restarted.busy.value, isFalse);
    expect(crashed.busy.value, isTrue);

    hung.complete();
    await pending;
    expect(crashed.busy.value, isFalse);
  });
}
