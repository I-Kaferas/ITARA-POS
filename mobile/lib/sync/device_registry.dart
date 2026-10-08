import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data/local/local_database.dart';

enum LanDeviceStatus {
  online,
  idle,
  offline,
  syncing,
  error,
  blocked,
  pending;

  static LanDeviceStatus fromString(String value) {
    return LanDeviceStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => LanDeviceStatus.offline,
    );
  }
}

class LanDevice {
  const LanDevice({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.os,
    required this.ip,
    required this.tenantId,
    required this.branchId,
    required this.storeId,
    required this.userId,
    required this.userName,
    required this.role,
    required this.version,
    required this.status,
    required this.lastSeen,
    required this.pairedAt,
    required this.approved,
    this.pairTokenHash = '',
    this.pending = 0,
  });

  final String id;
  final String name;
  final String deviceType;
  final String os;
  final String ip;
  final String tenantId;
  /// Shop / branch scope (§9). Mirrors [storeId] when the LAN uses store as branch.
  final String branchId;
  final String storeId;
  final String userId;
  final String userName;
  final String role;
  final String version;
  final LanDeviceStatus status;
  final DateTime lastSeen;
  final DateTime? pairedAt;
  final bool approved;
  final String pairTokenHash;
  final int pending;

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_id': id,
        'name': name,
        'device_type': deviceType,
        'type': deviceType,
        'os': os,
        'ip': ip,
        'tenant_id': tenantId,
        'tenant': tenantId,
        'branch_id': branchId.isNotEmpty ? branchId : storeId,
        'branch': branchId.isNotEmpty ? branchId : storeId,
        'store_id': storeId,
        'user_id': userId,
        'user': userName.isNotEmpty
            ? {'id': userId, 'name': userName}
            : (userId.isEmpty ? null : {'id': userId, 'name': userId}),
        'user_name': userName,
        'role': role,
        'version': version,
        'status': status.name,
        'last_seen': lastSeen.toIso8601String(),
        'paired_at': pairedAt?.toIso8601String(),
        'approved': approved,
        'pending': pending,
      };

  factory LanDevice.fromRow(Map<String, dynamic> row) {
    final storeId = row['store_id']?.toString() ?? '';
    final branchId = row['branch_id']?.toString() ?? '';
    return LanDevice(
      id: row['device_id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      deviceType: row['device_type']?.toString() ?? 'pos',
      os: row['os']?.toString() ?? '',
      ip: row['ip']?.toString() ?? '',
      tenantId: row['tenant_id']?.toString() ?? '',
      branchId: branchId.isNotEmpty ? branchId : storeId,
      storeId: storeId,
      userId: row['user_id']?.toString() ?? '',
      userName: row['user_name']?.toString() ?? '',
      role: row['role']?.toString() ?? 'slave',
      version: row['version']?.toString() ?? '',
      status: LanDeviceStatus.fromString(row['status']?.toString() ?? 'offline'),
      lastSeen: DateTime.tryParse(row['last_seen']?.toString() ?? '') ?? DateTime.now(),
      pairedAt: DateTime.tryParse(row['paired_at']?.toString() ?? ''),
      approved: (row['approved'] as int? ?? 0) == 1,
      pairTokenHash: row['pair_token_hash']?.toString() ?? '',
      pending: (row['pending'] as int?) ?? 0,
    );
  }

  LanDevice copyWith({
    String? id,
    String? name,
    String? deviceType,
    String? os,
    String? ip,
    String? tenantId,
    String? branchId,
    String? storeId,
    String? userId,
    String? userName,
    String? role,
    String? version,
    LanDeviceStatus? status,
    DateTime? lastSeen,
    DateTime? pairedAt,
    bool? approved,
    String? pairTokenHash,
    int? pending,
  }) {
    return LanDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      os: os ?? this.os,
      ip: ip ?? this.ip,
      tenantId: tenantId ?? this.tenantId,
      branchId: branchId ?? this.branchId,
      storeId: storeId ?? this.storeId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      role: role ?? this.role,
      version: version ?? this.version,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      pairedAt: pairedAt ?? this.pairedAt,
      approved: approved ?? this.approved,
      pairTokenHash: pairTokenHash ?? this.pairTokenHash,
      pending: pending ?? this.pending,
    );
  }
}

/// Durable LAN device registry stored in SQLite (Master) — mobile.md §9.
class DeviceRegistry {
  DeviceRegistry._();

  static final DeviceRegistry instance = DeviceRegistry._();

  Future<Database> get _db => LocalDatabase.instance.database;

