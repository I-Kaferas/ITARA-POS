import '../../hospitality/data/hospitality_api.dart';
import '../domain/kitchen_ticket.dart';
import '../domain/kitchen_ticket_status.dart';

class KitchenRepository {
  KitchenRepository({HospitalityApi? api}) : _api = api ?? HospitalityApi();

  final HospitalityApi _api;

  Future<List<KitchenTicket>> fetchTickets() async {
    final snap = await _api.snapshot();
    final docs = (snap['docs'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((doc) => doc['kind']?.toString() == 'ticket')
        .map(KitchenTicket.fromJson)
        .toList();
    docs.sort((a, b) {
      final aAt = a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aAt.compareTo(bAt);
    });
    return docs;
  }

  Future<List<KitchenTicket>> setStatus({
    required String ticketId,
    required KitchenTicketStatus status,
  }) async {
    final snap = await _api.apply({
      'action': 'set_ticket_status',
      'ticket_id': ticketId,
      'status': status.storage,
    });
    final docs = (snap['docs'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((doc) => doc['kind']?.toString() == 'ticket')
        .map(KitchenTicket.fromJson)
        .toList();
    docs.sort((a, b) {
      final aAt = a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aAt.compareTo(bAt);
    });
    return docs;
  }
}
