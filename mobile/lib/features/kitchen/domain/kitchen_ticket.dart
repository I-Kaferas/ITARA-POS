import 'kitchen_ticket_status.dart';

class KitchenTicketLine {
  const KitchenTicketLine({
    required this.name,
    this.quantity = 1,
    this.modifiers = const [],
    this.extras = const [],
    this.sides = const [],
    this.notes = '',
  });

  final String name;
  final int quantity;
  final List<String> modifiers;
  final List<String> extras;
  final List<String> sides;
  final String notes;

  factory KitchenTicketLine.fromJson(Map<String, dynamic> json) {
    List<String> strings(dynamic value) {
      if (value is! List) return const [];
      return value.map((item) {
        if (item is Map) {
          return item['name']?.toString() ?? '';
        }
        return item.toString();
      }).where((item) => item.isNotEmpty).toList();
    }

    return KitchenTicketLine(
      name: json['name']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      modifiers: strings(json['modifiers']),
      extras: strings(json['extras']),
      sides: strings(json['sides'] ?? json['accompagnements']),
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class KitchenTicket {
  const KitchenTicket({
    required this.id,
    required this.status,
    this.orderId = '',
    this.tableLabel = '',
    this.serverName = '',
    this.course = '',
    this.lines = const [],
    this.sentAt,
  });

  final String id;
  final KitchenTicketStatus status;
  final String orderId;
  final String tableLabel;
  final String serverName;
  final String course;
  final List<KitchenTicketLine> lines;
  final DateTime? sentAt;

  factory KitchenTicket.fromJson(Map<String, dynamic> json) {
    final lines = (json['lines'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => KitchenTicketLine.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return KitchenTicket(
      id: json['id']?.toString() ?? '',
      status: KitchenTicketStatus.fromWire(json['status']?.toString()),
      orderId: json['order_id']?.toString() ?? '',
      tableLabel: json['table_label']?.toString() ?? '',
      serverName: json['server_name']?.toString() ?? '',
      course: json['course']?.toString() ?? '',
      lines: lines,
      sentAt: DateTime.tryParse(json['sent_at']?.toString() ?? ''),
    );
  }

  String get headline {
    final table = tableLabel.isEmpty ? '—' : tableLabel;
    final courseLabel = course.isEmpty ? '' : ' · $course';
    return '$table$courseLabel';
  }
}
