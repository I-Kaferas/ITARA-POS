import 'package:uuid/uuid.dart';

import 'print_group.dart';
import 'printer_connection_type.dart';

class Printer {
  const Printer({
    required this.id,
    required this.name,
    required this.group,
    this.host = '',
    this.port = 9100,
    this.model = 'generic_80',
    this.connection = PrinterConnectionType.lan,
    this.format = 'thermal_80',
    this.paperWidthMm = 80,
    this.usbPath = '',
    this.bluetoothAddress = '',
    this.systemName = '',
    this.enabled = true,
    this.priority = 100,
    this.online = true,
    this.lastError = '',
    this.updatedAt,
  });

  final String id;
  final String name;
  final PrintGroup group;
  final String host;
  final int port;
  final String model;
  final PrinterConnectionType connection;
  final String format;
  final int paperWidthMm;
  final String usbPath;
  final String bluetoothAddress;
  final String systemName;
  final bool enabled;
  /// Lower runs first within a group (failover order).
  final int priority;
  final bool online;
  final String lastError;
  final DateTime? updatedAt;

  factory Printer.fromJson(Map<String, dynamic> json) {
    final connection = PrinterConnectionType.fromString(
      json['connection']?.toString(),
    );
    final format = json['format']?.toString() ?? 'thermal_80';
    final paperWidth = (json['paper_width_mm'] as num?)?.toInt() ??
        (format.contains('58') ? 58 : format.contains('a4') ? 210 : 80);

    return Printer(
      id: json['id']?.toString() ?? const Uuid().v4(),
      name: json['name']?.toString() ?? 'Imprimante',
      group: PrintGroup.fromString(json['group']?.toString() ?? json['print_group']?.toString()),
      host: json['host']?.toString() ?? '',
      port: (json['port'] as num?)?.toInt() ?? 9100,
      model: json['model']?.toString() ?? 'generic_80',
      connection: connection,
      format: format,
      paperWidthMm: paperWidth,
      usbPath: json['usb_path']?.toString() ?? '',
      bluetoothAddress: json['bluetooth_address']?.toString() ?? '',
      systemName: json['system_name']?.toString() ?? json['name']?.toString() ?? '',
      enabled: json['enabled'] != false && json['enabled'] != 0,
      priority: (json['priority'] as num?)?.toInt() ?? 100,
      online: json['online'] != false && json['online'] != 0,
      lastError: json['last_error']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  factory Printer.fromRow(Map<String, Object?> row) {
    return Printer.fromJson({
      'id': row['id'],
      'name': row['name'],
      'print_group': row['print_group'],
      'host': row['host'],
      'port': row['port'],
      'model': row['model'],
      'connection': row['connection'],
      'format': row['format'],
      'paper_width_mm': row['paper_width_mm'],
      'usb_path': row['usb_path'],
      'bluetooth_address': row['bluetooth_address'],
      'system_name': row['system_name'],
      'enabled': row['enabled'],
      'priority': row['priority'],
      'online': row['online'],
      'last_error': row['last_error'],
      'updated_at': row['updated_at'],
    });
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'group': group.name,
        'print_group': group.name,
        'host': host,
        'port': port,
        'model': model,
        'connection': connection.name,
        'format': format,
        'paper_width_mm': paperWidthMm,
        'usb_path': usbPath,
        'bluetooth_address': bluetoothAddress,
        'system_name': systemName,
        'enabled': enabled,
        'priority': priority,
        'online': online,
        'last_error': lastError,
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'print_group': group.name,
        'host': host,
        'port': port,
        'model': model,
        'connection': connection.name,
        'format': format,
        'paper_width_mm': paperWidthMm,
        'usb_path': usbPath,
        'bluetooth_address': bluetoothAddress,
        'system_name': systemName,
        'enabled': enabled ? 1 : 0,
        'priority': priority,
        'online': online ? 1 : 0,
        'last_error': lastError,
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  bool get isReady => enabled && online;

  bool get hasEndpoint => switch (connection) {
        PrinterConnectionType.lan ||
        PrinterConnectionType.ethernet ||
        PrinterConnectionType.wifi =>
          host.isNotEmpty,
        PrinterConnectionType.usb => usbPath.isNotEmpty || systemName.isNotEmpty,
        PrinterConnectionType.bluetooth => bluetoothAddress.isNotEmpty,
        PrinterConnectionType.system => systemName.isNotEmpty || name.isNotEmpty,
      };

  Printer copyWith({
    String? id,
    String? name,
    PrintGroup? group,
    String? host,
    int? port,
    String? model,
    PrinterConnectionType? connection,
    String? format,
    int? paperWidthMm,
    String? usbPath,
    String? bluetoothAddress,
    String? systemName,
    bool? enabled,
    int? priority,
    bool? online,
    String? lastError,
    DateTime? updatedAt,
  }) {
    return Printer(
      id: id ?? this.id,
      name: name ?? this.name,
      group: group ?? this.group,
      host: host ?? this.host,
      port: port ?? this.port,
      model: model ?? this.model,
      connection: connection ?? this.connection,
      format: format ?? this.format,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      usbPath: usbPath ?? this.usbPath,
      bluetoothAddress: bluetoothAddress ?? this.bluetoothAddress,
      systemName: systemName ?? this.systemName,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      online: online ?? this.online,
      lastError: lastError ?? this.lastError,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
