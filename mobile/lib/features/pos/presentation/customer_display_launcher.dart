import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'package:pos_mobile/core/i18n/app_locale.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_colors.dart';
import 'package:pos_mobile/core/theme/theme_controller.dart';
import 'package:pos_mobile/core/ui/window_open_gate.dart';

import '../services/customer_display_bus.dart';
import 'customer_display_view.dart';

const customerDisplayChannelName = 'itara.customer_display';

const _channel = WindowMethodChannel(
  customerDisplayChannelName,
  mode: ChannelMode.unidirectional,
);

/// Opens the customer-facing order screen.
///
/// On a desktop POS with a second monitor the screen is a real window on that
/// display and stays in sync with the cashier cart. On a single screen it
/// opens as a full-screen preview.
class CustomerDisplayLauncher {
  CustomerDisplayLauncher._();

  static final WindowOpenGate _gate = WindowOpenGate();

  /// True while a click is opening or focusing the customer window.
  static ValueNotifier<bool> get busy => _gate.busy;

  static bool _listening = false;
  static bool _windowOpen = false;
  static bool _pushing = false;
  static bool _dirty = false;
  static bool _previewRoute = false;
  static String? _windowId;
  static BuildContext? _context;

  static Future<void> open(BuildContext context) {
    _ensureListening();
    _context = context;
    return _gate.run(() async {
      try {
        await _openOnce();
      } catch (_) {
        final still = await _findExisting();
        if (still == null) _clearWindow();
      }
    });
  }

  static Future<void> _openOnce() async {
    if (!_isDesktop) {
      await _openRoute();
      return;
    }
    WindowController? found;
    await openSingleWindow(
      isOpen: () async {
        found = await _findExisting();
        return found != null;
      },
      focus: () async {
        final window = found;
        if (window == null || !await _focus(window)) {
          throw StateError('Customer display window is gone');
        }
        await _push();
      },
      create: _createWindow,
    );
  }

  static Future<void> _openRoute() async {
    if (_previewRoute) return;
    final context = _context;
    if (context == null || !context.mounted) return;
    _previewRoute = true;
    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const CustomerDisplayPage(),
        ),
      );
    } finally {
      _previewRoute = false;
    }
  }

  static Future<void> _createWindow() async {
    final frame = await _targetFrame();
    final payload = jsonEncode({
      'kind': 'customer_display',
      'cart': _cart(),
      'frame': frame,
    });
    final created = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: payload,
      ),
    );
    if (created.windowId.isEmpty) {
      throw StateError('Customer display window was not created');
    }
    _windowId = created.windowId;
    _windowOpen = true;
    _linked = false;
    await _pushUntilReady();
  }

  static void _clearWindow() {
    _windowOpen = false;
    _windowId = null;
    _linked = false;
  }

  static Map<String, dynamic> _cart() => {
        ...CustomerDisplayBus.instance.snapshot.toJson(),
        'locale': LocaleController.instance.code,
        'dark': ThemeController.instance.isDark,
      };

  static void _ensureListening() {
    if (_listening) return;
    _listening = true;
    void push() {
      if (_windowOpen) _push();
    }

    CustomerDisplayBus.instance.addListener(push);
    LocaleController.instance.addListener(push);
    ThemeController.instance.addListener(push);
  }

  static bool _linked = false;

  static Future<void> _pushUntilReady() async {
    for (var attempt = 0; attempt < 12; attempt++) {
      try {
        await _channel.invokeMethod<void>('cart', _cart());
        _linked = true;
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  static Future<void> _push() async {
    if (!_windowOpen) return;
    if (_pushing) {
      _dirty = true;
      return;
    }
    _pushing = true;
    try {
      await _channel.invokeMethod<void>('cart', _cart());
      _linked = true;
    } catch (_) {
      if (!_linked) return;
      final still = await _findExisting();
      if (still == null) {
        _windowOpen = false;
        _linked = false;
      }
    } finally {
      _pushing = false;
      if (_dirty && _windowOpen) {
        _dirty = false;
        await _push();
      } else {
        _dirty = false;
      }
    }
  }

  static Future<bool> _focus(WindowController window) async {
    try {
      await window.show();
      try {
        await window.invokeMethod<void>('focus');
      } catch (_) {}
      _windowId = window.windowId;
      _windowOpen = true;
      _linked = true;
      return true;
    } catch (_) {
      if (_windowId == window.windowId) _clearWindow();
      return false;
    }
  }

  static Future<WindowController?> _findExisting() async {
    try {
      final windows = await WindowController.getAll();
      final matches = <WindowController>[
        for (final window in windows)
          if (window.arguments.contains('"kind":"customer_display"')) window,
      ];
      if (matches.isEmpty) {
        _clearWindow();
        return null;
      }
      var primary = matches.first;
      if (_windowId != null) {
        for (final window in matches) {
          if (window.windowId == _windowId) {
            primary = window;
            break;
          }
        }
      }
      for (final extra in matches) {
        if (extra.windowId == primary.windowId) continue;
        try {
          await extra.hide();
        } catch (_) {}
      }
      _windowId = primary.windowId;
      _windowOpen = true;
      return primary;
    } catch (_) {
      if (_windowId != null && _windowId!.isNotEmpty) {
        return WindowController.fromWindowId(_windowId!);
      }
      return null;
    }
  }

  static Future<Map<String, dynamic>> _targetFrame() async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      final primary = await screenRetriever.getPrimaryDisplay();
      Display? customer;
      for (final display in displays) {
        if (display.id != primary.id) {
          customer = display;
          break;
        }
      }
      if (customer != null) {
        final origin = customer.visiblePosition ?? Offset.zero;
        final size = customer.visibleSize ?? customer.size;
        return {
          'x': origin.dx,
          'y': origin.dy,
          'w': size.width,
          'h': size.height,
          'fill': true,
        };
      }
    } catch (_) {}
    return {'x': 80.0, 'y': 80.0, 'w': 1180.0, 'h': 760.0, 'fill': false};
  }

  static bool get _isDesktop {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }
}

