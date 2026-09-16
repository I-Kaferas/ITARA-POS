import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_error_view.dart';
import '../../pos/data/pos_api_service.dart';
import '../../pos/domain/pos_models.dart';
import '../../pos/presentation/widgets/pos_ui.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  final _api = PosApiService();
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  List<SaleReturnRow> _rows = [];
  bool _loading = true;
  String? _error;

  String get _currency => TerminalConfigRepository.instance.config.currencyCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.fetchStoreReturns();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _statusLabel(String status) {
    return switch (status) {
      'completed' => 'Terminé',
      'pending' => 'En attente',
      'cancelled' => 'Annulé',
      'approved' => 'Approuvé',
      _ => status.isEmpty ? '—' : status,
    };
  }

  PosBadgeTone _statusTone(String status) {
    return switch (status) {
      'completed' || 'approved' => PosBadgeTone.success,
      'cancelled' => PosBadgeTone.danger,
      'pending' => PosBadgeTone.warning,
      _ => PosBadgeTone.neutral,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(
          'Retours',
          style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.brand500,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          LoadingView(message: 'Chargement des retours…'),
        ],
      );
    }

    if (_error != null && _rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: ErrorView(message: _error!, onRetry: _load),
          ),
        ],
      );
    }

    if (_rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: const EmptyState(
              icon: Icons.undo_outlined,
              title: 'Aucun retour',
              subtitle: 'Les remboursements de ce magasin apparaîtront ici.',
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: PosUi.pagePadding(context),
      itemCount: _rows.length + (_error != null ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (_error != null && index == 0) {
          return Text(_error!, style: PosUi.caption(color: AppColors.danger));
        }
        final row = _rows[_error != null ? index - 1 : index];
        return _ReturnCard(
          row: row,
          dateFormat: _dateFormat,
          currency: _currency,
          statusLabel: _statusLabel(row.status),
          statusTone: _statusTone(row.status),
        );
      },
    );
  }
}

class _ReturnCard extends StatelessWidget {
  const _ReturnCard({
    required this.row,
    required this.dateFormat,
    required this.currency,
    required this.statusLabel,
    required this.statusTone,
  });

  final SaleReturnRow row;
  final DateFormat dateFormat;
  final String currency;
  final String statusLabel;
  final PosBadgeTone statusTone;

  @override
  Widget build(BuildContext context) {
    final created = DateTime.tryParse(row.createdAt ?? '');
    final saleId = row.sale?['id']?.toString();
    final saleRef = row.sale?['reference']?.toString();
    final customerName = row.customer?['name']?.toString();

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(PosUi.radiusXl),
      child: InkWell(
        borderRadius: BorderRadius.circular(PosUi.radiusXl),
        onTap: saleId == null || saleId.isEmpty
            ? null
            : () => context.go(AppRoutes.saleDetail(saleId)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosUi.radiusXl),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.returnNumber,
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  PosBadge(label: statusLabel, tone: statusTone),
                ],
              ),
              const SizedBox(height: 10),
              _MetaRow(label: 'Vente', value: (saleRef == null || saleRef.isEmpty) ? '—' : saleRef),
              _MetaRow(label: 'Client', value: (customerName == null || customerName.isEmpty) ? '—' : customerName),
              _MetaRow(
                label: 'Total',
                value: MoneyFormatter.format(row.total, currencyCode: currency),
                mono: true,
              ),
              _MetaRow(
                label: 'Date',
                value: created == null ? '—' : dateFormat.format(created.toLocal()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: PosUi.caption()),
          ),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? PosUi.money(size: 13)
                  : PosUi.body(weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
