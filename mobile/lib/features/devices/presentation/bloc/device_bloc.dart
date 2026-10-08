import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../sync/device_registry.dart';
import '../../../../sync/local_master_server.dart';
import '../../../../sync/local_realtime.dart';
import '../../../../sync/master_config_store.dart';

part 'device_event.dart';
part 'device_state.dart';

class DeviceBloc extends Bloc<DeviceEvent, DeviceState> {
  DeviceBloc({
    required DeviceRegistry registry,
    required LocalMasterServer masterServer,
  })  : _registry = registry,
        _master = masterServer,
        super(const DeviceState()) {
    _master.addListener(_onMasterChanged);
    on<DeviceStarted>(_onStarted);
    on<DeviceRefreshed>(_onRefreshed);
    on<DeviceRevokeRequested>(_onRevoke);
    on<DeviceApproveRequested>(_onApprove);
    on<DeviceRenameRequested>(_onRename);
    on<DeviceDisableRequested>(_onDisable);
    on<DeviceEnableRequested>(_onEnable);
    on<DeviceRemoveRequested>(_onRemove);
    on<DeviceSyncRequested>(_onSync);
    on<DeviceReconnectRequested>(_onReconnect);
    on<DeviceSendConfigurationRequested>(_onSendConfiguration);
    add(const DeviceStarted());
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      add(const DeviceRefreshed());
    });
  }

  final DeviceRegistry _registry;
  final LocalMasterServer _master;
  Timer? _timer;

  void _onMasterChanged() => add(const DeviceRefreshed());

  Future<void> _onStarted(
    DeviceStarted event,
    Emitter<DeviceState> emit,
  ) async {
    await _refresh(emit);
  }

  Future<void> _onRefreshed(
    DeviceRefreshed event,
    Emitter<DeviceState> emit,
  ) async {
    await _refresh(emit);
  }

  Future<void> _onRevoke(
    DeviceRevokeRequested event,
    Emitter<DeviceState> emit,
  ) async {
    await _registry.revoke(event.deviceId);
    _master.clients.remove(event.deviceId);
    await _refresh(emit, message: 'Appareil révoqué');
  }

  Future<void> _onApprove(
    DeviceApproveRequested event,
    Emitter<DeviceState> emit,
  ) async {
    await _registry.setApproved(event.deviceId, approved: true);
    await _refresh(emit, message: 'Appareil approuvé');
  }

  Future<void> _onRename(
    DeviceRenameRequested event,
    Emitter<DeviceState> emit,
  ) async {
    await _registry.rename(event.deviceId, event.name);
    await _refresh(emit, message: 'Appareil renommé');
  }

  Future<void> _onDisable(
    DeviceDisableRequested event,
    Emitter<DeviceState> emit,
  ) async {
    await _registry.disable(event.deviceId);
    _master.clients.remove(event.deviceId);
    LocalRealtimeHub.instance.publishToDevice(
      event.deviceId,
      RealtimeEvent(
        type: RealtimeEventType.deviceCommand,
        payload: {'action': 'disable', 'device_id': event.deviceId},
      ),
    );
    await _refresh(emit, message: 'Appareil désactivé');
  }

  Future<void> _onEnable(
    DeviceEnableRequested event,
    Emitter<DeviceState> emit,
  ) async {
    await _registry.enable(event.deviceId);
    await _refresh(emit, message: 'Appareil réactivé');
  }

  Future<void> _onRemove(
    DeviceRemoveRequested event,
    Emitter<DeviceState> emit,
  ) async {
    await _registry.remove(event.deviceId);
    _master.clients.remove(event.deviceId);
    LocalRealtimeHub.instance.publish(RealtimeEvent(
      type: RealtimeEventType.deviceDisconnected,
      originDeviceId: event.deviceId,
      payload: {'device_id': event.deviceId, 'reason': 'removed'},
    ));
    await _refresh(emit, message: 'Appareil retiré');
  }

  Future<void> _onSync(
    DeviceSyncRequested event,
    Emitter<DeviceState> emit,
  ) async {
    await _registry.touch(
      deviceId: event.deviceId,
      status: LanDeviceStatus.syncing,
    );
    final sent = LocalRealtimeHub.instance.publishToDevice(
      event.deviceId,
      RealtimeEvent(
        type: RealtimeEventType.deviceCommand,
        payload: {'action': 'sync', 'device_id': event.deviceId},
      ),
    );
    await _refresh(
      emit,
      message: sent > 0 ? 'Sync demandé' : 'Sync demandé (hors ligne)',
    );
  }

  Future<void> _onReconnect(
    DeviceReconnectRequested event,
    Emitter<DeviceState> emit,
  ) async {
    final sent = LocalRealtimeHub.instance.publishToDevice(
      event.deviceId,
      RealtimeEvent(
        type: RealtimeEventType.deviceCommand,
        payload: {'action': 'reconnect', 'device_id': event.deviceId},
      ),
    );
    await _refresh(
      emit,
      message: sent > 0 ? 'Reconnexion demandée' : 'Appareil hors ligne',
    );
  }

  Future<void> _onSendConfiguration(
    DeviceSendConfigurationRequested event,
    Emitter<DeviceState> emit,
  ) async {
    final doc = await MasterConfigStore.instance.publishFromLocalTerminal();
    LocalRealtimeHub.instance.publish(RealtimeEvent(
      type: RealtimeEventType.configUpdated,
      payload: {'version': doc['version'], 'device_id': event.deviceId},
    ));
    final sent = LocalRealtimeHub.instance.publishToDevice(
      event.deviceId,
      RealtimeEvent(
        type: RealtimeEventType.deviceCommand,
        payload: {
          'action': 'send_configuration',
          'device_id': event.deviceId,
          'version': doc['version'],
        },
      ),
    );
    await _refresh(
      emit,
      message: sent > 0
          ? 'Configuration envoyée (v${doc['version']})'
          : 'Configuration publiée (appareil hors ligne)',
    );
  }

  Future<void> _refresh(Emitter<DeviceState> emit, {String? message}) async {
    emit(state.copyWith(loading: true, clearMessage: message == null));
    final devices = await _registry.list();
    emit(DeviceState(devices: devices, message: message));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _master.removeListener(_onMasterChanged);
    return super.close();
  }
}
