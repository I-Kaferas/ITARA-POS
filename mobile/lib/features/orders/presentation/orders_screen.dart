import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../sync/offline_store.dart';
import '../../../sync/sync_engine.dart';
import '../../../sync/sync_models.dart';
import '../../pos/data/pos_api_service.dart';
import '../../pos/domain/pos_models.dart';
import '../../pos/presentation/customer_display_launcher.dart';
import '../../pos/presentation/widgets/pos_merge_sheet.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import '../../pos/services/pos_pending_intent.dart';
import '../../receipt/domain/receipt_models.dart';
import '../../receipt/services/receipt_print_service.dart';
import '../data/orders_api_service.dart';
import '../domain/order_models.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

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
  String _waiter = 'all';
  String? _status;
  String? _payment;
  DateTime? _from;
  DateTime? _to;
  String? _selectedId;
  Map<String, String> _catalogNames = const {};
  String _boundStoreId = '';

  @override
  void initState() {
    super.initState();
    _boundStoreId = TerminalConfigRepository.instance.config.storeId;
    OfflineStore.instance.holdsRevision.addListener(_onHoldsChanged);
    TerminalConfigRepository.instance.addListener(_onStoreChanged);
    _load();
  }

  @override
  void dispose() {
    OfflineStore.instance.holdsRevision.removeListener(_onHoldsChanged);
    TerminalConfigRepository.instance.removeListener(_onStoreChanged);
    _search.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    final storeId = TerminalConfigRepository.instance.config.storeId;
    if (storeId == _boundStoreId) return;
    _boundStoreId = storeId;
    _selectedId = null;
    _sales = [];
    _holds = [];
    _orders = [];
    _invoices = [];
    _load();
  }

  void _onHoldsChanged() {
    if (!mounted) return;
    _refreshHolds();
  }

  Future<void> _refreshHolds() async {
    final storeId = TerminalConfigRepository.instance.config.storeId;
    final holds = OfflineStore.instance.holdsForStore(await OfflineStore.instance.loadLocalHolds(), storeId);
    if (!mounted || TerminalConfigRepository.instance.config.storeId != storeId) return;
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
    if (_section == 0) {
      await _loadLocalSales();
    } else if (_section == 1) {
      await _loadOrders();
    } else {
      await _loadInvoices();
    }
    if (mounted) setState(() => _loading = false);
  }

  bool get _isAdmin => TerminalConfigRepository.instance.config.isAdmin;

  String get _cashierId => TerminalConfigRepository.instance.config.cashierId.trim();

  List<String> get _waiterNames {
    final names = <String>{};
    for (final sale in _venteRows) {
      final name = sale.cashierName?.trim() ?? '';
      if (name.isNotEmpty) names.add(name);
    }
    final list = names.toList()..sort();
    return list;
  }

  bool get _canReachNetwork {
    final snap = SyncEngine.instance.snapshot;
    if (snap.masterReachable || snap.cloudReachable) return true;
    return switch (snap.connectivity) {
      ConnectivityState.online ||
      ConnectivityState.localAvailable ||
      ConnectivityState.cloudAvailable ||
      ConnectivityState.syncing =>
        true,
      _ => false,
    };
  }

  Future<void> _loadLocalSales() async {
    final config = TerminalConfigRepository.instance.config;
    final storeId = config.storeId;
    final sales = await OfflineStore.instance.listLocalSales(storeId: storeId);
    final holds = OfflineStore.instance.holdsForStore(await OfflineStore.instance.loadLocalHolds(), storeId);
    final names = await OfflineStore.instance.productNamesById(storeId: storeId);
    if (!mounted || TerminalConfigRepository.instance.config.storeId != storeId) return;
    // Offline-first: paint SQLite immediately; never block the UI on the network.
    setState(() {
      _catalogNames = names;
      _sales = sales.map((row) => _SaleRow.fromLocal(row, names)).toList();
      _holds = holds.map(_SaleRow.fromHold).where((sale) => sale.total > 0 || sale.reference.isNotEmpty).toList();
      if (!_isAdmin) {
        final selfName = config.cashierName.trim();
        if (selfName.isNotEmpty) _waiter = selfName;
      }
    });
    if (_canReachNetwork) {
      unawaited(_mergeRemoteSales(storeId: storeId, local: sales, names: names));
    }
  }

  Future<void> _mergeRemoteSales({
    required String storeId,
    required List<Map<String, dynamic>> local,
    required Map<String, String> names,
  }) async {
    final remote = await _remoteSales(local);
    if (!mounted || remote.isEmpty) return;
    if (TerminalConfigRepository.instance.config.storeId != storeId) return;
    setState(() {
      _sales = [
        ...local.map((row) => _SaleRow.fromLocal(row, names)),
        ...remote,
      ];
    });
  }

  Future<List<_SaleRow>> _remoteSales(List<Map<String, dynamic>> local) async {
    if (!_canReachNetwork) return const [];
    try {
      final config = TerminalConfigRepository.instance.config;
      final remote = await _posApi.fetchSales(
        processedBy: config.isAdmin || config.cashierId.trim().isEmpty ? null : config.cashierId.trim(),
      );
      final seen = <String>{};
      for (final row in local) {
        final id = row['id']?.toString() ?? '';
        final serverId = row['server_id']?.toString() ?? '';
        final reference = row['reference']?.toString() ?? '';
        if (id.isNotEmpty) seen.add(id);
        if (serverId.isNotEmpty) seen.add(serverId);
        if (reference.isNotEmpty) seen.add(reference);
      }
      return remote
          .where((row) {
            final id = row['id']?.toString() ?? '';
            final reference = row['reference']?.toString() ?? '';
            if (id.isNotEmpty && seen.contains(id)) return false;
            if (reference.isNotEmpty && seen.contains(reference)) return false;
            return id.isNotEmpty;
          })
          .map(_SaleRow.fromSummary)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _loadOrders() async {
    final storeId = TerminalConfigRepository.instance.config.storeId;
    try {
      final orders = await _api.fetchOrders(
        status: _section == 1 ? _status : null,
        search: _search.text.trim(),
        from: _from,
        to: _to,
      );
      if (!mounted || TerminalConfigRepository.instance.config.storeId != storeId) return;
      setState(() {
        _orders = orders.items;
        _ordersError = null;
      });
    } catch (error) {
      if (!mounted || TerminalConfigRepository.instance.config.storeId != storeId) return;
      setState(() => _ordersError = _networkMessage(error));
    }
  }

  Future<void> _loadInvoices() async {
    final storeId = TerminalConfigRepository.instance.config.storeId;
    try {
      final invoices = await _api.fetchInvoices(
        status: _section == 2 ? _status : null,
        search: _search.text.trim(),
        from: _from,
        to: _to,
      );
      if (!mounted || TerminalConfigRepository.instance.config.storeId != storeId) return;
      setState(() {
        _invoices = invoices.items;
        _invoicesError = null;
      });
    } catch (error) {
      if (!mounted || TerminalConfigRepository.instance.config.storeId != storeId) return;
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

  bool _belongsToCurrentCashier(_SaleRow sale) {
    final me = _cashierId;
    if (me.isEmpty) {
      final myName = TerminalConfigRepository.instance.config.cashierName.trim();
      if (myName.isEmpty) return true;
      return (sale.cashierName ?? '').trim() == myName;
    }
    final owner = (sale.cashierId ?? '').trim();
    if (owner.isNotEmpty) return owner == me;
    final myName = TerminalConfigRepository.instance.config.cashierName.trim();
    if (myName.isEmpty) return true;
    return (sale.cashierName ?? '').trim() == myName;
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
    var rows = [...holds, ..._sales];
    if (!_isAdmin) {
      rows = rows.where(_belongsToCurrentCashier).toList();
    }
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
          .where((sale) => matches('${sale.reference} ${sale.method} ${sale.status} ${sale.statusLabel} ${sale.customerName} ${sale.cashierName} ${sale.serviceMode}'))
          .where((sale) => _inRange(sale.createdAt))
          .where((sale) => _status == null || sale.filterStatus == _status)
          .where((sale) => _payment == null || sale.matchesPayment(_payment!))
          .where((sale) => _waiter == 'all' || (sale.cashierName ?? '').trim() == _waiter)
          .where((sale) => _matchesLane(_saleLane(sale)))
          .map((sale) => _ListItem(
                id: sale.id,
                title: sale.reference,
                meta: DateFormat('dd/MM HH:mm').format(sale.createdAt),
                amount: sale.total,
                currency: sale.currency,
                status: _laneLabel(_saleLane(sale)),
                statusKey: sale.status,
                badge: sale.serviceBadge,
                secondary: sale.secondaryReference,
                customer: _person(sale.customerName),
                servedBy: sale.cashierName?.trim() ?? '',
                payment: sale.paymentColumn,
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
                meta: DateFormat('dd/MM HH:mm').format(order.createdAt),
                amount: order.total,
                currency: order.currencyCode,
                status: _laneLabel(_purchaseLane(order.status)),
                statusKey: order.status,
                customer: _person(order.supplierName),
                servedPrefix: 'Warehouse',
                servedBy: order.warehouseName?.trim() ?? '',
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
              meta: DateFormat('dd/MM HH:mm').format(invoice.invoicedAt),
              amount: invoice.total,
              currency: 'FBU',
              status: _laneLabel(_invoiceLane(invoice.status)),
              statusKey: invoice.status,
              customer: _person(invoice.supplierName),
              servedPrefix: 'Order',
              servedBy: invoice.orderNumber?.trim() ?? '',
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

  Future<void> _printKitchenTicket(_SaleRow sale) async {
    if (sale.lines.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun article à imprimer')),
      );
      return;
    }
    final doc = pw.Document();
    final date = DateFormat('dd/MM/yyyy HH:mm').format(sale.createdAt);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              'BON DE CUISINE',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(sale.reference, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
            pw.Text(date, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
            if ((sale.customerName ?? '').trim().isNotEmpty)
              pw.Text('Client: ${sale.customerName}', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 0.6),
            ...sale.lines.map(
              (line) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Text('${line.quantity}x  ${line.name}', style: const pw.TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(await doc.save()),
      name: 'kitchen-${sale.reference}',
    );
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
        status: _laneLabel(_saleLane(sale)),
        statusKey: sale.status,
        paymentLabel: sale.paymentColumn == '—' ? '' : sale.paymentColumn,
        whenLabel: DateFormat('dd/MM HH:mm').format(sale.createdAt),
        serviceLabel: sale.serviceBadge ?? (sale.isHold ? 'Hold' : ''),
        customer: _person(sale.customerName),
        servedBy: (sale.cashierName ?? '').trim().isEmpty ? '—' : sale.cashierName!.trim(),
        remaining: sale.outstanding,
        amount: MoneyFormatter.format(sale.total, currencyCode: sale.currency),
        currency: sale.currency,
        lines: sale.lines,
        subtotal: sale.subtotalAmount > 0
            ? sale.subtotalAmount
            : sale.lines.fold<int>(0, (sum, line) => sum + line.lineTotal),
        tax: sale.taxTotal,
        totalAmount: sale.total,
        amountDue: sale.outstanding,
        payments: sale.resolvedPayments,
        itemCount: sale.lines.length,
        rows: [
          if (sale.note != null && sale.note!.isNotEmpty) ('Note', sale.note!),
        ],
        onModify: sale.isHold ? () => _openHoldOnPos(sale.id) : null,
        onAddArticles: sale.isHold ? () => _openHoldOnPos(sale.id, action: PosHoldAction.addArticles) : null,
        onSplit: canSplit ? () => _openHoldOnPos(sale.id, action: PosHoldAction.split) : null,
        onPay: sale.isHold ? () => _openHoldOnPos(sale.id, action: PosHoldAction.pay) : null,
        onPrintInvoice: sale.canIssueDocs ? () => _createInvoice(sale) : null,
        onPrintKitchen: () => _printKitchenTicket(sale),
      );
    }
    if (_section == 1) {
      final order = _orders.where((item) => item.id == id).firstOrNull;
      if (order == null) return null;
      return _Detail(
        title: order.orderNumber,
        status: _laneLabel(_purchaseLane(order.status)),
        statusKey: order.status,
        whenLabel: DateFormat('dd/MM HH:mm').format(order.createdAt),
        customer: _person(order.supplierName),
        servedBy: (order.warehouseName ?? '').trim().isEmpty ? '—' : order.warehouseName!.trim(),
        remaining: order.total,
        amount: MoneyFormatter.format(order.total, currencyCode: order.currencyCode),
        currency: order.currencyCode,
        subtotal: order.total,
        totalAmount: order.total,
        amountDue: order.total,
        rows: [
          if (order.notes != null && order.notes!.isNotEmpty) ('Notes', order.notes!),
        ],
      );
    }
    final invoice = _invoices.where((item) => item.id == id).firstOrNull;
    if (invoice == null) return null;
    return _Detail(
      title: invoice.invoiceNumber,
      status: _laneLabel(_invoiceLane(invoice.status)),
      statusKey: invoice.status,
      whenLabel: DateFormat('dd/MM HH:mm').format(invoice.invoicedAt),
      customer: _person(invoice.supplierName),
      servedBy: (invoice.orderNumber ?? '').trim().isEmpty ? '—' : invoice.orderNumber!.trim(),
      remaining: (invoice.total - invoice.paidAmount).clamp(0, invoice.total),
      amount: MoneyFormatter.format(invoice.total),
      subtotal: invoice.total,
      totalAmount: invoice.total,
      amountDue: (invoice.total - invoice.paidAmount).clamp(0, invoice.total),
      rows: const [],
    );
  }

  String _person(String? value) {
    final name = value?.trim() ?? '';
    return name.isEmpty ? '—' : name;
  }

  String _laneLabel(String lane) => switch (lane) {
        'open' => 'Open',
        'progress' => 'In Progress',
        'completed' => 'Completed',
        'cancelled' => 'Cancelled',
        'quarantine' => 'Quarantine',
        _ => lane,
      };

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

  Future<void> _open(String id) async {
    setState(() => _selectedId = id);
    if (!mounted) return;
    final detail = _detail;
    if (detail == null) return;
    final narrow = MediaQuery.sizeOf(context).width < 700;
    if (narrow) {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          builder: (pageContext) => _OrderDetailPage(detail: detail),
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        backgroundColor: PosUi.deskPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: _DetailBody(
              detail: detail,
              onClose: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
              onModify: detail.onModify == null
                  ? null
                  : () {
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                      detail.onModify!();
                    },
              onAddArticles: detail.onAddArticles == null
                  ? null
                  : () {
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                      detail.onAddArticles!();
                    },
              onSplit: detail.onSplit == null
                  ? null
                  : () {
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                      detail.onSplit!();
                    },
              onPay: detail.onPay == null
                  ? null
                  : () {
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                      detail.onPay!();
                    },
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

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: PosUi.deskCard,
        popupMenuTheme: PopupMenuThemeData(
          color: PosUi.deskCard,
          textStyle: AppTypography.text(color: PosUi.deskText, fontSize: 14),
        ),
      ),
      child: ColoredBox(
      color: PosUi.deskNight,
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
              waiter: _waiter,
              waiters: _waiterNames,
              waiterFilterEnabled: _isAdmin,
              lane: _quarantine ? -1 : _lane,
              quarantine: _quarantine,
              refreshing: _loading,
              section: _section,
              onStore: (value) => setState(() => _storeKey = value),
              onWaiter: (value) => setState(() => _waiter = value),
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
              onPreviewDisplay: () => CustomerDisplayLauncher.open(context),
              onSection: (value) {
                setState(() {
                  _section = value;
                  _selectedId = null;
                  _lane = 0;
                  _quarantine = false;
                  final selfName = TerminalConfigRepository.instance.config.cashierName.trim();
                  _waiter = !_isAdmin && selfName.isNotEmpty ? selfName : 'all';
                });
                _load();
              },
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
                child: Text(_sectionError!, style: AppTypography.text(fontSize: 12, color: AppColors.danger)),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: PosUi.deskAccent))
                : Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(wide ? 20 : 14, 12, wide ? 12 : 14, 16),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final tableWidth = constraints.maxWidth < 760 ? 920.0 : constraints.maxWidth;
                              return RefreshIndicator(
                                color: PosUi.deskAccent,
                                onRefresh: _load,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: tableWidth,
                                    height: constraints.maxHeight,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: PosUi.deskPanel,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: PosUi.deskLine),
                                      ),
                                      child: Column(
                                        children: [
                                          const _OrdersTableHeader(),
                                          Expanded(
                                            child: items.isEmpty
                                                ? ListView(
                                                    children: [
                                                      SizedBox(
                                                        height: constraints.maxHeight - 52,
                                                        child: const _Empty(),
                                                      ),
                                                    ],
                                                  )
                                                : ListView.separated(
                                                    itemCount: items.length,
                                                    separatorBuilder: (_, _) => Divider(height: 1, color: PosUi.deskLine),
                                                    itemBuilder: (context, index) {
                                                      final item = items[index];
                                                      final sale = _section == 0
                                                          ? _venteRows.where((row) => row.id == item.id).firstOrNull
                                                          : null;
                                                      final busy = _docBusyId != null && sale?.detailId == _docBusyId;
                                                      return _OrderTableRow(
                                                        item: item,
                                                        selected: _selectedId == item.id,
                                                        busy: busy,
                                                        onTap: () => _open(item.id),
                                                        onView: () => _open(item.id),
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
                                                      );
                                                    },
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
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

class _OrdersChrome extends StatelessWidget {
  const _OrdersChrome({
    required this.search,
    required this.place,
    required this.storeKey,
    required this.waiter,
    required this.waiters,
    this.waiterFilterEnabled = true,
    required this.lane,
    required this.quarantine,
    required this.refreshing,
    required this.section,
    required this.onStore,
    required this.onWaiter,
    required this.onSearch,
    required this.onLane,
    required this.onQuarantine,
    required this.onRefresh,
    required this.onPreviewDisplay,
    required this.onSection,
  });

  final TextEditingController search;
  final String place;
  final String storeKey;
  final String waiter;
  final List<String> waiters;
  final bool waiterFilterEnabled;
  final int lane;
  final bool quarantine;
  final bool refreshing;
  final int section;
  final ValueChanged<String> onStore;
  final ValueChanged<String> onWaiter;
  final ValueChanged<String> onSearch;
  final ValueChanged<int> onLane;
  final VoidCallback onQuarantine;
  final VoidCallback? onRefresh;
  final VoidCallback onPreviewDisplay;
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: PosUi.deskAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: PosUi.deskInk, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Orders',
                    style: AppTypography.text(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: PosUi.deskText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.text(fontSize: 13, color: PosUi.deskMuted),
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
                    icon: Icons.monitor_outlined,
                    label: 'Preview Customer display',
                    onPressed: () {
                      onPreviewDisplay();
                    },
                  ),
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
                    color: PosUi.deskCard,
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
        Row(
          children: [
            Expanded(
              child: _FilterMenu(
                icon: Icons.person_outline,
                value: waiterFilterEnabled
                    ? (waiters.contains(waiter) || waiter == 'all' ? waiter : 'all')
                    : (waiter == 'all' && waiters.isNotEmpty ? waiters.first : waiter),
                items: waiterFilterEnabled
                    ? [
                        const DropdownMenuItem(value: 'all', child: Text('All waiters')),
                        for (final name in waiters) DropdownMenuItem(value: name, child: Text(name)),
                      ]
                    : [
                        DropdownMenuItem(
                          value: waiter == 'all' && waiters.isNotEmpty ? waiters.first : waiter,
                          child: Text(waiter == 'all' ? 'Mes commandes' : waiter),
                        ),
                      ],
                onChanged: waiterFilterEnabled ? onWaiter : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FilterMenu(
                icon: Icons.storefront_outlined,
                value: storeKey,
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All stores')),
                  DropdownMenuItem(value: 'current', child: Text(place)),
                ],
                onChanged: onStore,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: search,
          onChanged: onSearch,
          style: AppTypography.text(fontSize: 14, color: PosUi.deskText),
          cursorColor: PosUi.deskAccent,
          decoration: InputDecoration(
            hintText: 'Search by order number, customer or waiter...',
            hintStyle: AppTypography.text(color: PosUi.deskMuted, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: PosUi.deskMuted, size: 20),
            filled: true,
            fillColor: PosUi.deskField,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: _fieldBorder(PosUi.deskLine),
            enabledBorder: _fieldBorder(PosUi.deskLine),
            focusedBorder: _fieldBorder(PosUi.deskAccent),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: PosUi.deskCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PosUi.deskLine),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 640;
              final tabs = [
                for (var i = 0; i < _lanes.length; i++)
                  _LaneTab(
                    label: _lanes[i],
                    selected: lane == i,
                    onTap: () => onLane(i),
                    expanded: !compact,
                  ),
              ];
              if (compact) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: tabs),
                );
              }
              return Row(children: tabs);
            },
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

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PosUi.deskField,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(icon, size: 18, color: PosUi.deskMuted),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                canvasColor: PosUi.deskCard,
                textTheme: Theme.of(context).textTheme.apply(
                  bodyColor: PosUi.deskText,
                  displayColor: PosUi.deskText,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  isExpanded: true,
                  dropdownColor: PosUi.deskCard,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: PosUi.deskMuted),
                  style: AppTypography.text(fontSize: 14, fontWeight: FontWeight.w600, color: PosUi.deskText),
                  items: items,
                  onChanged: onChanged == null
                      ? null
                      : (next) {
                          if (next != null) onChanged!(next);
                        },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LaneTab extends StatelessWidget {
  const _LaneTab({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.expanded,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tab = Material(
      color: selected ? PosUi.deskRaised : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: expanded ? 8 : 16, vertical: 11),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.text(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? PosUi.deskText : PosUi.deskMuted,
            ),
          ),
        ),
      ),
    );
    if (expanded) return Expanded(child: tab);
    return tab;
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
    final foreground = selected ? PosUi.deskInk : PosUi.deskText;
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: selected ? AppColors.warning : Colors.transparent,
        side: BorderSide(color: selected ? AppColors.warning : PosUi.deskLine),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: PosUi.deskAccent),
            )
          : Icon(icon, size: 16),
      label: Text(label, style: AppTypography.text(fontWeight: FontWeight.w600, fontSize: 13)),
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
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: Icon(icon, size: 18, color: PosUi.deskText),
    );
  }
}

class _OrdersTableHeader extends StatelessWidget {
  const _OrdersTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.text(fontSize: 12, fontWeight: FontWeight.w600, color: PosUi.deskMuted);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PosUi.deskLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(flex: 24, child: Text('Order #', style: style)),
            Expanded(flex: 22, child: Text('Customer', style: style)),
            Expanded(flex: 14, child: Text('Total', style: style)),
            Expanded(flex: 16, child: Text('Status', style: style)),
            Expanded(flex: 12, child: Text('Payment', style: style)),
            Expanded(flex: 12, child: Text('Time', style: style)),
            SizedBox(width: 96, child: Text('Actions', textAlign: TextAlign.right, style: style)),
          ],
        ),
      ),
    );
  }
}

class _OrderTableRow extends StatelessWidget {
  const _OrderTableRow({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onView,
    this.onReceipt,
    this.onInvoice,
    this.onMerge,
    this.onResume,
    this.busy = false,
  });

  final _ListItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onView;
  final VoidCallback? onReceipt;
  final VoidCallback? onInvoice;
  final VoidCallback? onMerge;
  final VoidCallback? onResume;
  final bool busy;

  bool get _hasMenu => onReceipt != null || onInvoice != null || onMerge != null || onResume != null;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.statusKey);
    return Material(
      color: selected ? PosUi.deskRaised : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                flex: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.text(fontSize: 13.5, fontWeight: FontWeight.w800, color: PosUi.deskText),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.badge != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: PosUi.deskAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.badge!,
                              style: AppTypography.text(fontSize: 10, fontWeight: FontWeight.w800, color: PosUi.deskInk),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (item.secondary != null)
                          Flexible(
                            child: Text(
                              item.secondary!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.text(fontSize: 11, color: PosUi.deskMuted),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.text(fontSize: 13, fontWeight: FontWeight.w700, color: PosUi.deskText),
                    ),
                    if (item.servedBy.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${item.servedPrefix}: ${item.servedBy}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.text(fontSize: 11, color: PosUi.deskMuted),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                flex: 14,
                child: Text(
                  MoneyFormatter.format(item.amount, currencyCode: item.currency),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.text(fontSize: 13, fontWeight: FontWeight.w800, color: PosUi.deskText),
                ),
              ),
              Expanded(
                flex: 16,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        item.status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.text(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  item.payment,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.text(fontSize: 13, fontWeight: FontWeight.w700, color: PosUi.deskAccent),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  item.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.text(fontSize: 12.5, color: PosUi.deskMuted),
                ),
              ),
              SizedBox(
                width: 96,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (busy)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: PosUi.deskAccent),
                      )
                    else
                      IconButton(
                        tooltip: 'View',
                        visualDensity: VisualDensity.compact,
                        onPressed: onView,
                        icon: Icon(Icons.visibility_outlined, size: 18, color: PosUi.deskMuted),
                      ),
                    if (_hasMenu)
                      PopupMenuButton<String>(
                        tooltip: 'More',
                        color: PosUi.deskCard,
                        onSelected: (value) {
                          switch (value) {
                            case 'receipt':
                              onReceipt?.call();
                            case 'invoice':
                              onInvoice?.call();
                            case 'merge':
                              onMerge?.call();
                            case 'resume':
                              onResume?.call();
                          }
                        },
                        itemBuilder: (context) => [
                          if (onReceipt != null) const PopupMenuItem(value: 'receipt', child: Text('Receipt')),
                          if (onInvoice != null) const PopupMenuItem(value: 'invoice', child: Text('Invoice')),
                          if (onMerge != null) const PopupMenuItem(value: 'merge', child: Text('Merge')),
                          if (onResume != null) const PopupMenuItem(value: 'resume', child: Text('Resume')),
                        ],
                        icon: Icon(Icons.more_horiz, size: 18, color: PosUi.deskMuted),
                      ),
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

class _OrderDetailPage extends StatelessWidget {
  const _OrderDetailPage({required this.detail});

  final _Detail detail;

  @override
  Widget build(BuildContext context) {
    void closeThen(VoidCallback? action) {
      Navigator.of(context).pop();
      action?.call();
    }

    return Scaffold(
      backgroundColor: PosUi.deskNight,
      appBar: AppBar(
        backgroundColor: PosUi.deskPanel,
        foregroundColor: PosUi.deskText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          detail.title,
          style: AppTypography.text(fontWeight: FontWeight.w800, color: PosUi.deskText),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _DetailBody(
            detail: detail,
            onModify: detail.onModify == null ? null : () => closeThen(detail.onModify),
            onAddArticles: detail.onAddArticles == null ? null : () => closeThen(detail.onAddArticles),
            onSplit: detail.onSplit == null ? null : () => closeThen(detail.onSplit),
            onPay: detail.onPay == null ? null : () => closeThen(detail.onPay),
          ),
        ],
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    this.onClose,
    this.onModify,
    this.onAddArticles,
    this.onSplit,
    this.onPay,
  });

  final _Detail detail;
  final VoidCallback? onClose;
  final VoidCallback? onModify;
  final VoidCallback? onAddArticles;
  final VoidCallback? onSplit;
  final VoidCallback? onPay;

  String _money(int amount) => MoneyFormatter.format(amount, currencyCode: detail.currency);

  @override
  Widget build(BuildContext context) {
    final modify = onModify ?? detail.onModify;
    final addArticles = onAddArticles ?? detail.onAddArticles;
    final split = onSplit ?? detail.onSplit;
    final pay = onPay ?? detail.onPay;
    final when = [
      if (detail.whenLabel.isNotEmpty) detail.whenLabel,
      if (detail.serviceLabel.isNotEmpty) detail.serviceLabel,
    ].join(' · ');
    final statusColor = _statusColor(detail.statusKey);
    final invoiceBlue = const Color(0xFF4C8DFF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        detail.title,
                        style: AppTypography.text(fontSize: 20, fontWeight: FontWeight.w800, color: PosUi.deskText),
                      ),
                      _DotPill(label: detail.status, color: statusColor),
                      if (detail.paymentLabel.isNotEmpty)
                        _DotPill(label: detail.paymentLabel, color: PosUi.deskAccent),
                    ],
                  ),
                  if (when.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(when, style: AppTypography.text(fontSize: 12.5, color: PosUi.deskMuted)),
                  ],
                ],
              ),
            ),
            if (onClose != null)
              IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                icon: Icon(Icons.close, color: PosUi.deskMuted),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _PersonCard(icon: Icons.person, label: 'Customer', value: detail.customer)),
            const SizedBox(width: 10),
            Expanded(child: _PersonCard(icon: Icons.room_service_outlined, label: 'Served by', value: detail.servedBy)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: PosUi.deskSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PosUi.deskAccent.withValues(alpha: 0.85)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PosUi.deskAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined, size: 18, color: PosUi.deskInk),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Remaining Balance', style: AppTypography.text(fontSize: 12, color: PosUi.deskMuted)),
                  const SizedBox(height: 2),
                  Text(
                    _money(detail.remaining),
                    style: AppTypography.text(fontSize: 20, fontWeight: FontWeight.w800, color: PosUi.deskAccent),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (detail.lines.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Items (${detail.lines.length})',
            style: AppTypography.text(fontSize: 15, fontWeight: FontWeight.w800, color: PosUi.deskText),
          ),
          const SizedBox(height: 8),
          for (final line in detail.lines) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: PosUi.deskSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PosUi.deskLine),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.name, style: AppTypography.text(fontSize: 14, fontWeight: FontWeight.w800, color: PosUi.deskText)),
                        const SizedBox(height: 3),
                        Text(
                          '${line.quantity} pcs x ${_money(line.unitPrice)}',
                          style: AppTypography.text(fontSize: 12, color: PosUi.deskMuted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _money(line.lineTotal),
                    style: AppTypography.text(fontSize: 14, fontWeight: FontWeight.w800, color: PosUi.deskText),
                  ),
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: PosUi.deskSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PosUi.deskLine),
          ),
          child: Column(
            children: [
              _MoneyLine(label: 'Subtotal', value: _money(detail.subtotal)),
              const SizedBox(height: 6),
              _MoneyLine(label: 'Tax', value: _money(detail.tax)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: PosUi.deskLine),
              ),
              _MoneyLine(label: 'Total', value: _money(detail.totalAmount > 0 ? detail.totalAmount : detail.subtotal), strong: true),
              const SizedBox(height: 6),
              _MoneyLine(label: 'Amount Due', value: _money(detail.amountDue), accent: true),
            ],
          ),
        ),
        if (detail.payments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: PosUi.deskField,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: invoiceBlue.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 16, color: invoiceBlue),
                    const SizedBox(width: 8),
                    Text('Payment History', style: AppTypography.text(fontSize: 14, fontWeight: FontWeight.w800, color: PosUi.deskText)),
                  ],
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < detail.payments.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _PaymentTile(index: i + 1, payment: detail.payments[i], money: _money, accent: invoiceBlue),
                ],
              ],
            ),
          ),
        ],
        if (detail.rows.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final row in detail.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${row.$1}: ${row.$2}', style: AppTypography.text(fontSize: 12, color: PosUi.deskMuted)),
            ),
        ],
        if (modify != null || addArticles != null || split != null || pay != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (modify != null)
                OutlinedButton.icon(
                  onPressed: modify,
                  style: OutlinedButton.styleFrom(foregroundColor: PosUi.deskText, side: BorderSide(color: PosUi.deskLine)),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier'),
                ),
              if (addArticles != null)
                OutlinedButton.icon(
                  onPressed: addArticles,
                  style: OutlinedButton.styleFrom(foregroundColor: PosUi.deskText, side: BorderSide(color: PosUi.deskLine)),
                  icon: const Icon(Icons.add_shopping_cart_outlined, size: 16),
                  label: const Text('Ajouter articles'),
                ),
              if (split != null)
                OutlinedButton.icon(
                  onPressed: split,
                  style: OutlinedButton.styleFrom(foregroundColor: PosUi.deskText, side: BorderSide(color: PosUi.deskLine)),
                  icon: const Icon(Icons.call_split, size: 16),
                  label: const Text('Séparer'),
                ),
              if (pay != null)
                FilledButton.icon(
                  onPressed: pay,
                  style: FilledButton.styleFrom(backgroundColor: PosUi.deskPay, foregroundColor: Colors.white),
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('Payer'),
                ),
            ],
          ),
        ],
        if (detail.onPrintInvoice != null || detail.onPrintKitchen != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PosUi.deskLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.print_outlined, size: 16, color: PosUi.deskMuted),
                    const SizedBox(width: 8),
                    Text('Print', style: AppTypography.text(fontSize: 13, fontWeight: FontWeight.w700, color: PosUi.deskText)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (detail.onPrintInvoice != null)
                      OutlinedButton.icon(
                        onPressed: () => detail.onPrintInvoice!(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: invoiceBlue,
                          side: BorderSide(color: invoiceBlue.withValues(alpha: 0.8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text('Print Invoice'),
                      ),
                    if (detail.onPrintKitchen != null)
                      OutlinedButton.icon(
                        onPressed: () => detail.onPrintKitchen!(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PosUi.deskAccent,
                          side: BorderSide(color: PosUi.deskAccent.withValues(alpha: 0.85)),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.restaurant, size: 16),
                        label: const Text('Print Kitchen Ticket'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DotPill extends StatelessWidget {
  const _DotPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.text(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PosUi.deskSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: PosUi.deskAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.text(fontSize: 11, color: PosUi.deskMuted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.text(fontSize: 14, fontWeight: FontWeight.w800, color: PosUi.deskText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyLine extends StatelessWidget {
  const _MoneyLine({required this.label, required this.value, this.strong = false, this.accent = false});

  final String label;
  final String value;
  final bool strong;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? PosUi.deskAccent : PosUi.deskText;
    final weight = strong || accent ? FontWeight.w800 : FontWeight.w500;
    return Row(
      children: [
        Text(label, style: AppTypography.text(fontSize: strong ? 14 : 13, fontWeight: weight, color: color)),
        const Spacer(),
        Text(value, style: AppTypography.text(fontSize: strong ? 15 : 13, fontWeight: weight, color: color)),
      ],
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.index,
    required this.payment,
    required this.money,
    required this.accent,
  });

  final int index;
  final _PaymentEntry payment;
  final String Function(int amount) money;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final when = payment.at == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(payment.at!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PosUi.deskField,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosUi.deskLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.7)),
            ),
            child: Text('$index', style: AppTypography.text(fontSize: 11, fontWeight: FontWeight.w700, color: accent)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.method, style: AppTypography.text(fontSize: 14, fontWeight: FontWeight.w800, color: PosUi.deskText)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (when.isNotEmpty)
                      Text(when, style: AppTypography.text(fontSize: 11, color: PosUi.deskMuted)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accent.withValues(alpha: 0.6)),
                      ),
                      child: Text(payment.method, style: AppTypography.text(fontSize: 11, fontWeight: FontWeight.w700, color: accent)),
                    ),
                  ],
                ),
                if ((payment.treatedBy ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Treated by: ${payment.treatedBy}',
                    style: AppTypography.text(fontSize: 12, fontWeight: FontWeight.w600, color: accent),
                  ),
                ],
              ],
            ),
          ),
          Text(money(payment.amount), style: AppTypography.text(fontSize: 14, fontWeight: FontWeight.w800, color: accent)),
        ],
      ),
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
            color: PosUi.deskCard,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.receipt_long_outlined, color: PosUi.deskAccent, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          'No data available',
          style: AppTypography.text(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: PosUi.deskMuted,
          ),
        ),
      ],
    );
  }
}

