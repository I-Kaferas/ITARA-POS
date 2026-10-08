import 'package:uuid/uuid.dart';

import 'print_group.dart';

/// Maps category / product / document → print group (mobile.md §40).
enum PrintRouteKind { category, product, document }

extension PrintRouteKindX on PrintRouteKind {
  String get label => switch (this) {
        PrintRouteKind.category => 'Catégorie → Imprimante',
        PrintRouteKind.product => 'Produit → Imprimante',
        PrintRouteKind.document => 'Document → Imprimante',
      };

  /// Default sort priority when seeding (product most specific).
  int get defaultPriority => switch (this) {
        PrintRouteKind.product => 1,
        PrintRouteKind.category => 10,
        PrintRouteKind.document => 100,
      };
}

class PrintRoute {
  const PrintRoute({
    required this.id,
    required this.kind,
    required this.matchKey,
    required this.group,
    this.printerId = '',
    this.enabled = true,
    this.priority = 100,
    this.label = '',
  });

  final String id;
  final PrintRouteKind kind;
  final String matchKey;
  final PrintGroup group;
  final String printerId;
  final bool enabled;
  final int priority;
  /// Human label for UI (e.g. "Drink → Bar Printer"). Not required in DB.
  final String label;

  String get displayLabel {
    if (label.trim().isNotEmpty) return label.trim();
    final arrow = '${matchKey.isEmpty ? '—' : matchKey} → ${group.label}';
    return switch (kind) {
      PrintRouteKind.product => 'Produit $arrow',
      PrintRouteKind.category => 'Catégorie $arrow',
      PrintRouteKind.document => 'Document $arrow',
    };
  }

  factory PrintRoute.fromJson(Map<String, dynamic> json) {
    return PrintRoute(
      id: json['id']?.toString() ?? const Uuid().v4(),
      kind: PrintRouteKind.values.firstWhere(
        (item) => item.name == (json['kind']?.toString() ?? ''),
        orElse: () => PrintRouteKind.document,
      ),
      matchKey: json['match_key']?.toString() ?? '',
      group: PrintGroup.fromString(json['print_group']?.toString()),
      printerId: json['printer_id']?.toString() ?? '',
      enabled: json['enabled'] != false && json['enabled'] != 0,
      priority: (json['priority'] as num?)?.toInt() ?? 100,
      label: json['label']?.toString() ?? '',
    );
  }

  factory PrintRoute.fromRow(Map<String, Object?> row) {
    return PrintRoute.fromJson({
      'id': row['id'],
      'kind': row['kind'],
      'match_key': row['match_key'],
      'print_group': row['print_group'],
      'printer_id': row['printer_id'],
      'enabled': row['enabled'],
      'priority': row['priority'],
      'label': row['label'],
    });
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'match_key': matchKey,
        'print_group': group.name,
        'printer_id': printerId,
        'enabled': enabled,
        'priority': priority,
        'label': label,
      };

  Map<String, Object?> toRow() => {
        'id': id,
        'kind': kind.name,
        'match_key': matchKey,
        'print_group': group.name,
        'printer_id': printerId.isEmpty ? null : printerId,
        'enabled': enabled ? 1 : 0,
        'priority': priority,
        'label': label.isEmpty ? null : label,
      };

  PrintRoute copyWith({
    String? id,
    PrintRouteKind? kind,
    String? matchKey,
    PrintGroup? group,
    String? printerId,
    bool? enabled,
    int? priority,
    String? label,
  }) {
    return PrintRoute(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      matchKey: matchKey ?? this.matchKey,
      group: group ?? this.group,
      printerId: printerId ?? this.printerId,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      label: label ?? this.label,
    );
  }
}