/// Entry point for the second window. [initialJson] is the window argument.
class CustomerDisplayApp extends StatefulWidget {
  const CustomerDisplayApp({super.key, required this.initialJson});

  final String initialJson;

  @override
  State<CustomerDisplayApp> createState() => _CustomerDisplayAppState();
}

class _CustomerDisplayAppState extends State<CustomerDisplayApp> {
  late CustomerDisplaySnapshot _snapshot;
  Map<String, dynamic> _frame = const {'fill': false, 'w': 1180, 'h': 760};

  @override
  void initState() {
    super.initState();
    final decoded = _decode(widget.initialJson);
    final cart = decoded['cart'];
    _snapshot = cart is Map
        ? CustomerDisplaySnapshot.fromJson(cart.map((key, value) => MapEntry(key.toString(), value)))
        : CustomerDisplaySnapshot.fromMessage(widget.initialJson);
    final frame = decoded['frame'];
    if (frame is Map) {
      _frame = frame.map((key, value) => MapEntry(key.toString(), value));
    }
    _applyLocale();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _placeWindow();
      _listen();
    });
  }

  void _applyLocale() {
    if (_snapshot.locale.isNotEmpty) LocaleController.instance.bind(_snapshot.locale);
    AppColors.bind(_snapshot.dark ? AppPalette.dark : AppPalette.light);
  }

  Map<String, dynamic> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    return const {};
  }

  Future<void> _listen() async {
    try {
      await _channel.setMethodCallHandler((call) async {
        if (call.method == 'cart' && mounted) {
          setState(() {
            _snapshot = CustomerDisplaySnapshot.fromMessage(call.arguments);
            _applyLocale();
          });
        }
        return null;
      });
      final current = await WindowController.fromCurrentEngine();
      await current.setWindowMethodHandler((MethodCall call) async {
        if (call.method == 'focus') {
          await windowManager.show();
          await windowManager.focus();
        }
        return null;
      });
    } catch (_) {}
  }

  Future<void> _placeWindow() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        await windowManager.ensureInitialized();
        final fill = _frame['fill'] == true;
        final width = (_frame['w'] as num?)?.toDouble() ?? 1180;
        final height = (_frame['h'] as num?)?.toDouble() ?? 760;
        final x = (_frame['x'] as num?)?.toDouble() ?? 80;
        final y = (_frame['y'] as num?)?.toDouble() ?? 80;
        final title = '${_snapshot.brandName} — Customer Display';
        windowManager.waitUntilReadyToShow(
          WindowOptions(
            size: Size(width, height),
            center: !fill,
            title: title,
            backgroundColor: const Color(0xFFF3F5F9),
          ),
          () async {
            if (fill) {
              await windowManager.setBounds(Rect.fromLTWH(x, y, width, height));
            }
            await windowManager.setTitle(title);
            await windowManager.show();
            await windowManager.focus();
          },
        );
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: trf('{0} — Customer Display', [_snapshot.brandName]),
      home: CustomerDisplayView(snapshot: _snapshot),
    );
  }
}