Color _statusColor(String status) => switch (status.toLowerCase()) {
      'completed' || 'approved' || 'paid' || 'synced' => PosUi.deskStock,
      'pending' || 'held' || 'submitted' || 'partial' || 'partially_paid' || 'retrying' || 'draft' => PosUi.deskAccent,
      'cancelled' || 'failed' || 'conflict' || 'voided' => AppColors.danger,
      'merged' => PosUi.deskMuted,
      _ => PosUi.deskMuted,
    };

class _ListItem {
  const _ListItem({
    required this.id,
    required this.title,
    required this.meta,
    required this.amount,
    required this.currency,
    required this.status,
    required this.statusKey,
    this.badge,
    this.secondary,
    this.customer = '—',
    this.servedPrefix = 'Served by',
    this.servedBy = '',
    this.payment = '—',
  });

  final String id;
  final String title;
  final String meta;
  final int amount;
  final String currency;
  final String status;
  final String statusKey;
  final String? badge;
  final String? secondary;
  final String customer;
  final String servedPrefix;
  final String servedBy;
  final String payment;

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
    this.tax = 0,
    this.totalAmount = 0,
    this.amountDue = 0,
    this.remaining = 0,
    this.itemCount = 0,
    this.paymentLabel = '',
    this.whenLabel = '',
    this.serviceLabel = '',
    this.customer = '—',
    this.servedBy = '—',
    this.payments = const [],
    this.onModify,
    this.onAddArticles,
    this.onSplit,
    this.onPay,
    this.onPrintInvoice,
    this.onPrintKitchen,
  });

  final String title;
  final String status;
  final String statusKey;
  final String amount;
  final String currency;
  final List<(String, String)> rows;
  final List<_LineDetail> lines;
  final int subtotal;
  final int tax;
  final int totalAmount;
  final int amountDue;
  final int remaining;
  final int itemCount;
  final String paymentLabel;
  final String whenLabel;
  final String serviceLabel;
  final String customer;
  final String servedBy;
  final List<_PaymentEntry> payments;
  final VoidCallback? onModify;
  final VoidCallback? onAddArticles;
  final VoidCallback? onSplit;
  final VoidCallback? onPay;
  final Future<void> Function()? onPrintInvoice;
  final Future<void> Function()? onPrintKitchen;
}

