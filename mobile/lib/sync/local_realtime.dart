import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/config/terminal_config_repository.dart';
import 'device_registry.dart';
import 'local_master_server.dart';

/// Local Master ↔ Slave realtime events (no cloud dependency).
enum RealtimeEventType {
  newSale,
  saleUpdated,
  paymentReceived,
  stockUpdated,
  tableUpdated,
  orderCreated,
  orderUpdated,
  kitchenOrderCreated,
  kitchenOrderReady,
  notificationCreated,
  deviceConnected,
  deviceDisconnected,
  configUpdated,
  printJobQueued,
  printJobDone,
  deviceCommand,
  heartbeat,
  unknown;

  static RealtimeEventType fromWire(String? value) {
    final key = (value ?? '').trim();
    return RealtimeEventType.values.firstWhere(
      (item) => item.wire == key,
      orElse: () => RealtimeEventType.unknown,
    );
  }

  String get wire => switch (this) {
        RealtimeEventType.newSale => 'NewSale',
        RealtimeEventType.saleUpdated => 'SaleUpdated',
        RealtimeEventType.paymentReceived => 'PaymentReceived',
        RealtimeEventType.stockUpdated => 'StockUpdated',
        RealtimeEventType.tableUpdated => 'TableUpdated',
        RealtimeEventType.orderCreated => 'OrderCreated',
        RealtimeEventType.orderUpdated => 'OrderUpdated',
        RealtimeEventType.kitchenOrderCreated => 'KitchenOrderCreated',
        RealtimeEventType.kitchenOrderReady => 'KitchenOrderReady',
        RealtimeEventType.notificationCreated => 'NotificationCreated',
        RealtimeEventType.deviceConnected => 'DeviceConnected',
        RealtimeEventType.deviceDisconnected => 'DeviceDisconnected',
        RealtimeEventType.configUpdated => 'ConfigUpdated',
        RealtimeEventType.printJobQueued => 'PrintJobQueued',
        RealtimeEventType.printJobDone => 'PrintJobDone',
        RealtimeEventType.deviceCommand => 'DeviceCommand',
        RealtimeEventType.heartbeat => 'Heartbeat',
        RealtimeEventType.unknown => 'Unknown',
      };
}

class RealtimeEvent {
  RealtimeEvent({
    required this.type,
    this.payload = const {},
    this.originDeviceId = '',
    DateTime? occurredAt,
  }) : occurredAt = occurredAt ?? DateTime.now();

  final RealtimeEventType type;
  final Map<String, dynamic> payload;
  final String originDeviceId;
  final DateTime occurredAt;

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    return RealtimeEvent(
      type: RealtimeEventType.fromWire(json['type']?.toString()),
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
      originDeviceId: json['origin_device_id']?.toString() ?? '',
      occurredAt: DateTime.tryParse(json['occurred_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.wire,
        'payload': payload,
        'origin_device_id': originDeviceId,
        'occurred_at': occurredAt.toIso8601String(),
      };

  String encode() => jsonEncode(toJson());
}

/// Master-side WebSocket hub on `/api/v1/realtime`.
class LocalRealtimeHub extends ChangeNotifier {
  LocalRealtimeHub._();

  static final LocalRealtimeHub instance = LocalRealtimeHub._();

  final _sockets = <WebSocket>{};
  final _deviceBySocket = <WebSocket, String>{};
  final _controller = StreamController<RealtimeEvent>.broadcast();
  Timer? _ping;

  Stream<RealtimeEvent> get events => _controller.stream;
  int get clientCount => _sockets.length;

  void start() {
    _ping?.cancel();
    _ping = Timer.periodic(const Duration(seconds: 20), (_) {
      publish(RealtimeEvent(type: RealtimeEventType.heartbeat));
    });
  }

  void stop() {
    _ping?.cancel();
    _ping = null;
    for (final socket in List<WebSocket>.from(_sockets)) {
      try {
        socket.close();
      } catch (_) {}
    }
    _sockets.clear();
    _deviceBySocket.clear();
    notifyListeners();
  }

  Future<bool> accept(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) return false;
    final token = request.headers.value('x-pair-token')?.trim() ??
        request.uri.queryParameters['pair_token']?.trim() ??
        '';
    final deviceId = request.headers.value('x-device-id')?.trim() ??
        request.uri.queryParameters['device_id']?.trim() ??
        '';

    if (token.isNotEmpty) {
      final device = await DeviceRegistry.instance.findByToken(token);
      if (device == null || device.status == LanDeviceStatus.blocked) {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        return true;
      }
    }

    final socket = await WebSocketTransformer.upgrade(request);
    _sockets.add(socket);
    if (deviceId.isNotEmpty) {
      _deviceBySocket[socket] = deviceId;
      publish(RealtimeEvent(
        type: RealtimeEventType.deviceConnected,
        originDeviceId: deviceId,
        payload: {'device_id': deviceId},
      ));
    }
    notifyListeners();

    socket.listen(
      (message) {
        if (message is! String) return;
        try {
          final decoded = jsonDecode(message);
          if (decoded is! Map) return;
          final event = RealtimeEvent.fromJson(Map<String, dynamic>.from(decoded));
          if (event.type == RealtimeEventType.unknown) return;
          if (event.type == RealtimeEventType.heartbeat) return;
          publish(event, exclude: socket);
        } catch (_) {}
      },
      onDone: () => _drop(socket),
      onError: (_) => _drop(socket),
      cancelOnError: true,
    );
    return true;
  }

  void publish(RealtimeEvent event, {WebSocket? exclude}) {
    _controller.add(event);
    final wire = event.encode();
    for (final socket in List<WebSocket>.from(_sockets)) {
      if (identical(socket, exclude)) continue;
      try {
        socket.add(wire);
      } catch (_) {
        _drop(socket);
      }
    }
  }

  /// Push an event only to the sockets bound to [deviceId] (Master §45).
  int publishToDevice(String deviceId, RealtimeEvent event) {
    if (deviceId.isEmpty) return 0;
    _controller.add(event);
    final wire = event.encode();
    var sent = 0;
    for (final entry in Map<WebSocket, String>.from(_deviceBySocket).entries) {
      if (entry.value != deviceId) continue;
      try {
        entry.key.add(wire);
        sent++;
      } catch (_) {
        _drop(entry.key);
      }
    }
    return sent;
  }

  bool isDeviceConnected(String deviceId) =>
      deviceId.isNotEmpty && _deviceBySocket.containsValue(deviceId);

  void _drop(WebSocket socket) {
    if (!_sockets.remove(socket)) return;
    final deviceId = _deviceBySocket.remove(socket) ?? '';
    try {
      socket.close();
    } catch (_) {}
    if (deviceId.isNotEmpty) {
      publish(RealtimeEvent(
        type: RealtimeEventType.deviceDisconnected,
        originDeviceId: deviceId,
        payload: {'device_id': deviceId},
      ));
    }
    notifyListeners();
  }
}

/// Slave-side WebSocket client to the Master hub.
class LocalRealtimeClient extends ChangeNotifier {
  LocalRealtimeClient._();

