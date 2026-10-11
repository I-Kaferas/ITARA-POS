import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../sync/offline_store.dart';
import '../../pos/data/pos_api_service.dart';
import '../../pos/domain/pos_models.dart';
import '../../pos/presentation/widgets/pos_merge_sheet.dart';
import '../../pos/services/pos_pending_intent.dart';
import '../../receipt/domain/receipt_models.dart';
import '../../receipt/services/receipt_print_service.dart';
import '../data/orders_api_service.dart';
import '../domain/order_models.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _api = OrdersApiService();
  final _posApi = PosApiService();
  final _printer = ReceiptPrintService();
  final _search = TextEditingController();

  List<_SaleRow> _sales = [];
  List<_SaleRow> _holds = [];
  List<PurchaseOrder> _orders = [];
  List<PurchaseInvoice> _invoices = [];
  bool _loading = true;
  String? _salesError;
  String? _ordersError;
  String? _invoicesError;
  String? _docBusyId;
  int _section = 0;
  int _lane = 0;
  bool _quarantine = false;
  String _storeKey = 'all';
  String? _status;
  String? _payment;
  DateTime? _from;
  DateTime? _to;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    OfflineStore.instance.holdsRevision.addListener(_onHoldsChanged);
    _load();
  }

  @override
  void dispose() {
    OfflineStore.instance.holdsRevision.removeListener(_onHoldsChanged);
    _search.dispose();
    super.dispose();
  }

  void _onHoldsChanged() {
    if (!mounted) return;
    _refreshHolds();
  }

  Future<void> _refreshHolds() async {
    final holds = await OfflineStore.instance.loadLocalHolds();
    if (!mounted) return;
    setState(() {
      _holds = holds.map(_SaleRow.fromHold).where((sale) => sale.reference.isNotEmpty).toList();
    });
  }

  String? get _sectionError => switch (_section) {
        0 => _salesError,
        1 => _ordersError,
        2 => _invoicesError,
        _ => null,
      };

  Future<void> _load() async {
    setState(() => _loading = true);
    await _loadLocalSales();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadLocalSales() async {
    final sales = await OfflineStore.instance.listLocalSales();
    final holds = await OfflineStore.instance.loadLocalHolds();
    if (!mounted) return;
    setState(() {
      _sales = sales.map(_SaleRow.fromLocal).toList();
      _holds = holds.map(_SaleRow.fromHold).where((sale) => sale.total > 0 || sale.reference.isNotEmpty).toList();
    });
  }

  Future<void> _loadRemoteSales() async {
    try {
      final remote = await _posApi.fetchSales(
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        status: _section == 0 && _status != null && _status != 'failed' ? _status : null,
        paymentStatus: _section == 0 ? _payment : null,
        from: _from == null ? null : DateFormat('yyyy-MM-dd').format(_from!),
        to: _to == null ? null : DateFormat('yyyy-MM-dd').format(_to!),
      );
      if (!mounted) return;
      final remoteRows = remote.map(_SaleRow.fromRemote).where((sale) => sale.id.isNotEmpty).toList();
      setState(() {
        _sales = _mergeSales(local: _sales.where((sale) => !sale.isRemote).toList(), remote: remoteRows);
        _salesError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _salesError = _networkMessage(error));
    }
  }

  List<_SaleRow> _mergeSales({required List<_SaleRow> local, required List<_SaleRow> remote}) {
    final remoteIds = <String>{};
    for (final sale in remote) {
      remoteIds.add(sale.id);
      final serverId = sale.serverId;
      if (serverId != null && serverId.isNotEmpty) remoteIds.add(serverId);
    }
    final keptLocal = local.where((sale) {
      if (remoteIds.contains(sale.id)) return false;
      final serverId = sale.serverId;
      if (serverId != null && serverId.isNotEmpty && remoteIds.contains(serverId)) return false;
      return true;
    });
    return [...keptLocal, ...remote];
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await _api.fetchOrders(
        status: _section == 1 ? _status : null,
        search: _search.text.trim(),
        from: _from,
        to: _to,
      );
      if (!mounted) return;
      setState(() {
        _orders = orders.items;
        _ordersError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _ordersError = _networkMessage(error));
    }
  }

  Future<void> _loadInvoices() async {
    try {
      final invoices = await _api.fetchInvoices(
        status: _section == 2 ? _status : null,
        search: _search.text.trim(),
        from: _from,
        to: _to,
      );
      if (!mounted) return;
      setState(() {
        _invoices = invoices.items;
        _invoicesError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _invoicesError = _networkMessage(error));
    }
  }

  String _networkMessage(Object error) {
    final text = error.toString();
    if (text.contains('refused') ||
        text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('timed out')) {
      return 'Impossible de joindre le serveur. Réessayez dans un instant.';
    }
    return text.replaceFirst('Exception: ', '');
  }

  List<_SaleRow> get _venteRows {
    final remoteIds = _sales.where((sale) => sale.isRemote).map((sale) => sale.id).toSet();
    for (final sale in _sales.where((sale) => sale.isRemote)) {
      final serverId = sale.serverId;
      if (serverId != null && serverId.isNotEmpty) remoteIds.add(serverId);
    }
    final holds = _holds.where((hold) {
      if (remoteIds.contains(hold.id)) return false;
      final serverId = hold.serverId;
      if (serverId != null && serverId.isNotEmpty && remoteIds.contains(serverId)) return false;
      return true;
    });
    final rows = [...holds, ..._sales];
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  bool _inRange(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    if (_from != null && day.isBefore(DateTime(_from!.year, _from!.month, _from!.day))) return false;
    if (_to != null && day.isAfter(DateTime(_to!.year, _to!.month, _to!.day))) return false;
    return true;
  }

  List<_ListItem> get _items {
    final query = _search.text.trim().toLowerCase();
    bool matches(String value) => query.isEmpty || value.toLowerCase().contains(query);

    if (_section == 0) {
      return _venteRows
          .where((sale) => matches('${sale.reference} ${sale.method} ${sale.status} ${sale.statusLabel} ${sale.customerName}'))
          .where((sale) => _inRange(sale.createdAt))
          .where((sale) => _status == null || sale.filterStatus == _status)
          .where((sale) => _payment == null || sale.matchesPayment(_payment!))
          .where((sale) => _matchesLane(_saleLane(sale)))
          .map((sale) => _ListItem(
                id: sale.id,
                title: sale.reference,
                subtitle: sale.subtitle,
                meta: _date(sale.createdAt),
                amount: sale.total,
                currency: sale.currency,
                status: sale.statusLabel,
                statusKey: sale.status,
                kind: sale.isHold ? 'hold' : 'sale',
              ))
          .toList();
    }
    if (_section == 1) {
      return _orders
          .where((order) => matches('${order.orderNumber} ${order.supplierName ?? ''}'))
          .where((order) => _inRange(order.createdAt))
          .where((order) => _status == null || order.status == _status)
          .where((order) => _matchesLane(_purchaseLane(order.status)))
          .map((order) => _ListItem(
                id: order.id,
                title: order.orderNumber,
                subtitle: order.supplierName ?? 'Fournisseur',
                meta: _date(order.createdAt),
                amount: order.total,
                currency: order.currencyCode,
                status: _orderStatus(order.status),
                statusKey: order.status,
                kind: 'purchase',
              ))
          .toList();
    }
    return _invoices
        .where((invoice) => matches('${invoice.invoiceNumber} ${invoice.supplierName ?? ''}'))
        .where((invoice) => _inRange(invoice.invoicedAt))
        .where((invoice) => _status == null || invoice.status == _status)
        .where((invoice) => _matchesLane(_invoiceLane(invoice.status)))
        .map((invoice) => _ListItem(
              id: invoice.id,
              title: invoice.invoiceNumber,
              subtitle: invoice.supplierName ?? 'Facture',
              meta: _date(invoice.invoicedAt),
              amount: invoice.total,
              currency: 'FBU',
              status: _invoiceStatus(invoice.status),
              statusKey: invoice.status,
              kind: 'invoice',
            ))
        .toList();
  }

  void _openHoldOnPos(String holdId, {PosHoldAction action = PosHoldAction.modify}) {
    PosPendingIntent.retrieveHold(holdId, action: action);
    context.go(AppRoutes.pos);
  }

  void _resumeSale(_SaleRow sale) {
    _openHoldOnPos(sale.resumeId);
  }

  void _viewSale(_SaleRow sale) {
    final id = sale.detailId;
    if (id == null || id.isEmpty) return;
    context.go(AppRoutes.saleDetail(id));
  }

  Future<void> _mergeSale(_SaleRow sale) async {
    final id = sale.mergeId;
    if (id == null || id.isEmpty) return;
    final merged = await showPosMergeSheet(
      context,
      saleId: id,
      saleReference: sale.reference,
      api: _posApi,
    );
    if (merged == true && mounted) await _load();
  }

  Future<void> _createReceipt(_SaleRow sale) async {
    final id = sale.detailId;
    if (id == null || id.isEmpty) return;
    await _issueDocument(saleId: id, label: 'Reçu', create: () => _posApi.createReceipt(id));
  }

  Future<void> _createInvoice(_SaleRow sale) async {
    final id = sale.detailId;
    if (id == null || id.isEmpty) return;
    await _issueDocument(saleId: id, label: 'Facture', create: () => _posApi.createInvoice(id));
  }

  Future<void> _issueDocument({
    required String saleId,
    required String label,
    required Future<Map<String, dynamic>> Function() create,
  }) async {
    setState(() => _docBusyId = saleId);
    try {
      final result = await create();
      final payload = _receiptPayload(result);
      if (payload != null) {
        await _printer.print(payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label imprimé')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label créé avec succès')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_networkMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _docBusyId = null);
    }
  }

  _Detail? get _detail {
    final id = _selectedId;
    if (id == null) return null;
    if (_section == 0) {
      final sale = _venteRows.where((item) => item.id == id).firstOrNull;
      if (sale == null) return null;
      final canSplit = sale.isHold &&
          (sale.lines.length >= 2 || sale.lines.any((line) => line.quantity > 1));
      return _Detail(
        title: sale.reference,
        status: sale.statusLabel,
        statusKey: sale.status,
        amount: MoneyFormatter.format(sale.total, currencyCode: sale.currency),
        currency: sale.currency,
        lines: sale.lines,
        subtotal: sale.lines.fold<int>(0, (sum, line) => sum + line.lineTotal),
        itemCount: sale.itemCount > 0
            ? sale.itemCount
            : sale.lines.fold<int>(0, (sum, line) => sum + line.quantity),
        rows: [
          ('Date', _date(sale.createdAt)),
          if (sale.customerName != null && sale.customerName!.isNotEmpty) ('Client', sale.customerName!),
          if (sale.note != null && sale.note!.isNotEmpty) ('Note', sale.note!),
          if (!sale.isHold) ('Paiement', sale.methodLabel),
          if (!sale.isHold) ('Payé', MoneyFormatter.format(sale.paid, currencyCode: sale.currency)),
          if (!sale.isHold) ('Reste', MoneyFormatter.format(sale.outstanding, currencyCode: sale.currency)),
          ('Origine', sale.isHold ? 'Caisse locale' : sale.isRemote ? 'Serveur' : 'Vente locale'),
          if (!sale.isHold && !sale.isRemote) ('Synchro', sale.syncLabel),
          if (sale.isRemote) ('Paiement statut', sale.paymentStatus),
        ],
        onModify: sale.isHold ? () => _openHoldOnPos(sale.id) : null,
        onAddArticles: sale.isHold ? () => _openHoldOnPos(sale.id, action: PosHoldAction.addArticles) : null,
        onSplit: canSplit ? () => _openHoldOnPos(sale.id, action: PosHoldAction.split) : null,
        onPay: sale.isHold ? () => _openHoldOnPos(sale.id, action: PosHoldAction.pay) : null,
      );
    }
    if (_section == 1) {
      final order = _orders.where((item) => item.id == id).firstOrNull;
      if (order == null) return null;
      return _Detail(
        title: order.orderNumber,
        status: _orderStatus(order.status),
        statusKey: order.status,
        amount: MoneyFormatter.format(order.total, currencyCode: order.currencyCode),
        currency: order.currencyCode,
        rows: [
          ('Fournisseur', order.supplierName ?? '—'),
          ('Entrepôt', order.warehouseName ?? '—'),
          ('Date', _date(order.createdAt)),
          if (order.expectedAt != null) ('Livraison', _date(order.expectedAt!)),
          if (order.notes != null && order.notes!.isNotEmpty) ('Notes', order.notes!),
        ],
      );
    }
    final invoice = _invoices.where((item) => item.id == id).firstOrNull;
    if (invoice == null) return null;
    return _Detail(
      title: invoice.invoiceNumber,
      status: _invoiceStatus(invoice.status),
      statusKey: invoice.status,
      amount: MoneyFormatter.format(invoice.total),
      rows: [
        ('Fournisseur', invoice.supplierName ?? '—'),
        ('Commande', invoice.orderNumber ?? '—'),
        ('Date', _date(invoice.invoicedAt)),
        ('Payé', MoneyFormatter.format(invoice.paidAmount)),
      ],
    );
  }

  String _date(DateTime value) => DateFormat('dd/MM/yyyy · HH:mm').format(value);

  bool _matchesLane(String lane) {
    if (_quarantine) return lane == 'quarantine';
    if (lane == 'quarantine') return false;
    return switch (_lane) {
      1 => lane == 'open',
      2 => lane == 'progress',
      3 => lane == 'completed',
      4 => lane == 'cancelled',
      _ => true,
    };
  }

  String _saleLane(_SaleRow sale) {
    final raw = sale.status.toLowerCase();
    if (raw == 'failed' || raw == 'retrying' || sale.filterStatus == 'failed') return 'quarantine';
    if (raw == 'voided' || raw == 'cancelled' || raw == 'merged') return 'cancelled';
    if (raw == 'completed' || raw == 'synced' || sale.filterStatus == 'completed') return 'completed';
    if (sale.isHold || raw == 'pending' || raw == 'held') return 'progress';
    return 'open';
  }

  String _purchaseLane(String status) => switch (status.toLowerCase()) {
        'cancelled' => 'cancelled',
        'completed' || 'received' => 'completed',
        'approved' || 'partially_received' || 'partial' => 'progress',
        _ => 'open',
      };

  String _invoiceLane(String status) => switch (status.toLowerCase()) {
        'cancelled' => 'cancelled',
        'paid' => 'completed',
        'partially_paid' => 'progress',
        _ => 'open',
      };

  String _orderStatus(String status) => switch (status.toLowerCase()) {
        'draft' => 'Brouillon',
        'submitted' => 'Soumise',
        'pending' => 'En attente',
        'approved' => 'Approuvée',
        'completed' => 'Terminée',
        'cancelled' => 'Annulée',
        'partial' => 'Partielle',
        _ => status,
      };

  String _invoiceStatus(String status) => switch (status.toLowerCase()) {
        'posted' => 'Comptabilisée',
        'partially_paid' => 'Partiellement payée',
        'paid' => 'Payée',
        'cancelled' => 'Annulée',
        _ => status,
      };

  void _open(String id) {
    if (_section == 0) {
      final sale = _venteRows.where((item) => item.id == id).firstOrNull;
      if (sale != null && sale.canOpenRemoteDetail) {
        _viewSale(sale);
        return;
      }
    }
    final wide = MediaQuery.sizeOf(context).width >= 980;
    setState(() => _selectedId = id);
    if (wide) return;
    final detail = _detail;
    if (detail == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: _DetailBody(
              detail: _Detail(
                title: detail.title,
                status: detail.status,
                statusKey: detail.statusKey,
                amount: detail.amount,
                currency: detail.currency,
                rows: detail.rows,
                lines: detail.lines,
                subtotal: detail.subtotal,
                itemCount: detail.itemCount,
                onModify: detail.onModify == null
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                        detail.onModify!();
                      },
                onAddArticles: detail.onAddArticles == null
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                        detail.onAddArticles!();
                      },
                onSplit: detail.onSplit == null
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                        detail.onSplit!();
                      },
                onPay: detail.onPay == null
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                        detail.onPay!();
                      },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final items = _items;
    final config = TerminalConfigRepository.instance.config;
    final place = config.deviceName.trim().isEmpty
        ? (config.brandName.trim().isEmpty ? 'Store' : config.brandName.trim())
        : config.deviceName.trim();

    return ColoredBox(
      color: AppColors.canvas,
      child: Column(
        children: [
          if (!config.canManageOrders)
            const SlaveModeBanner(message: 'Consultation seule — les achats sont gérés par le master.'),
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 20 : 14, 16, wide ? 20 : 14, 0),
            child: _OrdersChrome(
              search: _search,
              place: place,
              storeKey: _storeKey,
              lane: _quarantine ? -1 : _lane,
              quarantine: _quarantine,
              refreshing: _loading,
              section: _section,
              onStore: (value) => setState(() => _storeKey = value),
              onSearch: (_) => setState(() {}),
              onLane: (value) => setState(() {
                _lane = value;
                _quarantine = false;
                _selectedId = null;
              }),
              onQuarantine: () => setState(() {
                _quarantine = !_quarantine;
                _selectedId = null;
              }),
              onRefresh: _loading ? null : _load,
              onSection: (value) => setState(() {
                _section = value;
                _selectedId = null;
                _lane = 0;
                _quarantine = false;
              }),
            ),
          ),
          if (_sectionError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                ),
                child: Text(_sectionError!, style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.danger)),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: items.isEmpty
                              ? LayoutBuilder(
                                  builder: (context, constraints) => ListView(
                                    children: [
                                      SizedBox(
                                        height: constraints.maxHeight,
                                        child: const _Empty(),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.fromLTRB(wide ? 20 : 14, 12, wide ? 12 : 14, 20),
                                  itemCount: items.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    final sale = _section == 0
                                        ? _venteRows.where((row) => row.id == item.id).firstOrNull
                                        : null;
                                    final busy = sale != null && _docBusyId == sale.detailId;
                                    return AppOnce(
                                      id: 'order-${item.id}',
                                      child: _RowCard(
                                      item: item,
                                      selected: _selectedId == item.id,
                                      onTap: () => _open(item.id),
                                      onView: sale != null && sale.canOpenRemoteDetail
                                          ? () => _viewSale(sale)
                                          : null,
                                      onReceipt: sale != null && sale.canIssueDocs && !busy
                                          ? () => _createReceipt(sale)
                                          : null,
                                      onInvoice: sale != null && sale.canIssueDocs && !busy
                                          ? () => _createInvoice(sale)
                                          : null,
                                      onMerge: sale != null && sale.canMerge
                                          ? () => _mergeSale(sale)
                                          : null,
                                      onResume: sale != null && sale.canResume
                                          ? () => _resumeSale(sale)
                                          : null,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                      if (wide && _detail != null)
                        SizedBox(
                          width: 360,
                          child: _DetailPanel(detail: _detail!),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrdersChrome extends StatelessWidget {
  const _OrdersChrome({
    required this.search,
    required this.place,
    required this.storeKey,
    required this.lane,
    required this.quarantine,
    required this.refreshing,
    required this.section,
    required this.onStore,
    required this.onSearch,
    required this.onLane,
    required this.onQuarantine,
    required this.onRefresh,
    required this.onSection,
  });

  final TextEditingController search;
  final String place;
  final String storeKey;
  final int lane;
  final bool quarantine;
  final bool refreshing;
  final int section;
  final ValueChanged<String> onStore;
  final ValueChanged<String> onSearch;
  final ValueChanged<int> onLane;
  final VoidCallback onQuarantine;
  final VoidCallback? onRefresh;
  final ValueChanged<int> onSection;

  static const _lanes = ['All', 'Open', 'In Progress', 'Completed', 'Cancelled'];

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (section) {
      1 => 'Purchase orders',
      2 => 'Supplier invoices',
      _ => 'Manage and track all POS orders',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.cashierBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Orders',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppColors.brandInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.ibmPlexSans(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  _OutlineAction(
                    icon: Icons.warning_amber_rounded,
                    label: 'Quarantine',
                    selected: quarantine,
                    onPressed: onQuarantine,
                  ),
                  _OutlineAction(
                    icon: Icons.refresh_rounded,
                    label: 'Refresh',
                    busy: refreshing,
                    onPressed: onRefresh,
                  ),
                  PopupMenuButton<int>(
                    tooltip: 'More',
                    onSelected: onSection,
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 0, child: Text('POS orders')),
                      PopupMenuItem(value: 1, child: Text('Purchases')),
                      PopupMenuItem(value: 2, child: Text('Invoices')),
                    ],
                    child: const _OutlineIcon(icon: Icons.more_horiz),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _StoreField(place: place, value: storeKey, onChanged: onStore),
        const SizedBox(height: 10),
        TextField(
          controller: search,
          onChanged: onSearch,
          style: GoogleFonts.ibmPlexSans(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by order number, customer or waiter...',
            hintStyle: GoogleFonts.ibmPlexSans(color: AppColors.textMuted, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: _fieldBorder(AppColors.border),
            enabledBorder: _fieldBorder(AppColors.border),
            focusedBorder: _fieldBorder(AppColors.cashierBlue),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _lanes.length; i++)
                Expanded(
                  child: Material(
                    color: lane == i ? AppColors.brand100 : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      onTap: () => onLane(i),
                      borderRadius: BorderRadius.circular(9),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Text(
                          _lanes[i],
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 13,
                            fontWeight: lane == i ? FontWeight.w700 : FontWeight.w500,
                            color: lane == i ? AppColors.brandInk : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

OutlineInputBorder _fieldBorder(Color color) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );
}

class _StoreField extends StatelessWidget {
  const _StoreField({required this.place, required this.value, required this.onChanged});

  final String place;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
          style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All stores')),
            DropdownMenuItem(value: 'current', child: Text(place)),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.brandInk;
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: selected ? AppColors.warning : AppColors.surface,
        side: BorderSide(color: selected ? AppColors.warning : AppColors.borderStrong),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: busy
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandInk),
            )
          : Icon(icon, size: 16),
      label: Text(label, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class _OutlineIcon extends StatelessWidget {
  const _OutlineIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Icon(icon, size: 18, color: AppColors.brandInk),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.item,
    required this.selected,
    required this.onTap,
    this.onView,
    this.onReceipt,
    this.onInvoice,
    this.onMerge,
    this.onResume,
  });

  final _ListItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onView;
  final VoidCallback? onReceipt;
  final VoidCallback? onInvoice;
  final VoidCallback? onMerge;
  final VoidCallback? onResume;

  bool get _hasActions =>
      onView != null || onReceipt != null || onInvoice != null || onMerge != null || onResume != null;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.statusKey);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: AppMotion.resolve(context, AppMotion.micro),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.brand600 : AppColors.border, width: selected ? 1.4 : 1),
          color: selected ? AppColors.brand50.withValues(alpha: 0.55) : AppColors.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, _hasActions ? 8 : 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, size: 18, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary)),
                          const SizedBox(height: 3),
                          Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 3),
                          Text(item.meta, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          MoneyFormatter.format(item.amount, currencyCode: item.currency),
                          style: GoogleFonts.ibmPlexMono(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.brandInk),
                        ),
                        const SizedBox(height: 6),
                        _Status(label: item.status, status: item.statusKey),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_hasActions)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (onView != null)
                      _SaleActionChip(label: 'Voir', icon: Icons.visibility_outlined, onPressed: onView!),
                    if (onReceipt != null)
                      _SaleActionChip(label: 'Reçu', icon: Icons.receipt_outlined, onPressed: onReceipt!),
                    if (onInvoice != null)
                      _SaleActionChip(label: 'Facture', icon: Icons.description_outlined, onPressed: onInvoice!),
                    if (onMerge != null)
                      _SaleActionChip(label: 'Fusionner', icon: Icons.merge_type, onPressed: onMerge!),
                    if (onResume != null)
                      _SaleActionChip(label: 'Reprendre', icon: Icons.play_arrow_outlined, onPressed: onResume!),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SaleActionChip extends StatelessWidget {
  const _SaleActionChip({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fieldFill,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.brandInk),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.brandInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.detail});

  final _Detail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _DetailBody(detail: detail),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final _Detail detail;

  @override
  Widget build(BuildContext context) {
    final currency = detail.currency;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text(detail.title, style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w700))),
            _Status(label: detail.status, status: detail.statusKey),
          ],
        ),
        if (detail.onModify != null ||
            detail.onAddArticles != null ||
            detail.onSplit != null ||
            detail.onPay != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (detail.onModify != null)
                OutlinedButton.icon(
                  onPressed: detail.onModify,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier'),
                ),
              if (detail.onAddArticles != null)
                OutlinedButton.icon(
                  onPressed: detail.onAddArticles,
                  icon: const Icon(Icons.add_shopping_cart_outlined, size: 16),
                  label: const Text('Ajouter articles'),
                ),
              if (detail.onSplit != null)
                OutlinedButton.icon(
                  onPressed: detail.onSplit,
                  icon: const Icon(Icons.call_split, size: 16),
                  label: const Text('Séparer'),
                ),
              if (detail.onPay != null)
                FilledButton.icon(
                  onPressed: detail.onPay,
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('Payer'),
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total', style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(detail.amount, style: GoogleFonts.ibmPlexMono(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.brandInk)),
              if (detail.itemCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${detail.itemCount} article${detail.itemCount > 1 ? 's' : ''}',
                  style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        if (detail.lines.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Articles',
            style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          for (final line in detail.lines)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.name,
                          style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${line.quantity} × ${MoneyFormatter.format(line.unitPrice, currencyCode: currency)}',
                          style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    MoneyFormatter.format(line.lineTotal, currencyCode: currency),
                    style: GoogleFonts.ibmPlexMono(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.brandInk),
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('Sous-total', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary)),
                    const Spacer(),
                    Text(
                      MoneyFormatter.format(detail.subtotal, currencyCode: currency),
                      style: GoogleFonts.ibmPlexMono(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('Total', style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const Spacer(),
                    Text(
                      detail.amount,
                      style: GoogleFonts.ibmPlexMono(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.brandInk),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else if (detail.onModify != null) ...[
          const SizedBox(height: 14),
          Text(
            'Aucun détail d’article disponible pour cette commande.',
            style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: 14),
        for (final row in detail.rows) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(row.$1, style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary)),
                ),
                Flexible(
                  child: Text(
                    row.$2,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}


class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: AppColors.brand100,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.receipt_long_outlined, color: AppColors.brandInk, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          'No data available',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

Color _statusColor(String status) => switch (status.toLowerCase()) {
      'completed' || 'approved' || 'paid' || 'synced' => AppColors.success,
      'pending' || 'held' || 'submitted' || 'partial' || 'partially_paid' || 'retrying' || 'draft' => AppColors.warning,
      'cancelled' || 'failed' || 'conflict' || 'voided' => AppColors.danger,
      'merged' => AppColors.brand600,
      _ => AppColors.brand600,
    };

class _ListItem {
  const _ListItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.amount,
    required this.currency,
    required this.status,
    required this.statusKey,
    this.kind = 'sale',
  });

  final String id;
  final String title;
  final String subtitle;
  final String meta;
  final int amount;
  final String currency;
  final String status;
  final String statusKey;
  final String kind;

  IconData get icon => switch (kind) {
        'hold' => Icons.schedule_outlined,
        'purchase' => Icons.local_shipping_outlined,
        'invoice' => Icons.description_outlined,
        _ => Icons.receipt_long_outlined,
      };
}

class _Detail {
  const _Detail({
    required this.title,
    required this.status,
    required this.statusKey,
    required this.amount,
    required this.rows,
    this.currency = 'FBU',
    this.lines = const [],
    this.subtotal = 0,
    this.itemCount = 0,
    this.onModify,
    this.onAddArticles,
    this.onSplit,
    this.onPay,
  });

  final String title;
  final String status;
  final String statusKey;
  final String amount;
  final String currency;
  final List<(String, String)> rows;
  final List<_LineDetail> lines;
  final int subtotal;
  final int itemCount;
  final VoidCallback? onModify;
  final VoidCallback? onAddArticles;
  final VoidCallback? onSplit;
  final VoidCallback? onPay;
}

class _LineDetail {
  const _LineDetail({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final int quantity;
  final int unitPrice;

  int get lineTotal => unitPrice * quantity;
}

class _SaleRow {
  const _SaleRow({
    required this.id,
    required this.reference,
    required this.total,
    required this.paid,
    required this.outstanding,
    required this.method,
    required this.status,
    required this.createdAt,
    required this.currency,
    this.serverId,
    this.customerName,
    this.note,
    this.itemCount = 0,
    this.isHold = false,
    this.isRemote = false,
    this.paymentStatusRaw,
    this.lines = const [],
  });

  factory _SaleRow.fromLocal(Map<String, dynamic> row) {
    String currency = 'FBU';
    var lines = const <_LineDetail>[];
    try {
      final payload = jsonDecode(row['payload_json'] as String? ?? '{}') as Map<String, dynamic>;
      currency = payload['currency']?.toString() ?? currency;
      final items = payload['items'];
      if (items is List) {
        lines = items.whereType<Map>().map((raw) {
          final item = Map<String, dynamic>.from(raw);
          final name = item['product_name']?.toString() ??
              item['name']?.toString() ??
              item['sku']?.toString() ??
              'Article';
          return _LineDetail(
            name: name,
            quantity: (item['quantity'] as num?)?.toInt() ?? 1,
            unitPrice: (item['unit_price'] as num?)?.toInt() ?? 0,
          );
        }).toList();
      }
    } catch (_) {}
    return _SaleRow(
      id: row['id'] as String,
      serverId: row['server_id']?.toString(),
      reference: row['reference'] as String? ?? 'Vente',
      total: (row['total'] as num?)?.toInt() ?? 0,
      paid: (row['paid_amount'] as num?)?.toInt() ?? 0,
      outstanding: (row['outstanding_amount'] as num?)?.toInt() ?? 0,
      method: row['method'] as String? ?? 'cash',
      status: row['sync_status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      currency: currency,
      lines: lines,
      itemCount: lines.fold<int>(0, (sum, line) => sum + line.quantity),
    );
  }

  factory _SaleRow.fromHold(Map<String, dynamic> row) {
    final held = PosHeldSale.fromLocalJson(row);
    final currency = TerminalConfigRepository.instance.config.currencyCode;
    return _SaleRow(
      id: held.id,
      serverId: held.serverId,
      reference: held.label,
      total: held.total,
      paid: 0,
      outstanding: held.total,
      method: 'held',
      status: 'held',
      createdAt: held.heldAt,
      currency: currency,
      customerName: held.customer?.displayLabel,
      note: held.note,
      itemCount: held.itemCount,
      isHold: true,
      paymentStatusRaw: 'unpaid',
      lines: held.lines
          .map(
            (line) => _LineDetail(
              name: line.displayName,
              quantity: line.quantity,
              unitPrice: line.unitPrice,
            ),
          )
          .toList(),
    );
  }

  factory _SaleRow.fromRemote(Map<String, dynamic> row) {
    final customer = row['customer'];
    final customerName = customer is Map
        ? customer['name']?.toString()
        : row['customer_name']?.toString();
    final items = row['items'];
    final lines = items is List
        ? items.whereType<Map>().map((raw) {
            final item = Map<String, dynamic>.from(raw);
            return _LineDetail(
              name: item['product_name']?.toString() ??
                  item['name']?.toString() ??
                  item['product_sku']?.toString() ??
                  'Article',
              quantity: (item['quantity'] as num?)?.toInt() ?? 1,
              unitPrice: (item['unit_price'] as num?)?.toInt() ?? 0,
            );
          }).toList()
        : const <_LineDetail>[];
    final payments = row['payments'];
    var method = row['payment_method']?.toString() ?? row['method']?.toString() ?? 'cash';
    if (payments is List && payments.isNotEmpty) {
      final first = payments.first;
      if (first is Map) {
        method = first['method']?.toString() ?? first['payment_method']?.toString() ?? method;
      }
    }
    return _SaleRow(
      id: row['id']?.toString() ?? '',
      serverId: row['id']?.toString(),
      reference: row['reference']?.toString() ?? 'Vente',
      total: (row['total'] as num?)?.toInt() ?? 0,
      paid: (row['paid_amount'] as num?)?.toInt() ?? 0,
      outstanding: (row['outstanding_amount'] as num?)?.toInt() ?? 0,
      method: method,
      status: row['status']?.toString() ?? 'completed',
      createdAt: DateTime.tryParse(
            row['completed_at']?.toString() ?? row['created_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
      currency: row['currency']?.toString() ??
          TerminalConfigRepository.instance.config.currencyCode,
      customerName: customerName,
      note: row['notes']?.toString(),
      itemCount: lines.fold<int>(0, (sum, line) => sum + line.quantity),
      isRemote: true,
      paymentStatusRaw: row['payment_status']?.toString(),
      lines: lines,
    );
  }

  final String id;
  final String? serverId;
  final String reference;
  final int total;
  final int paid;
  final int outstanding;
  final String method;
  final String status;
  final DateTime createdAt;
  final String currency;
  final String? customerName;
  final String? note;
  final int itemCount;
  final bool isHold;
  final bool isRemote;
  final String? paymentStatusRaw;
  final List<_LineDetail> lines;

  String? get detailId {
    if (isRemote) return id;
    final remote = serverId;
    if (remote != null && remote.isNotEmpty) return remote;
    return null;
  }

  String get resumeId => serverId?.isNotEmpty == true ? serverId! : id;

  String? get mergeId {
    if (isHold) return serverId?.isNotEmpty == true ? serverId : null;
    if (isRemote && status.toLowerCase() == 'pending') return id;
    return null;
  }

  bool get canOpenRemoteDetail => detailId != null && !isHold;

  bool get canIssueDocs {
    final id = detailId;
    if (id == null || id.isEmpty) return false;
    final key = status.toLowerCase();
    return key == 'completed' || key == 'synced';
  }

  bool get canMerge => mergeId != null;

  bool get canResume => isHold || (isRemote && status.toLowerCase() == 'pending');

  String get methodLabel => switch (method) {
        'held' => 'Non payée',
        'cash' => 'Espèces',
        'card' => 'Carte',
        'credit' => 'Crédit',
        'mobile_money' => 'Mobile money',
        'partial' => 'Partiel',
        _ => method,
      };

  String get subtitle {
    if (isHold) {
      final parts = <String>[
        'Commande en attente',
        if (itemCount > 0) '$itemCount art.',
        if (customerName != null && customerName!.isNotEmpty) customerName!,
      ];
      return parts.join(' · ');
    }
    final parts = <String>[
      methodLabel,
      if (customerName != null && customerName!.isNotEmpty) customerName!,
      if (isRemote) 'Serveur',
    ];
    return parts.join(' · ');
  }

  String get statusLabel => switch (status.toLowerCase()) {
        'held' => 'En attente',
        'synced' => 'Terminée',
        'completed' => 'Terminée',
        'pending' => isRemote || isHold ? 'En attente' : 'À synchroniser',
        'draft' => 'Brouillon',
        'voided' => 'Annulée',
        'merged' => 'Fusionnée',
        'failed' || 'retrying' => 'À renvoyer',
        _ => status,
      };

  String get filterStatus {
    if (isRemote) return status.toLowerCase();
    return switch (status.toLowerCase()) {
      'held' => 'pending',
      'synced' => 'completed',
      'failed' || 'retrying' => 'failed',
      _ => 'pending',
    };
  }

  String get paymentStatus {
    final raw = paymentStatusRaw?.toLowerCase();
    if (raw != null && raw.isNotEmpty) return raw;
    if (isHold || (paid <= 0 && outstanding > 0)) return 'on_credit';
    if (outstanding > 0) return 'partial';
    if (method == 'credit') return 'credit';
    return 'paid';
  }

  bool matchesPayment(String filter) {
    final key = filter.toLowerCase();
    final current = paymentStatus.toLowerCase();
    if (current == key) return true;
    if (key == 'unpaid') {
      return current == 'on_credit' || current == 'unpaid' || (paid <= 0 && outstanding > 0);
    }
    if (key == 'credit') {
      return current == 'credit' || current == 'on_credit' || method == 'credit';
    }
    if (key == 'on_credit') {
      return current == 'on_credit' || current == 'unpaid' || current == 'credit';
    }
    return false;
  }

  String get syncLabel => statusLabel;
}


ReceiptPrintPayload? _receiptPayload(dynamic result) {
  if (result is ReceiptPrintPayload) return result;
  if (result is Map) {
    final map = Map<String, dynamic>.from(result);
    final payload = map['payload'] ??
        (map['data'] is Map ? (map['data'] as Map)['payload'] : null) ??
        map;
    if (payload is Map) {
      try {
        return ReceiptPrintPayload.fromJson(Map<String, dynamic>.from(payload));
      } catch (_) {}
    }
  }
  return null;
}