  static String hashToken(String token) =>
      sha256.convert(utf8.encode('itara-pair|$token')).toString();

  Future<List<LanDevice>> list({bool includePending = true}) async {
    final db = await _db;
    final rows = await db.query(
      'lan_devices',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map(LanDevice.fromRow)
        .where((d) => includePending || d.approved)
        .toList();
  }

  Future<LanDevice?> find(String deviceId) async {
    if (deviceId.isEmpty) return null;
    final db = await _db;
    final rows = await db.query(
      'lan_devices',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LanDevice.fromRow(rows.first);
  }

  Future<LanDevice?> findByToken(String token) async {
    if (token.isEmpty) return null;
    final hash = hashToken(token);
    final db = await _db;
    final rows = await db.query(
      'lan_devices',
      where: 'pair_token_hash = ? AND approved = 1',
      whereArgs: [hash],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LanDevice.fromRow(rows.first);
  }

  Future<void> upsert(LanDevice device) async {
    final db = await _db;
    final branch = device.branchId.isNotEmpty ? device.branchId : device.storeId;
    await db.insert(
      'lan_devices',
      {
        'device_id': device.id,
        'name': device.name,
        'device_type': device.deviceType,
        'os': device.os,
        'ip': device.ip,
        'tenant_id': device.tenantId,
        'branch_id': branch,
        'store_id': device.storeId,
        'user_id': device.userId,
        'user_name': device.userName,
        'role': device.role,
        'version': device.version,
        'status': device.status.name,
        'last_seen': device.lastSeen.toIso8601String(),
        'paired_at': device.pairedAt?.toIso8601String(),
        'approved': device.approved ? 1 : 0,
        'pair_token_hash': device.pairTokenHash,
        'pending': device.pending,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> touch({
    required String deviceId,
    String? name,
    String? deviceType,
    String? os,
    String? ip,
    String? tenantId,
    String? branchId,
    String? storeId,
    String? userId,
    String? userName,
    String? role,
    String? version,
    LanDeviceStatus? status,
    int? pending,
  }) async {
    final existing = await find(deviceId);
    if (existing == null) return;
    await upsert(existing.copyWith(
      name: name?.trim().isNotEmpty == true ? name!.trim() : null,
      deviceType: deviceType?.trim().isNotEmpty == true ? deviceType!.trim() : null,
      os: os?.trim().isNotEmpty == true ? os!.trim() : null,
      ip: ip,
      tenantId: tenantId?.trim().isNotEmpty == true ? tenantId!.trim() : null,
      branchId: branchId?.trim().isNotEmpty == true ? branchId!.trim() : null,
      storeId: storeId?.trim().isNotEmpty == true ? storeId!.trim() : null,
      userId: userId,
      userName: userName,
      role: role?.trim().isNotEmpty == true ? role!.trim() : null,
      version: version,
      status: status,
      lastSeen: DateTime.now(),
      pending: pending,
    ));
  }

  Future<void> rename(String deviceId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await touch(deviceId: deviceId, name: trimmed);
  }

  Future<void> setApproved(String deviceId, {required bool approved}) async {
    final existing = await find(deviceId);
    if (existing == null) return;
    await upsert(existing.copyWith(
      status: approved ? LanDeviceStatus.online : LanDeviceStatus.blocked,
      approved: approved,
    ));
  }

  /// Soft-disable: device stays registered but cannot sync (§45 Disable).
  Future<void> disable(String deviceId) async {
    await setApproved(deviceId, approved: false);
  }

  /// Re-enable a previously disabled device.
  Future<void> enable(String deviceId) async {
    await setApproved(deviceId, approved: true);
  }

  Future<void> revoke(String deviceId) async {
    final db = await _db;
    await db.delete('lan_devices', where: 'device_id = ?', whereArgs: [deviceId]);
  }

  /// Alias for remove (§45 Remove).
  Future<void> remove(String deviceId) => revoke(deviceId);

  /// Mark devices not seen within [timeout] as offline.
  Future<int> pruneOffline({Duration timeout = const Duration(seconds: 45)}) async {
    final cutoff = DateTime.now().subtract(timeout);
    final devices = await list();
    var count = 0;
    for (final device in devices) {
      if (!device.approved) continue;
      if (device.status == LanDeviceStatus.blocked) continue;
      if (device.lastSeen.isAfter(cutoff)) continue;
      if (device.status == LanDeviceStatus.offline) continue;
      await upsert(device.copyWith(status: LanDeviceStatus.offline));
      count++;
    }
    return count;
  }
}