  static final LocalRealtimeClient instance = LocalRealtimeClient._();

  WebSocket? _socket;
  Timer? _reconnect;
  StreamSubscription? _sub;
  final _controller = StreamController<RealtimeEvent>.broadcast();
  bool connected = false;
  String? lastError;
  DateTime? lastEventAt;

  Stream<RealtimeEvent> get events => _controller.stream;

  Future<void> startIfSlave() async {
    final config = TerminalConfigRepository.instance.config;
    if (!config.isSlave || config.masterHost.trim().isEmpty) {
      await stop();
      return;
    }
    await _connect();
  }

  Future<void> stop() async {
    _reconnect?.cancel();
    _reconnect = null;
    await _sub?.cancel();
    _sub = null;
    final socket = _socket;
    _socket = null;
    connected = false;
    if (socket != null) {
      try {
        await socket.close();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _connect() async {
    _reconnect?.cancel();
    _reconnect = null;
    await _sub?.cancel();
    _sub = null;
    final previous = _socket;
    _socket = null;
    if (previous != null) {
      try {
        await previous.close();
      } catch (_) {}
    }

    final config = TerminalConfigRepository.instance.config;
    if (!config.isSlave) return;

    final base = LocalMasterServer.clientBaseUrl();
    if (base == null || base.isEmpty) {
      lastError = 'Master host manquant';
      connected = false;
      _scheduleReconnect();
      notifyListeners();
      return;
    }

    final uri = Uri.parse(base.replaceFirst(RegExp(r'^http'), 'ws'));
    final wsUri = uri.replace(
      path: '${uri.path.replaceAll(RegExp(r'/+$'), '')}/realtime',
      queryParameters: {
        if (config.masterPairToken.isNotEmpty) 'pair_token': config.masterPairToken,
        if (config.deviceId.isNotEmpty) 'device_id': config.deviceId,
      },
    );

    try {
      final socket = await WebSocket.connect(
        wsUri.toString(),
        headers: {
          if (config.masterPairToken.isNotEmpty) 'X-Pair-Token': config.masterPairToken,
          if (config.deviceId.isNotEmpty) 'X-Device-ID': config.deviceId,
          if (config.tenantId.isNotEmpty) 'X-Tenant-ID': config.tenantId,
          if (config.storeId.isNotEmpty) 'X-Store-ID': config.storeId,
        },
      ).timeout(const Duration(seconds: 8));
      _socket = socket;
      connected = true;
      lastError = null;
      notifyListeners();
      _sub = socket.listen(
        (message) {
          if (message is! String) return;
          try {
            final decoded = jsonDecode(message);
            if (decoded is! Map) return;
            final event = RealtimeEvent.fromJson(Map<String, dynamic>.from(decoded));
            lastEventAt = DateTime.now();
            _controller.add(event);
            notifyListeners();
          } catch (_) {}
        },
        onDone: () {
          connected = false;
          notifyListeners();
          _scheduleReconnect();
        },
        onError: (Object error) {
          lastError = error.toString();
          connected = false;
          notifyListeners();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (error) {
      lastError = error.toString();
      connected = false;
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnect?.cancel();
    final config = TerminalConfigRepository.instance.config;
    if (!config.isSlave) return;
    _reconnect = Timer(const Duration(seconds: 4), () => unawaited(_connect()));
  }

  void publishLocally(RealtimeEvent event) {
    _controller.add(event);
  }
}
