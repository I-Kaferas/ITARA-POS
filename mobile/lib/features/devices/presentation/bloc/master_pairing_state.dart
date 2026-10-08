part of 'master_pairing_bloc.dart';

final class MasterPairingState extends Equatable {
  const MasterPairingState({
    this.masterCode,
    this.expiresAt,
    this.busy = false,
    this.errorMessage,
    this.lastPairedHost,
    this.pendingRequests = const [],
    this.qrPayload,
    this.phase,
  });

  final String? masterCode;
  final DateTime? expiresAt;
  final bool busy;
  final String? errorMessage;
  final String? lastPairedHost;
  final List<PairingRequest> pendingRequests;
  final PairingQrPayload? qrPayload;
  final PairingPhase? phase;

  MasterPairingState copyWith({
    String? masterCode,
    DateTime? expiresAt,
    bool? busy,
    String? errorMessage,
    String? lastPairedHost,
    List<PairingRequest>? pendingRequests,
    PairingQrPayload? qrPayload,
    PairingPhase? phase,
    bool clearError = false,
  }) {
    return MasterPairingState(
      masterCode: masterCode ?? this.masterCode,
      expiresAt: expiresAt ?? this.expiresAt,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastPairedHost: lastPairedHost ?? this.lastPairedHost,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      qrPayload: qrPayload ?? this.qrPayload,
      phase: phase ?? this.phase,
    );
  }

  @override
  List<Object?> get props => [
        masterCode,
        expiresAt,
        busy,
        errorMessage,
        lastPairedHost,
        pendingRequests,
        qrPayload?.encode(),
        phase,
      ];
}
