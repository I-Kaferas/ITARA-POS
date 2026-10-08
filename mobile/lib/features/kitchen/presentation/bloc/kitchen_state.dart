part of 'kitchen_bloc.dart';

enum KitchenLoadStatus { initial, loading, ready, failure }

final class KitchenState extends Equatable {
  const KitchenState({
    this.status = KitchenLoadStatus.initial,
    this.tickets = const [],
    this.error,
  });

  final KitchenLoadStatus status;
  final List<KitchenTicket> tickets;
  final String? error;

  bool get isLoading => status == KitchenLoadStatus.loading;

  List<KitchenTicket> get openTickets =>
      tickets.where((ticket) => ticket.status.isOpen).toList();

  List<KitchenTicket> byStatus(KitchenTicketStatus status) =>
      openTickets.where((ticket) => ticket.status == status).toList();

  KitchenState copyWith({
    KitchenLoadStatus? status,
    List<KitchenTicket>? tickets,
    String? error,
    bool clearError = false,
  }) {
    return KitchenState(
      status: status ?? this.status,
      tickets: tickets ?? this.tickets,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, tickets, error];
}
