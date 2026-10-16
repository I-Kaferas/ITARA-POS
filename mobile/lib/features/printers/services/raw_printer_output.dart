import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'escpos_raster.dart';

class BluetoothPrinterDevice {
  const BluetoothPrinterDevice({required this.name, required this.address});

  final String name;
  final String address;
}

/// Where raw printer bytes go: a TCP socket (JetDirect / port 9100) or a
/// Bluetooth serial link.
class RawPrinterTarget {
  const RawPrinterTarget.network(this.host, {this.port = 9100})
      : bluetoothAddress = '';

  const RawPrinterTarget.bluetooth(this.bluetoothAddress)
      : host = '',
        port = 0;

  final String host;
  final int port;
  final String bluetoothAddress;

  bool get isBluetooth => bluetoothAddress.isNotEmpty;

  String get label => isBluetooth ? bluetoothAddress : '$host:$port';
}

/// Direct printing without OS drivers: ESC/POS over the network or Bluetooth.
class RawPrinterOutput {
  RawPrinterOutput._();

  static final RawPrinterOutput instance = RawPrinterOutput._();

  static const networkTimeout = Duration(seconds: 5);
  static const bluetoothTimeout = Duration(seconds: 20);

  Future<void> _bluetoothQueue = Future.value();
  String _bluetoothConnected = '';

  static String normalizeMac(String raw) =>
      raw.trim().replaceAll('-', ':').toUpperCase();

  static bool isValidMac(String raw) =>
      RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(normalizeMac(raw));

  /// Thermal formats are rasterized to ESC/POS. A4 on a network printer is
  /// sent as raw PDF, which office printers accept on port 9100.
  Future<void> printPdf(
    Uint8List pdf,
    RawPrinterTarget target, {
    required int paperWidthMm,
    bool openDrawer = false,
  }) async {
    if (paperWidthMm > 80 && !target.isBluetooth) {
      await send(target, pdf);
      return;
    }
    final bytes = await EscPosRaster.fromPdf(
      pdf,
      paperWidthMm: math.min(paperWidthMm, 80),
      openDrawer: openDrawer,
    );
    await send(target, bytes);
  }

  Future<void> send(RawPrinterTarget target, List<int> bytes) {
    if (target.isBluetooth) {
      final run = _bluetoothQueue.then(
        (_) => _writeBluetooth(normalizeMac(target.bluetoothAddress), bytes),
      );
      _bluetoothQueue = run.catchError((_) {});
      return run;
    }
    return _writeNetwork(target.host.trim(), target.port, bytes);
  }

  Future<int> probeNetwork(String host, int port) async {
    final watch = Stopwatch()..start();
    final socket = await Socket.connect(host.trim(), port, timeout: networkTimeout);
    socket.destroy();
    return watch.elapsedMilliseconds;
  }

  /// Opens (or reuses) the Bluetooth link without printing anything.
  Future<void> probeBluetooth(String address) {
    final run = _bluetoothQueue.then((_) => _connectBluetooth(normalizeMac(address)));
    _bluetoothQueue = run.catchError((_) {});
    return run;
  }

  bool get bluetoothSupported =>
      Platform.isAndroid || Platform.isWindows || Platform.isIOS || Platform.isMacOS;

  /// Human-readable reason Bluetooth cannot be used right now, or null.
  Future<String?> bluetoothProblem() async {
    if (!bluetoothSupported) {
      return 'Le Bluetooth n’est pas pris en charge sur cette plateforme.';
    }
    if (Platform.isWindows) return null;
    try {
      if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
        return 'Autorisez « Appareils à proximité » pour ITARA POS dans les paramètres.';
      }
      if (!await PrintBluetoothThermal.bluetoothEnabled) {
        return 'Activez le Bluetooth de cet appareil.';
      }
    } catch (error) {
      return 'Bluetooth indisponible : $error';
    }
    return null;
  }

  /// Android lists paired devices; Windows runs a short BLE scan (≈5 s).
  Future<List<BluetoothPrinterDevice>> bluetoothDevices() async {
    final problem = await bluetoothProblem();
    if (problem != null) throw StateError(problem);
    final found = await PrintBluetoothThermal.pairedBluetooths;
    final seen = <String>{};
    return [
      for (final item in found)
        if (seen.add(normalizeMac(item.macAdress)))
          BluetoothPrinterDevice(
            name: item.name.trim().isEmpty ? item.macAdress : item.name.trim(),
            address: normalizeMac(item.macAdress),
          ),
    ];
  }

  Future<void> _writeNetwork(String host, int port, List<int> bytes) async {
    if (host.isEmpty) throw StateError('Adresse IP de l’imprimante manquante');
    final socket = await Socket.connect(host, port, timeout: networkTimeout);
    try {
      socket.add(bytes);
      await socket.flush();
    } finally {
      await socket.close();
      socket.destroy();
    }
  }

  Future<void> _connectBluetooth(String address) async {
    if (!isValidMac(address)) {
      throw StateError('Adresse Bluetooth invalide : $address');
    }
    final problem = await bluetoothProblem();
    if (problem != null) throw StateError(problem);
    if (_bluetoothConnected == address &&
        await PrintBluetoothThermal.connectionStatus) {
      return;
    }
    if (_bluetoothConnected.isNotEmpty ||
        await PrintBluetoothThermal.connectionStatus) {
      await PrintBluetoothThermal.disconnect;
    }
    _bluetoothConnected = '';
    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: address)
        .timeout(bluetoothTimeout, onTimeout: () => false);
    if (!ok) {
      throw StateError(
        'Connexion impossible à $address. Vérifiez que l’imprimante est allumée, appairée et libre.',
      );
    }
    _bluetoothConnected = address;
  }

  Future<void> _writeBluetooth(String address, List<int> bytes) async {
    await _connectBluetooth(address);
    // Windows writes BLE packets; serial printers also drop data when flooded.
    final chunk = Platform.isWindows ? 180 : 1024;
    for (var start = 0; start < bytes.length; start += chunk) {
      final end = math.min(start + chunk, bytes.length);
      final ok = await PrintBluetoothThermal.writeBytes(bytes.sublist(start, end));
      if (!ok) {
        _bluetoothConnected = '';
        await PrintBluetoothThermal.disconnect;
        throw StateError('Envoi Bluetooth interrompu vers $address');
      }
      if (!Platform.isWindows) {
        await Future<void>.delayed(const Duration(milliseconds: 12));
      }
    }
  }
}
