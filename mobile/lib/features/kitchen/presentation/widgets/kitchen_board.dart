import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../pos/presentation/widgets/pos_ui.dart';
import '../../domain/kitchen_ticket.dart';
import '../../domain/kitchen_ticket_status.dart';

/// Tablet-first Kitchen Display board (§24).
class KitchenBoard extends StatelessWidget {
  const KitchenBoard({
    super.key,
    required this.tickets,
    required this.onAdvance,
    this.onCancel,
  });

  final List<KitchenTicket> tickets;
  final ValueChanged<KitchenTicket> onAdvance;
  final ValueChanged<KitchenTicket>? onCancel;

  static const _columns = [
    KitchenTicketStatus.neu,
    KitchenTicketStatus.preparing,
    KitchenTicketStatus.ready,
  ];

  @override
  Widget build(BuildContext context) {
    final open = tickets.where((ticket) => ticket.status.isOpen).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final columns = _columns
            .map(
              (status) => KitchenColumn(
                status: status,
                tickets: open.where((ticket) => ticket.status == status).toList(),
                onAdvance: onAdvance,
                onCancel: onCancel,
                scroll: wide,
              ),
            )
            .toList();
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final column in columns) Expanded(child: column),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: columns,
        );
      },
    );
  }
}

class KitchenColumn extends StatelessWidget {
  const KitchenColumn({
    super.key,
    required this.status,
    required this.tickets,
    required this.onAdvance,
    this.onCancel,
    this.scroll = false,
  });

  final KitchenTicketStatus status;
  final List<KitchenTicket> tickets;
  final ValueChanged<KitchenTicket> onAdvance;
  final ValueChanged<KitchenTicket>? onCancel;
  final bool scroll;

  Color get _accent => switch (status) {
        KitchenTicketStatus.neu => const Color(0xFFB45309),
        KitchenTicketStatus.preparing => AppColors.brand700,
        KitchenTicketStatus.ready => const Color(0xFF047857),
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${status.label} · ${tickets.length}',
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    final body = tickets.isEmpty
        ? Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Aucun bon', style: PosUi.caption(color: AppColors.textMuted)),
          )
        : Column(
            children: [
              for (final ticket in tickets)
                KitchenTicketCard(
                  ticket: ticket,
                  onAdvance: onAdvance,
                  onCancel: onCancel,
                ),
            ],
          );

    if (!scroll) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [header, body],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                children: [
                  if (tickets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Aucun bon', style: PosUi.caption(color: AppColors.textMuted)),
                    )
                  else
                    for (final ticket in tickets)
                      KitchenTicketCard(
                        ticket: ticket,
                        onAdvance: onAdvance,
                        onCancel: onCancel,
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KitchenTicketCard extends StatelessWidget {
  const KitchenTicketCard({
    super.key,
    required this.ticket,
    required this.onAdvance,
    this.onCancel,
  });

  final KitchenTicket ticket;
  final ValueChanged<KitchenTicket> onAdvance;
  final ValueChanged<KitchenTicket>? onCancel;

  @override
  Widget build(BuildContext context) {
    final next = ticket.status.next;
    final age = ticket.sentAt == null
        ? ''
        : _ageLabel(DateTime.now().difference(ticket.sentAt!));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.headline,
                    style: GoogleFonts.ibmPlexSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (age.isNotEmpty)
                  Text(age, style: PosUi.caption(color: AppColors.textMuted)),
              ],
            ),
            if (ticket.serverName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(ticket.serverName, style: PosUi.caption()),
            ],
            const SizedBox(height: 8),
            for (final line in ticket.lines) ...[
              Text(
                '${line.quantity} × ${line.name}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              if (line.modifiers.isNotEmpty)
                Text('  · ${line.modifiers.join(', ')}', style: PosUi.caption()),
              if (line.extras.isNotEmpty)
                Text('  + ${line.extras.join(', ')}', style: PosUi.caption()),
              if (line.sides.isNotEmpty)
                Text('  → ${line.sides.join(', ')}', style: PosUi.caption()),
              if (line.notes.isNotEmpty)
                Text('  ! ${line.notes}', style: PosUi.caption(color: AppColors.danger)),
              const SizedBox(height: 4),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (next != null)
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(PosUi.ctaHeight),
                      ),
                      onPressed: () => onAdvance(ticket),
                      child: Text(ticket.status.advanceLabel),
                    ),
                  ),
                if (next != null && onCancel != null) const SizedBox(width: 8),
                if (onCancel != null)
                  IconButton.outlined(
                    tooltip: 'Annuler',
                    onPressed: () => onCancel!(ticket),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _ageLabel(Duration age) {
    if (age.inMinutes < 1) return '<1 min';
    if (age.inHours < 1) return '${age.inMinutes} min';
    return '${age.inHours} h';
  }
}
