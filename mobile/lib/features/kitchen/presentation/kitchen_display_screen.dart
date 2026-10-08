import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_error_view.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import 'bloc/kitchen_bloc.dart';
import 'widgets/kitchen_board.dart';

/// Dedicated Android/Tablet Kitchen Display (§24) with realtime refresh.
class KitchenDisplayScreen extends StatelessWidget {
  const KitchenDisplayScreen({super.key, this.embedded = false});

  /// When true, omit the outer Scaffold/AppBar (e.g. hospitality tab).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<KitchenBloc>()..add(const KitchenStarted()),
      child: _KitchenDisplayBody(embedded: embedded),
    );
  }
}

class _KitchenDisplayBody extends StatelessWidget {
  const _KitchenDisplayBody({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = BlocConsumer<KitchenBloc, KitchenState>(
      listenWhen: (prev, next) =>
          next.error != null && next.error != prev.error && next.tickets.isNotEmpty,
      listener: (context, state) {
        final message = state.error;
        if (message == null) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
      builder: (context, state) {
        if (state.isLoading && state.tickets.isEmpty) {
          return const LoadingView(message: 'Chargement cuisine…');
        }
        if (state.error != null && state.tickets.isEmpty) {
          return ErrorView(
            message: state.error!,
            onRetry: () => context.read<KitchenBloc>().add(const KitchenStarted()),
          );
        }
        return ColoredBox(
          color: AppColors.canvas,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: embedded
                          ? Text(
                              '${state.openTickets.length} bons · temps réel',
                              style: PosUi.caption(),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('CUISINE', style: PosUi.sectionLabel()),
                                Text(
                                  'Kitchen Display',
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    if (!embedded)
                      Text(
                        '${state.openTickets.length} bons',
                        style: PosUi.caption(),
                      ),
                    IconButton(
                      tooltip: 'Actualiser',
                      onPressed: () =>
                          context.read<KitchenBloc>().add(const KitchenRefreshed()),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: KitchenBoard(
                  tickets: state.tickets,
                  onAdvance: (ticket) => context
                      .read<KitchenBloc>()
                      .add(KitchenAdvanceRequested(ticket.id)),
                  onCancel: (ticket) => context
                      .read<KitchenBloc>()
                      .add(KitchenCancelRequested(ticket.id)),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(child: body),
    );
  }
}