class _PaymentEntry {
  const _PaymentEntry({
    required this.method,
    required this.amount,
    this.at,
    this.treatedBy,
  });

  final String method;
  final int amount;
  final DateTime? at;
  final String? treatedBy;
}

String _saleLineName(Map<String, dynamic> item, [Map<String, String> catalog = const {}]) {
  String? useful(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower == 'item' || lower == 'article') return null;
    return text;
  }

  final product = item['product'];
  final variant = item['product_variant'] ?? item['variant'];
  final nestedId = product is Map ? product['product_id']?.toString() : null;
  final productId = (item['product_id']?.toString().trim().isNotEmpty ?? false)
      ? item['product_id'].toString()
      : (nestedId ?? '');

  return useful(item['product_name']) ??
      useful(item['name']) ??
      useful(item['productName']) ??
      (product is Map ? useful(product['name']) : null) ??
      (variant is Map ? useful(variant['name']) ?? useful(variant['label']) : null) ??
      useful(item['product_sku']) ??
      useful(item['sku']) ??
      useful(catalog[productId]) ??
      'Article';
}

class _LineDetail {
  const _LineDetail({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.totalOverride,
  });

  final String name;
  final int quantity;
  final int unitPrice;
  final int? totalOverride;

  int get lineTotal => totalOverride ?? unitPrice * quantity;
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
    this.serviceMode,
    this.cashierId,
    this.cashierName,
    this.ticket,
    this.tableId,
    this.taxTotal = 0,
    this.subtotalAmount = 0,
    this.payments = const [],
    this.hydrated = false,
  });

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
  final String? serviceMode;
  final String? cashierId;
  final String? cashierName;
  final String? ticket;
  final String? tableId;
  final int taxTotal;
  final int subtotalAmount;
  final List<_PaymentEntry> payments;
  final bool hydrated;

  factory _SaleRow.fromLocal(Map<String, dynamic> row, [Map<String, String> catalog = const {}]) {
    String currency = 'FBU';
    var lines = const <_LineDetail>[];
    String? serviceMode;
    String? cashierId = row['user_id']?.toString();
    String? cashierName;
    String? ticket;
    String? tableId;
    var taxTotal = 0;
    var subtotalAmount = 0;
    try {
      final payload = jsonDecode(row['payload_json'] as String? ?? '{}') as Map<String, dynamic>;
      currency = payload['currency']?.toString() ?? currency;
      serviceMode = payload['service_mode']?.toString();
      cashierName = payload['cashier_name']?.toString();
      final payloadUser = payload['user_id']?.toString();
      if ((cashierId == null || cashierId.isEmpty) && payloadUser != null && payloadUser.isNotEmpty) {
        cashierId = payloadUser;
      }
      ticket = payload['payment_transaction_number']?.toString();
      tableId = payload['table_id']?.toString();
      final payloadItems = payload['items'];
      final storedItems = row['local_items'];
      final items = payloadItems is List && payloadItems.isNotEmpty ? payloadItems : storedItems;
      if (items is List) {
        lines = items.whereType<Map>().map((raw) {
          final item = Map<String, dynamic>.from(raw);
          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
          final unitPrice = (item['unit_price'] as num?)?.toInt() ?? 0;
          final lineTotal = (item['line_total'] as num?)?.toInt();
          return _LineDetail(
            name: _saleLineName(item, catalog),
            quantity: quantity,
            unitPrice: unitPrice,
            totalOverride: lineTotal,
          );
        }).toList();
      }
      taxTotal = (payload['tax_total'] as num?)?.toInt() ?? 0;
      subtotalAmount = (payload['subtotal'] as num?)?.toInt() ?? 0;
    } catch (_) {}
    final customerName = row['customer_name']?.toString();
    final rawPayments = row['local_payments'];
    final payments = rawPayments is List
        ? rawPayments.whereType<Map>().map((raw) {
            final payment = Map<String, dynamic>.from(raw);
            final method = payment['payment_method']?.toString() ?? payment['method']?.toString() ?? 'cash';
            final amount = (payment['amount_in_sale_currency'] as num?)?.toInt() ?? (payment['amount'] as num?)?.toInt() ?? 0;
            return _PaymentEntry(
              method: _paymentName(method),
              amount: amount,
              at: DateTime.tryParse(payment['created_at']?.toString() ?? '') ??
                  DateTime.tryParse(row['created_at']?.toString() ?? ''),
              treatedBy: cashierName,
            );
          }).toList()
        : const <_PaymentEntry>[];
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
      customerName: customerName,
      serviceMode: serviceMode,
      cashierId: cashierId,
      cashierName: cashierName,
      ticket: ticket,
      tableId: tableId,
      taxTotal: taxTotal,
      subtotalAmount: subtotalAmount,
      payments: payments,
      hydrated: true,
    );
  }

  factory _SaleRow.fromSummary(Map<String, dynamic> row) {
    final customer = row['customer'];
    final cashier = row['processed_by'];
    final created = DateTime.tryParse(row['completed_at']?.toString() ?? '') ??
        DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.now();
    return _SaleRow(
      id: row['id']?.toString() ?? '',
      serverId: row['id']?.toString(),
      reference: row['reference']?.toString() ?? 'Vente',
      total: (row['total'] as num?)?.toInt() ?? 0,
      paid: (row['paid_amount'] as num?)?.toInt() ?? 0,
      outstanding: (row['outstanding_amount'] as num?)?.toInt() ?? 0,
      method: row['payment_status']?.toString() ?? 'cash',
      status: row['status']?.toString() ?? 'completed',
      createdAt: created,
      currency: row['currency']?.toString() ?? 'FBU',
      customerName: customer is Map ? customer['name']?.toString() : null,
      cashierId: cashier is Map ? cashier['id']?.toString() : null,
      cashierName: cashier is Map ? cashier['name']?.toString() : null,
      serviceMode: row['service_mode']?.toString(),
      ticket: row['payment_transaction_number']?.toString(),
      tableId: row['table_id']?.toString(),
      taxTotal: (row['tax_total'] as num?)?.toInt() ?? 0,
      subtotalAmount: (row['subtotal'] as num?)?.toInt() ?? 0,
      isRemote: true,
      paymentStatusRaw: row['payment_status']?.toString(),
      hydrated: false,
    );
  }

  factory _SaleRow.fromHold(Map<String, dynamic> row) {
    final held = PosHeldSale.fromLocalJson(row);
    final config = TerminalConfigRepository.instance.config;
    final currency = config.currencyCode;
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
      cashierId: config.cashierId.trim().isEmpty ? null : config.cashierId.trim(),
      cashierName: config.cashierName,
      tableId: held.tableId,
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

  List<_PaymentEntry> get resolvedPayments {
    if (payments.isNotEmpty) return payments;
    if (isHold) return const [];
    final credit = method == 'credit' || paymentColumn == 'Credit';
    final amount = credit ? (outstanding > 0 ? outstanding : total) : paid;
    if (amount <= 0) return const [];
    return [
      _PaymentEntry(
        method: paymentColumn == '—' ? methodLabel : paymentColumn,
        amount: amount,
        at: createdAt,
        treatedBy: cashierName,
      ),
    ];
  }

  String? get serviceBadge {
    final mode = serviceMode?.toLowerCase().trim();
    if (mode == 'takeaway') return 'Takeaway';
    if (mode == 'delivery') return 'Delivery';
    if (tableId != null && tableId!.trim().isNotEmpty) return 'Table';
    return null;
  }

  String? get secondaryReference {
    final value = ticket?.trim();
    if (value == null || value.isEmpty || value == reference) return null;
    return value;
  }

  String get paymentColumn => _paymentName(method);

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


String _paymentName(String method) => switch (method) {
      'held' => '—',
      'cash' => 'Cash',
      'card' => 'Card',
      'credit' => 'Credit',
      'mobile_money' => 'Mobile',
      'partial' => 'Partial',
      'room' => 'Room',
      _ => method,
    };

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
