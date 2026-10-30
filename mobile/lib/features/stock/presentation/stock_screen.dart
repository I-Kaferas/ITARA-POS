import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/permissions/permission_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../sync/sync_engine.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/inventory_movement_type.dart';
import '../../inventory/domain/inventory_posting.dart';
import '../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../inventory/presentation/bloc/stock_count_bloc.dart';
import '../../inventory/presentation/widgets/stock_count_view.dart';
import '../../inventory/presentation/widgets/stock_movement_sheet.dart';
import '../../pos/domain/pos_models.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

/// Stock, mouvements et inventaires (§29).
class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => InventoryBloc()..add(const InventoryStarted())),
        BlocProvider(create: (_) => StockCountBloc()..add(const StockCountStarted())),
      ],
      child: const _StockBody(),
    );
  }
}

class _StockBody extends StatefulWidget {
  const _StockBody();

  @override
  State<_StockBody> createState() => _StockBodyState();
}

class _StockBodyState extends State<_StockBody> {
  late int _revision = SyncEngine.instance.catalogRevision;

  bool get _canAdjust {
    final config = TerminalConfigRepository.instance.config;
    return config.isAdmin || PermissionCatalog(config.permissions).canAdjustStock;
  }

  @override
  void initState() {
    super.initState();
    SyncEngine.instance.addListener(_onSync);
  }

  @override
  void dispose() {
    SyncEngine.instance.removeListener(_onSync);
    super.dispose();
  }

  void _onSync() {
    final revision = SyncEngine.instance.catalogRevision;
    if (revision == _revision || !mounted) return;
    _revision = revision;
    context.read<InventoryBloc>().add(const InventoryRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InventoryBloc, InventoryState>(
      listenWhen: (a, b) => a.message != b.message || (a.errorMessage != b.errorMessage && b.status == InventoryStatus.ready),
      listener: (context, state) {
        final text = state.errorMessage ?? state.message;
        if (text == null) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(text)),
          backgroundColor: state.errorMessage != null ? AppColors.danger : null,
        ));
        context.read<InventoryBloc>().add(const InventoryFeedbackCleared());
      },
      child: DefaultTabController(
        length: 3,
        child: ColoredBox(
          color: AppColors.canvas,
          child: Column(
            children: [
              Material(
                color: AppColors.surface,
                child: TabBar(
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: [
                    Tab(text: tr('Stock')),
                    Tab(text: tr('Mouvements')),
                    Tab(text: tr('Inventaires')),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _StockList(canAdjust: _canAdjust),
                    const _MovementHistory(),
                    StockCountView(canPost: _canAdjust),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockList extends StatelessWidget {
  const _StockList({required this.canAdjust});

  final bool canAdjust;

  Future<void> _sync(BuildContext context) async {
    final bloc = context.read<InventoryBloc>();
    await SyncEngine.instance.downloadStock();
    bloc.add(const InventoryRefreshed());
  }

  Future<void> _openActions(BuildContext context, PosProduct product) async {
    final bloc = context.read<InventoryBloc>();
    final state = bloc.state;
    final choice = await AppDialogs.sheet<String>(
      context: context,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(product.name, style: PosUi.cardTitle())),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: Text(tr('Entrée / sortie / casse')),
              onTap: () => Navigator.of(context).pop('move'),
            ),
            if (state.canTransfer)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(tr('Transfert entre dépôts')),
                onTap: () => Navigator.of(context).pop('transfer'),
              ),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(tr('Historique')),
              onTap: () => Navigator.of(context).pop('history'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'history') {
      final rows = await InventoryRepository.instance.history(productId: product.productId, limit: 50);
      if (!context.mounted) return;
      await AppDialogs.sheet<void>(
        context: context,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: _MovementList(rows: rows, emptyLabel: 'Aucun mouvement pour cet article.'),
        ),
      );
      return;
    }
    final event = await AppDialogs.sheet<InventoryEvent>(
      context: context,
      child: StockMovementSheet(
        product: product,
        units: InventoryRepository.instance.unitsFor(product),
        warehouses: state.warehouses,
        transfer: choice == 'transfer',
      ),
    );
    if (event != null) bloc.add(event);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryBloc, InventoryState>(
      builder: (context, state) {
        final items = state.filtered;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => context.read<InventoryBloc>().add(InventoryQueryChanged(v)),
                      decoration: InputDecoration(
                        hintText: tr('Rechercher un produit…'),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: tr('Synchroniser'),
                    onPressed: state.isLoading ? null : () => _sync(context),
                    icon: const Icon(Icons.sync),
                  ),
                ],
              ),
            ),
            if (state.lowStockCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    trf('{0} article(s) en stock bas', [state.lowStockCount]),
                    style: PosUi.caption(color: AppColors.danger),
                  ),
                ),
              ),
            if (state.submitting) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.status == InventoryStatus.failure
                      ? Center(
                          child: TextButton(
                            onPressed: () => context.read<InventoryBloc>().add(const InventoryStarted()),
                            child: Text(trf('Erreur · Réessayer\n{0}', [state.errorMessage])),
                          ),
                        )
                      : items.isEmpty
                          ? Center(
                              child: Text(
                                tr('Aucun stock local. Synchronisez le catalogue.'),
                                style: PosUi.body(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                              itemCount: items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 6),
                              itemBuilder: (context, index) => _StockTile(
                                product: items[index],
                                onTap: canAdjust ? () => _openActions(context, items[index]) : null,
                              ),
                            ),
            ),
          ],
        );
      },
    );
  }
}

