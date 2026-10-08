part of 'device_bloc.dart';

final class DeviceState extends Equatable {
  const DeviceState({
    this.devices = const [],
    this.loading = false,
    this.message,
  });

  final List<LanDevice> devices;
  final bool loading;
  final String? message;

  DeviceState copyWith({
    List<LanDevice>? devices,
    bool? loading,
    String? message,
    bool clearMessage = false,
  }) {
    return DeviceState(
      devices: devices ?? this.devices,
      loading: loading ?? this.loading,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => [devices, loading, message];
}
