part of 'device_bloc.dart';

sealed class DeviceEvent extends Equatable {
  const DeviceEvent();

  @override
  List<Object?> get props => const [];
}

final class DeviceStarted extends DeviceEvent {
  const DeviceStarted();
}

final class DeviceRefreshed extends DeviceEvent {
  const DeviceRefreshed();
}

final class DeviceRevokeRequested extends DeviceEvent {
  const DeviceRevokeRequested(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => [deviceId];
}

final class DeviceApproveRequested extends DeviceEvent {
  const DeviceApproveRequested(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => [deviceId];
}

final class DeviceRenameRequested extends DeviceEvent {
  const DeviceRenameRequested({required this.deviceId, required this.name});

  final String deviceId;
  final String name;

  @override
  List<Object?> get props => [deviceId, name];
}

/// §45 Disable
final class DeviceDisableRequested extends DeviceEvent {
  const DeviceDisableRequested(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => [deviceId];
}

/// §45 Enable (re-approve after disable)
final class DeviceEnableRequested extends DeviceEvent {
  const DeviceEnableRequested(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => [deviceId];
}

/// §45 Remove
final class DeviceRemoveRequested extends DeviceEvent {
  const DeviceRemoveRequested(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => [deviceId];
}

/// §45 Sync
final class DeviceSyncRequested extends DeviceEvent {
  const DeviceSyncRequested(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => [deviceId];
}

/// §45 Reconnect
final class DeviceReconnectRequested extends DeviceEvent {
  const DeviceReconnectRequested(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => [deviceId];
}

/// §45 Send Configuration
final class DeviceSendConfigurationRequested extends DeviceEvent {
  const DeviceSendConfigurationRequested(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => [deviceId];
}
