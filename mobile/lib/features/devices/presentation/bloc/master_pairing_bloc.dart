import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../sync/local_master_discovery.dart';
import '../../../../sync/pairing_models.dart';
import '../../../../sync/pairing_service.dart';

part 'master_pairing_event.dart';
part 'master_pairing_state.dart';

class MasterPairingBloc extends Bloc<MasterPairingEvent, MasterPairingState> {
  MasterPairingBloc(this._pairing)
      : super(MasterPairingState(
          masterCode: _pairing.activeCode,
          expiresAt: _pairing.expiresAt,
          pendingRequests: _pairing.pendingRequests,
          qrPayload: _pairing.masterQrPayload,
        )) {
    _pairing.addListener(_onChanged);
    on<MasterPairingSynced>(_onSynced);
    on<MasterPairingCodeRefreshRequested>(_onRefreshCode);
    on<MasterPairingAcceptRequested>(_onAccept);
    on<MasterPairingRejectRequested>(_onReject);
    on<MasterPairingSlaveRequested>(_onPairSlave);
    on<MasterPairingQrRequested>(_onPairQr);
  }

  final PairingService _pairing;

  void _onChanged() => add(const MasterPairingSynced());

  void _onSynced(
    MasterPairingSynced event,
    Emitter<MasterPairingState> emit,
  ) {
    emit(state.copyWith(
      masterCode: _pairing.activeCode,
      expiresAt: _pairing.expiresAt,
      pendingRequests: _pairing.pendingRequests,
      qrPayload: _pairing.masterQrPayload,
    ));
  }

  void _onRefreshCode(
    MasterPairingCodeRefreshRequested event,
    Emitter<MasterPairingState> emit,
  ) {
    _pairing.refreshCode();
  }

  Future<void> _onAccept(
    MasterPairingAcceptRequested event,
    Emitter<MasterPairingState> emit,
  ) async {
    try {
      await _pairing.acceptRequest(event.requestId);
    } catch (error) {
      emit(state.copyWith(
        pendingRequests: _pairing.pendingRequests,
        qrPayload: _pairing.masterQrPayload,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  void _onReject(
    MasterPairingRejectRequested event,
    Emitter<MasterPairingState> emit,
  ) {
    _pairing.rejectRequest(event.requestId);
  }

  Future<void> _onPairSlave(
    MasterPairingSlaveRequested event,
    Emitter<MasterPairingState> emit,
  ) async {
    emit(state.copyWith(
      busy: true,
      clearError: true,
      phase: PairingPhase.authentication,
    ));
    try {
      await _pairing.pairWithMaster(
        host: '${event.master.host}:${event.master.port}',
        code: event.code,
        masterDeviceId: event.master.masterId,
      );
      emit(state.copyWith(
        busy: false,
        lastPairedHost: event.master.host,
        pendingRequests: _pairing.pendingRequests,
        qrPayload: _pairing.masterQrPayload,
        phase: PairingPhase.registered,
      ));
    } catch (error) {
      emit(state.copyWith(
        busy: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
        pendingRequests: _pairing.pendingRequests,
        qrPayload: _pairing.masterQrPayload,
        phase: PairingPhase.rejected,
      ));
    }
  }

  Future<void> _onPairQr(
    MasterPairingQrRequested event,
    Emitter<MasterPairingState> emit,
  ) async {
    emit(state.copyWith(
      busy: true,
      clearError: true,
      phase: PairingPhase.handshake,
    ));
    try {
      await _pairing.pairWithQr(event.raw);
      emit(state.copyWith(
        busy: false,
        lastPairedHost: _pairing.masterQrPayload?.ip,
        pendingRequests: _pairing.pendingRequests,
        qrPayload: _pairing.masterQrPayload,
        phase: PairingPhase.registered,
      ));
    } catch (error) {
      emit(state.copyWith(
        busy: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
        pendingRequests: _pairing.pendingRequests,
        qrPayload: _pairing.masterQrPayload,
        phase: PairingPhase.rejected,
      ));
    }
  }

  @override
  Future<void> close() {
    _pairing.removeListener(_onChanged);
    return super.close();
  }
}