class _StockTile extends StatelessWidget {
  const _StockTile({required this.product, this.onTap});

  final PosProduct product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final qty = p.quantityOnHand ?? 0;
    final threshold = p.lowStockThreshold ?? 0;
    final low = threshold > 0 && qty <= threshold;
    final detail = p.stockDisplay?.isNotEmpty == true ? p.stockDisplay! : (p.sku.isEmpty ? '—' : p.sku);
    return AppOnce(
      id: 'stock-${p.storeProductId}',
      child: AnimatedContainer(
        duration: AppMotion.resolve(context, AppMotion.content),
        curve: AppMotion.standard,
        decoration: BoxDecoration(
          color: low ? AppColors.dangerBg : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: low ? AppColors.danger.withValues(alpha: 0.45) : AppColors.border,
          ),
        ),
        child: ListTile(
          minVerticalPadding: 12,
          onTap: onTap,
          title: Text(
            tr(p.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.text(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            low ? trf('Stock bas · {0}', [detail]) : detail,
            style: PosUi.caption(color: low ? AppColors.danger : null),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppValueFade(
                value: qty,
                child: Text(
                  '$qty',
                  style: GoogleFonts.ibmPlexMono(
                    fontWeight: FontWeight.w700,
                    color: low ? AppColors.danger : AppColors.textPrimary,
                  ),
                ),
              ),
              Text(MoneyFormatter.format(p.price), style: PosUi.caption()),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementHistory extends StatelessWidget {
  const _MovementHistory();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryBloc, InventoryState>(
      buildWhen: (a, b) => a.history != b.history || a.status != b.status,
      builder: (context, state) {
        if (state.isLoading) return const Center(child: CircularProgressIndicator());
        return RefreshIndicator(
          onRefresh: () async => context.read<InventoryBloc>().add(const InventoryRefreshed()),
          child: _MovementList(rows: state.history, emptyLabel: 'Aucun mouvement de stock local.'),
        );
      },
    );
  }
}

class _MovementList extends StatelessWidget {
  const _MovementList({required this.rows, required this.emptyLabel});

  final List<InventoryMovementRecord> rows;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return ListView(children: [
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Center(child: Text(tr(emptyLabel), style: PosUi.body(color: AppColors.textSecondary))),
        ),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = rows[index];
        final type = row.movementType;
        final inbound = row.quantity > 0;
        final pending = row.awaitingSync;
        return ListTile(
          dense: true,
          leading: Icon(
            type == InventoryMovementType.transferIn || type == InventoryMovementType.transferOut
                ? Icons.swap_horiz
                : (inbound ? Icons.south_west : Icons.north_east),
            color: inbound ? AppColors.success : AppColors.danger,
          ),
          title: Text(row.productName, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${tr(type?.label ?? row.type)} · ${_stamp(row.createdAt)}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                inbound ? '+${row.quantity}' : '${row.quantity}',
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w700,
                  color: inbound ? AppColors.success : AppColors.danger,
                ),
              ),
              if (pending) Text(tr('à synchroniser'), style: PosUi.caption()),
            ],
          ),
        );
      },
    );
  }
}

String _stamp(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}
