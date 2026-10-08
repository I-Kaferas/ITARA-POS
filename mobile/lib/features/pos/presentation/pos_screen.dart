import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/architecture/business_continuity.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../sync/offline_store.dart';
import '../../../sync/sync_engine.dart';
import 'bloc/cart_bloc.dart';
import 'bloc/category_bloc.dart';
import 'bloc/checkout_bloc.dart';
import 'bloc/payment_bloc.dart';
import 'bloc/product_bloc.dart';
import '../../accounting/presentation/accounting_screen.dart';
import '../../customers/presentation/customer_account_screen.dart';
import '../../expenses/presentation/expenses_screen.dart';
import '../../hospitality/presentation/hospitality_screen.dart';
import '../../notifications/presentation/notification_badge.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../production/presentation/production_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../services/presentation/services_screen.dart';
import '../../barcode/presentation/widgets/hid_scanner_field.dart';
import '../../barcode/services/hid_scanner_controller.dart';
import '../../receipt/domain/receipt_models.dart';
import '../../receipt/services/cash_drawer_service.dart';
import '../../receipt/services/receipt_print_service.dart';
import '../../shifts/data/shifts_api_service.dart';
import '../data/pos_api_service.dart';
import '../domain/pos_models.dart';
import '../services/pos_cart_engine.dart';
import '../services/pos_favorites_store.dart';
import '../services/pos_pending_intent.dart';
import 'widgets/pos_cart_panel.dart';
import 'widgets/pos_category_sidebar.dart';
import 'widgets/pos_desktop_shortcuts.dart';
import 'widgets/pos_footer_panel.dart';
import 'widgets/pos_product_grid.dart';
import 'widgets/pos_quick_products_bar.dart';
import 'widgets/pos_return_sheet.dart';
import 'widgets/pos_search_bar.dart';
import 'widgets/pos_session_gate.dart';
import 'widgets/pos_ui.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<ProductBloc>()
            ..add(const ProductCatalogLoadRequested()),
        ),
        BlocProvider(create: (_) => sl<CategoryBloc>()),
        BlocProvider(create: (_) => sl<CartBloc>()),
        BlocProvider(
          create: (_) => sl<CheckoutBloc>()..add(const CheckoutStarted()),
        ),
        BlocProvider(
          create: (_) => sl<PaymentBloc>()..add(const PaymentStarted()),
        ),
      ],
      child: _PosScreenBody(embedded: embedded),
    );
  }
}

class _PosScreenBody extends StatefulWidget {
  const _PosScreenBody({this.embedded = false});

  final bool embedded;

  @override
  State<_PosScreenBody> createState() => _PosScreenBodyState();
}

class _PosScreenBodyState extends State<_PosScreenBody> {
  final _api = PosApiService();
  final _cart = PosCartEngine();
  final _shiftsApi = ShiftsApiService();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  late final HidScannerController _hidScanner;
  final _cashDrawer = CashDrawerService();

  List<PosProduct> _products = [];
  List<PosCategory> _categories = [];
  String? _selectedCategoryId;
  String _searchQuery = '';
  bool _loading = true;
  String? _error;
  String? _statusMessage;
  bool _cartOpen = false;
  bool _requestPayment = false;
  bool _requestCustomer = false;
  bool _requestRetrieve = false;
  bool _shiftOpen = false;

  bool get _isDesktopPos {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }
  bool _shiftLoading = false;
  List<PosGateRegister> _registers = [];
  Timer? _recalcTimer;
  Timer? _searchDebounce;
  int _catalogRevision = -1;
  Map<String, int> _categoryCounts = const {};
  List<PosProduct> _filteredCache = const [];
  String? _filteredCategoryId;
  String _filteredQuery = '';
  final _favorites = PosFavoritesStore.instance;
  StreamSubscription<ProductState>? _productSub;

  @override
  void initState() {
    super.initState();
    _hidScanner = HidScannerController(onScan: _onBarcodeScanned);
    _cart.addListener(_onCartChanged);
    SyncEngine.instance.addListener(_onSyncChanged);
    PosPendingIntent.notifier.addListener(_onPendingIntent);
    _favorites.addListener(_onFavoritesChanged);
    unawaited(_favorites.ensureLoaded());
    unawaited(_loadPendingOrders().then((_) => _consumePendingIntent()));
    _catalogRevision = SyncEngine.instance.catalogRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final products = context.read<ProductBloc>();
      _productSub = products.stream.listen(_onProductState);
      _onProductState(products.state);
      products.add(const ProductCatalogLoadRequested());
    });
    unawaited(_loadShiftSession());
  }

  @override
  void dispose() {
    _recalcTimer?.cancel();
    _searchDebounce?.cancel();
    _productSub?.cancel();
    PosPendingIntent.notifier.removeListener(_onPendingIntent);
    SyncEngine.instance.removeListener(_onSyncChanged);
    _favorites.removeListener(_onFavoritesChanged);
    _cart.removeListener(_onCartChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _hidScanner.dispose();
    super.dispose();
  }

  void _onProductState(ProductState state) {
    if (!mounted) return;
    setState(() {
      _products = state.products;
      _categories = state.categories;
      if (state.selectedCategoryId != null ||
          state.searchQuery != _searchQuery) {
        _selectedCategoryId = state.selectedCategoryId ?? _selectedCategoryId;
        _searchQuery = state.searchQuery.isEmpty ? _searchQuery : state.searchQuery;
      }
      _loading = state.isLoading && state.products.isEmpty;
      _error = state.errorMessage;
      if (state.statusMessage != null) {
        _statusMessage = state.statusMessage;
      }
      _rebuildFilters(productsChanged: true);
    });
    context.read<CategoryBloc>().add(CategoryCatalogUpdated(
          categories: state.categories,
          counts: state.categoryCounts,
        ));
  }

  void _focusSearch() {
    _searchFocus.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
  }

  void _onFavoritesChanged() {
    if (!mounted) return;
    _rebuildFilters(productsChanged: true);
    setState(() {});
  }

  Future<void> _shortcutHold() async {
    try {
      final snapshot = _cart.lines.map((l) => l.copy()).toList();
      final customer = _cart.customer;
      final note = _cart.note;
      final discountAmount = _cart.discountAmount;
      final discountPercent = _cart.discountPercent;
      final tableId = _cart.tableId;
      final label = _cart.holdSale();
      await _persistHolds();
      unawaited(_syncHoldToServer(
        label: label,
        lines: snapshot,
        customer: customer,
        note: note,
        discountAmount: discountAmount,
        discountPercent: discountPercent,
        tableId: tableId,
      ));
      _showStatus('Commande en attente: $label');
    } catch (e) {
      _showStatus(e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _syncHoldToServer({
    required String label,
    required List<PosCartLine> lines,
    PosCustomer? customer,
    String? note,
    int discountAmount = 0,
    double discountPercent = 0,
    String? tableId,
  }) async {
    if (lines.isEmpty) return;
    try {
      final payload = {
        'items': lines.map((line) => line.toSaleItem()).toList(),
        if (customer != null) 'customer_id': customer.saleCustomerId,
        if (discountPercent > 0)
          'discount': {'type': 'percent', 'value': discountPercent}
        else if (discountAmount > 0)
          'discount': {'type': 'fixed', 'value': discountAmount},
        if (note != null) 'notes': note,
        if (tableId != null) 'table_id': tableId,
        'label': label,
      };
      final data = await _api.holdSale(payload);
      final serverId = data['id']?.toString() ?? data['sale_id']?.toString() ?? '';
      if (serverId.isEmpty) return;
      final local = _cart.heldSales.cast<PosHeldSale?>().firstWhere(
            (sale) => sale!.label == label && (sale.serverId == null || sale.serverId!.isEmpty),
            orElse: () => null,
          );
      if (local != null) {
        _cart.rememberRemoteHold(serverId: serverId, label: label, heldAt: local.heldAt);
        await _persistHolds();
      }
    } catch (_) {
      // Keep local hold — offline-first.
    }
  }

  Future<void> _shortcutNewSale() async {
    try {
      final label = _cart.startNewSale();
      if (label == null) {
        _showStatus('Déjà une nouvelle commande');
        return;
      }
      await _persistHolds();
      _showStatus('Commande mise en attente ($label) — nouvelle commande prête');
    } catch (e) {
      _showStatus(e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', ''));
    }
  }

  void _shortcutPayment() {
    if (_cart.isEmpty) {
      _showStatus('Panier vide — ajoutez un article avant de payer');
      return;
    }
    setState(() => _requestPayment = true);
  }

  void _shortcutCustomer() {
    setState(() => _requestCustomer = true);
  }

  void _shortcutRetrieve() {
    if (_cart.heldSales.isEmpty) {
      _showStatus('Aucune commande en attente');
      return;
    }
    setState(() => _requestRetrieve = true);
  }

  void _shortcutCancel() {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (_searchFocus.hasFocus && _searchController.text.isNotEmpty) {
      _searchController.clear();
      setState(() => _searchQuery = '');
      return;
    }
    if (_cart.isEmpty) {
      _showStatus('Rien à annuler');
      return;
    }
    _cart.cancel();
    _showStatus('Vente annulée');
  }

  String _holdsSignature = '';

  void _onCartChanged() {
    setState(() {});
    _scheduleRecalc();
    final signature = _cart.heldSales.map((sale) => '${sale.id}:${sale.itemCount}:${sale.lines.length}:${sale.note}').join('|');
    if (signature == _holdsSignature) return;
    _holdsSignature = signature;
    unawaited(_persistHolds());
  }

  Future<void> _loadShiftSession() async {
    setState(() => _shiftLoading = true);
    try {
      final registers = await _shiftsApi.fetchRegisters();
      final current = await _shiftsApi.currentCashierShift();
      if (!mounted) return;
      setState(() {
        _registers = registers.map((r) => PosGateRegister(id: r.id, name: r.name, code: r.code)).toList();
        _shiftOpen = current != null && (current['status']?.toString() == 'open' || current['closed_at'] == null);
        _shiftLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      try {
        final registers = await _shiftsApi.fetchRegisters();
        var open = false;
        for (final reg in registers) {
          final session = await _shiftsApi.currentSession(reg.id);
          if (session.session != null && session.session!.isOpen) {
            open = true;
            break;
          }
        }
        if (!mounted) return;
        setState(() {
          _registers = registers.map((r) => PosGateRegister(id: r.id, name: r.name, code: r.code)).toList();
          _shiftOpen = open;
          _shiftLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _shiftLoading = false;
          _shiftOpen = true; // allow offline selling
        });
      }
    }
  }

  Future<void> _openShift(String pin, String registerId, int opening) async {
    try {
      await _shiftsApi.openCashierShiftWithPin(registerId: registerId, pin: pin, openingFloat: opening);
    } catch (_) {
      await _shiftsApi.openSession(registerId: registerId, openingBalance: opening);
    }
    await _loadShiftSession();
  }

  Future<void> _recalculateCart() async {
    if (_cart.isEmpty) {
      _cart.clearServerTotals();
      return;
    }
    try {
      final payload = {
        'items': _cart.lines
            .map(
              (line) => {
                'line_id': line.lineId,
                'product_id': line.product.productId,
                'quantity': line.quantity,
                'unit_price': line.unitPrice,
                if (line.variantId != null) 'product_variant_id': line.variantId,
                if (line.saleUnitId != null) 'sale_unit_id': line.saleUnitId,
                if (line.isAccompaniment) 'is_accompaniment': true,
                if (line.lineDiscountFixed > 0) 'line_discount_fixed': line.lineDiscountFixed,
              },
            )
            .toList(),
        if (_cart.customer != null) 'customer_id': _cart.customer!.saleCustomerId,
        if (_cart.discountPercent > 0)
          'discount': {'type': 'percent', 'value': _cart.discountPercent}
        else if (_cart.discountAmount > 0)
          'discount': {'type': 'fixed', 'value': _cart.discountAmount},
        if (_cart.loyaltyPoints > 0) 'loyalty_points': _cart.loyaltyPoints,
        if (_cart.note != null) 'notes': _cart.note,
        if (_cart.tableId != null) 'table_id': _cart.tableId,
      };
      final calc = await _api.calculateCart(payload);
      _cart.applyServerTotals(
        subtotal: calc.subtotal,
        taxTotal: calc.taxTotal,
        discountTotal: calc.discountTotal,
        feesTotal: calc.feesTotal,
        total: calc.total,
      );
    } catch (_) {
      _cart.clearServerTotals();
    }
  }

  void _scheduleRecalc() {
    _recalcTimer?.cancel();
    _recalcTimer = Timer(const Duration(milliseconds: 280), () => unawaited(_recalculateCart()));
  }

  Future<void> _persistHolds() async {
    final existing = await OfflineStore.instance.loadLocalHolds();
    final serverIds = {
      for (final row in existing)
        if ((row['id']?.toString() ?? '').isNotEmpty) row['id'].toString(): row['server_id']?.toString(),
    };
    final payload = _cart.heldSales.map((sale) {
      final json = sale.toLocalJson();
      final stored = serverIds[sale.id];
      if ((json['server_id'] == null || json['server_id'].toString().isEmpty) && stored != null && stored.isNotEmpty) {
        json['server_id'] = stored;
      }
      return json;
    }).toList();
    await OfflineStore.instance.saveLocalHolds(payload);
  }

  void _onSyncChanged() {
    final revision = SyncEngine.instance.catalogRevision;
    if (revision == _catalogRevision || !mounted) return;
    _catalogRevision = revision;
    unawaited(_loadCatalog(forceNetwork: false));
  }

  void _rebuildFilters({bool productsChanged = false}) {
    if (productsChanged || _filteredCategoryId != _selectedCategoryId || _filteredQuery != _searchQuery) {
      _filteredCategoryId = _selectedCategoryId;
      _filteredQuery = _searchQuery;
      var result = _products;
      if (_selectedCategoryId == PosFavoritesStore.favoritesCategoryId) {
        result = result.where((p) => _favorites.isFavorite(p.productId)).toList();
      } else if (_selectedCategoryId != null) {
        result = result.where((product) => product.categoryId == _selectedCategoryId).toList();
      }
      final query = _searchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        result = result.where((product) {
          return product.name.toLowerCase().contains(query) ||
              product.sku.toLowerCase().contains(query) ||
              (product.barcode?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
      _filteredCache = result;
    }
    if (productsChanged) {
      final counts = <String, int>{};
      for (final product in _products) {
        final id = product.categoryId;
        if (id == null || id.isEmpty) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      _categoryCounts = counts;
    }
  }

  List<PosProduct> get _quickProducts {
    final byId = {for (final p in _products) p.productId: p};
    return _favorites.quickProductIds
        .map((id) => byId[id])
        .whereType<PosProduct>()
        .where((p) => p.isAvailable)
        .toList();
  }

  Future<void> _showLineDiscountDialog(String lineId) async {
    final line = _cart.lines.cast<PosCartLine?>().firstWhere(
          (l) => l!.lineId == lineId,
          orElse: () => null,
        );
    if (line == null) return;
    final ctrl = TextEditingController(
      text: line.lineDiscountFixed > 0 ? '${line.lineDiscountFixed}' : '',
    );
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remise ligne'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Montant (max ${line.lineSubtotal})',
            suffixText: AppConfig.currencyCode,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 0), child: const Text('Effacer')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(ctrl.text.trim()) ?? 0;
              Navigator.pop(ctx, value);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (amount == null || !mounted) return;
    _cart.setLineDiscount(lineId, amount);
    _scheduleRecalc();
  }

  Future<void> _loadCatalog({bool forceNetwork = false}) async {
    context.read<ProductBloc>().add(
          ProductCatalogLoadRequested(forceNetwork: forceNetwork),
        );
  }

  List<PosProduct> get _filteredProducts {
    _rebuildFilters();
    return _filteredCache;
  }

  void _showStatus(String message) {
    setState(() => _statusMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _addProduct(PosProduct product) async {
    // Never show a toast/snackbar when adding to cart.
    ScaffoldMessenger.of(context).clearSnackBars();

    PosCartLine? parentLine;
    final needsOptions = product.hasOptions || product.saleUnits.length > 1;
    if (needsOptions) {
      final choice = await showDialog<_OptionChoice>(
        context: context,
        builder: (context) => _OptionDialog(product: product),
      );
      if (choice == null || !mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      _cart.addProduct(
        product,
        quantity: choice.quantity,
        variant: choice.variant,
        saleUnitId: choice.saleUnitId,
      );
      parentLine = _cart.lines.cast<PosCartLine?>().lastWhere(
            (line) =>
                line != null &&
                line.product.productId == product.productId &&
                !line.isAccompaniment,
            orElse: () => null,
          );
    } else {
      _cart.addProduct(product);
      parentLine = _cart.lines.cast<PosCartLine?>().lastWhere(
            (line) =>
                line != null &&
                line.product.productId == product.productId &&
                !line.isAccompaniment,
            orElse: () => null,
          );
    }

    if (parentLine != null &&
        product.accompanimentEnabled &&
        product.accompaniments.isNotEmpty &&
        mounted) {
      final selected = await showDialog<List<PosAccompaniment>>(
        context: context,
        builder: (context) => _AccompanimentDialog(product: product),
      );
      if (selected != null && selected.isNotEmpty && mounted) {
        final stubs = selected
            .map(
              (item) => PosProduct(
                storeProductId: item.productId,
                productId: item.productId,
                sku: item.sku,
                name: item.name,
                price: 0,
              ),
            )
            .toList();
        _cart.addAccompaniments(parentLine, stubs);
      }
    }

    _scheduleRecalc();
  }

  Future<void> _loadPendingOrders() async {
    try {
      final local = await OfflineStore.instance.loadLocalHolds();
      _cart.restoreHeldSales(local.map(PosHeldSale.fromLocalJson).where((sale) => sale.lines.isNotEmpty).toList());
      final pending = await _api.fetchPendingSales();
      for (final sale in pending) {
        final id = sale['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final created = DateTime.tryParse(sale['created_at']?.toString() ?? '');
        final total = (sale['total'] as num?)?.toInt() ?? 0;
        final reference = sale['reference']?.toString() ?? 'Commande en attente';
        _cart.rememberRemoteHold(
          serverId: id,
          label: total > 0 ? '$reference · ${MoneyFormatter.format(total)}' : reference,
          heldAt: created,
        );
      }
    } catch (_) {}
  }

  void _onPendingIntent() {
    unawaited(_consumePendingIntent());
  }

  Future<void> _consumePendingIntent() async {
    final intent = PosPendingIntent.take();
    if (intent == null || !mounted) return;

    final tableId = intent.tableId?.trim();
    if (tableId != null && tableId.isNotEmpty) {
      _cart.setTableId(tableId);
    }

    if (intent.holdId.trim().isEmpty) return;

    try {
      if (_cart.heldById(intent.holdId) == null) {
        await _loadPendingOrders();
      }
      var held = _cart.heldById(intent.holdId);
      if (held != null && held.lines.isEmpty && (held.serverId?.isNotEmpty ?? false)) {
        await _fillRemoteHold(held);
        held = _cart.heldById(intent.holdId);
      }
      if (held == null || held.lines.isEmpty) {
        throw Exception('Cette commande n’a aucun article à modifier');
      }
      _cart.retrieveSale(intent.holdId, parkCurrentFirst: !_cart.isEmpty);
      await _persistHolds();
      if (!mounted) return;
      final status = switch (intent.action) {
        PosHoldAction.modify => 'Commande chargée — modifiez puis Enregistrer (Attente)',
        PosHoldAction.addArticles => 'Commande chargée — ajoutez des articles puis Enregistrer (Attente)',
        PosHoldAction.pay => 'Commande chargée — paiement',
        PosHoldAction.split => 'Commande chargée — choisissez les articles à séparer',
      };
      _showStatus(status);
      if (MediaQuery.sizeOf(context).width < 980) {
        setState(() => _cartOpen = true);
      }
      if (intent.openSplit && mounted) {
        final moves = await showPosSplitDialog(context, _cart);
        if (moves == null || moves.isEmpty || !mounted) return;
        final label = _cart.splitSale(moves);
        await _persistHolds();
        if (!mounted) return;
        _showStatus('Commande séparée: $label (en attente)');
      } else if (intent.openPay && mounted) {
        setState(() => _requestPayment = true);
      }
    } catch (e) {
      if (!mounted) return;
      _showStatus(e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _handlePaymentSuccess(PosPaymentResult result) async {
    final change = result.change > 0 ? ' — Monnaie: ${MoneyFormatter.format(result.change)}' : '';
    final balance = result.outstandingAmount > 0
        ? ' — Solde: ${MoneyFormatter.format(result.outstandingAmount)}'
        : '';
    final loyalty = (result.loyaltyEarned ?? 0) > 0
        ? ' — Fidélité: +${result.loyaltyEarned} pts'
        : '';
    _showStatus('${result.message}$change$balance$loyalty');
    _cart.cancel();
    if (CashDrawerService.shouldOpenForPayment(
      method: result.method,
      change: result.change,
    )) {
      unawaited(_cashDrawer.openFromTerminalConfig());
    }
    await _tryPrintReceipt(result);
  }

  Future<void> _tryPrintReceipt(PosPaymentResult result) async {
    // §74 — print is after commit; failures never cancel the sale.
    await BusinessContinuity.afterSalePrint(null, () async {
      Map<String, dynamic>? receipt = result.receipt;
      final saleId = result.saleId;
      if (receipt == null && saleId != null && saleId.isNotEmpty) {
        receipt = await _api.createReceipt(saleId);
      }
      if (receipt == null) return;
      final payload = _receiptPayloadFromMap(receipt);
      if (payload == null || !mounted) return;
      await ReceiptPrintService().tryPrint(payload);
    });
  }

  ReceiptPrintPayload? _receiptPayloadFromMap(Map<String, dynamic> map) {
    final payload = map['payload'] ??
        (map['data'] is Map ? (map['data'] as Map)['payload'] : null) ??
        map;
    if (payload is! Map) return null;
    try {
      return ReceiptPrintPayload.fromJson(Map<String, dynamic>.from(payload));
    } catch (_) {
      return null;
    }
  }

  Future<void> _fillRemoteHold(PosHeldSale held) async {
    final serverId = held.serverId;
    if (serverId == null || serverId.isEmpty) return;
    final sale = await _api.fetchSale(serverId);
    if (sale == null) return;
    final items = sale['items'] as List<dynamic>? ?? [];
    final lines = <PosCartLine>[];
    for (final raw in items.whereType<Map>()) {
      final item = Map<String, dynamic>.from(raw);
      final productId = item['product_id']?.toString() ?? '';
      if (productId.isEmpty) continue;
      final name = item['product_name']?.toString() ?? item['name']?.toString() ?? 'Article';
      final price = (item['unit_price'] as num?)?.toInt() ?? 0;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      lines.add(
        PosCartLine(
          lineId: item['id']?.toString() ?? productId,
          product: PosProduct(
            storeProductId: productId,
            productId: productId,
            sku: item['product_sku']?.toString() ?? '',
            name: name,
            price: price,
          ),
          unitPrice: price,
          quantity: qty,
        ),
      );
    }
    if (lines.isEmpty) return;
    _cart.attachLines(held.id, lines);
  }

  Future<void> _onBarcodeScanned(String code) async {
    final local = _products.cast<PosProduct?>().firstWhere(
          (p) => p!.matchesBarcode(code),
          orElse: () => null,
        );

    if (local != null) {
      _addProduct(local);
      return;
    }

    try {
      final result = await _api.lookupBarcode(code);
      if (!result.found) {
        _showStatus('Code-barres introuvable: $code');
        return;
      }

      final bySku = _products.cast<PosProduct?>().firstWhere(
            (p) => p!.sku == result.productSku,
            orElse: () => null,
          );

      if (bySku != null) {
        _addProduct(bySku);
      } else {
        _showStatus('Produit non disponible dans ce magasin');
      }
    } catch (e) {
      _showStatus('Erreur scan: $e');
    }
  }

  void _onSearchChanged(String value) {
    context.read<ProductBloc>().add(ProductSearchChanged(value));
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || _searchQuery == value) return;
      setState(() => _searchQuery = value);
    });
  }

  void _onSearchSubmitted(String value) {
    if (value.trim().isEmpty) return;
    _onBarcodeScanned(value.trim());
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktopPos || PosUi.isWindowsDesk(context);
    final content = PosDesktopShortcuts(
      onSearch: _focusSearch,
      onNewSale: () => unawaited(_shortcutNewSale()),
      onCustomer: _shortcutCustomer,
      onPayment: _shortcutPayment,
      onHold: () => unawaited(_shortcutHold()),
      onRetrieve: _shortcutRetrieve,
      onCancel: _shortcutCancel,
      child: Stack(
      children: [
        Column(
          children: [
            PosSearchBar(
              controller: _searchController,
              focusNode: _searchFocus,
              showDesktopHint: desktop,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
              onScanTap: () => _onSearchSubmitted(_searchController.text),
            ),
            if (desktop) const PosShortcutHintBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorView(error: _error!, onRetry: () => _loadCatalog(forceNetwork: true))
                      : _PosWorkspace(
                          threePane: PosUi.usePosThreePane(context),
                          windowsDesk: PosUi.isWindowsDesk(context),
                          cartOpen: _cartOpen,
                          onToggleCart: () => setState(() => _cartOpen = !_cartOpen),
                          categories: PosCategorySidebar(
                            categories: _categories,
                            selectedCategoryId: _selectedCategoryId,
                            totalCount: _products.length,
                            favoritesCount: _products
                                .where((p) => _favorites.isFavorite(p.productId))
                                .length,
                            counts: _categoryCounts,
                            onCategorySelected: (id) {
                              context.read<ProductBloc>().add(
                                    ProductCategoryFilterChanged(id),
                                  );
                              context.read<CategoryBloc>().add(
                                    CategorySelected(id),
                                  );
                              setState(() => _selectedCategoryId = id);
                            },
                          ),
                          products: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PosQuickProductsBar(
                                products: _quickProducts,
                                onProductTap: (product) {
                                  _addProduct(product);
                                  if (!PosUi.usePosThreePane(context)) {
                                    setState(() => _cartOpen = true);
                                  }
                                },
                              ),
                              Expanded(
                                child: PosProductGrid(
                                  products: _filteredProducts,
                                  favoriteIds: _favorites.favorites,
                                  onToggleFavorite: (product) => unawaited(
                                    _favorites.toggleFavorite(product.productId),
                                  ),
                                  onProductTap: (product) {
                                    _addProduct(product);
                                    if (!PosUi.usePosThreePane(context)) {
                                      setState(() => _cartOpen = true);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          cart: PosCartPanel(
                            cart: _cart,
                            onIncrement: _cart.incrementQuantity,
                            onDecrement: _cart.decrementQuantity,
                            onRemove: _cart.removeLine,
                            onLineDiscount: _showLineDiscountDialog,
                          ),
                          cartCount: _cart.itemCount,
                          cartTotal: MoneyFormatter.format(_cart.total),
                        ),
            ),
            PosFooterPanel(
              cart: _cart,
              api: _api,
              showShortcutLabels: desktop,
              requestPayment: _requestPayment,
              onPaymentRequestHandled: () => setState(() => _requestPayment = false),
              requestCustomer: _requestCustomer,
              onCustomerRequestHandled: () => setState(() => _requestCustomer = false),
              requestRetrieve: _requestRetrieve,
              onRetrieveRequestHandled: () => setState(() => _requestRetrieve = false),
              onHold: () => unawaited(_shortcutHold()),
              onNewSale: () => unawaited(_shortcutNewSale()),
              onRetrieve: (id, {bool parkCurrentFirst = false}) async {
                final openCartAfter = !PosUi.usePosThreePane(context);
                try {
                  final held = _cart.heldById(id);
                  if (held != null && held.lines.isEmpty && (held.serverId?.isNotEmpty ?? false)) {
                    await _fillRemoteHold(held);
                  }
                  final loaded = _cart.heldById(id);
                  if (loaded == null || loaded.lines.isEmpty) {
                    throw Exception('Cette commande n’a aucun article à modifier');
                  }
                  _cart.retrieveSale(id, parkCurrentFirst: parkCurrentFirst);
                  await _persistHolds();
                  if (!mounted) return;
                  _showStatus(
                    parkCurrentFirst
                        ? 'Vente en cours mise en attente — commande chargée, ajoutez des articles'
                        : 'Commande chargée — ajoutez des articles, puis Enregistrer (Attente)',
                  );
                  if (openCartAfter) {
                    setState(() => _cartOpen = true);
                  }
                } catch (e) {
                  _showStatus(e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', ''));
                }
              },
              onSplit: (moves) async {
                try {
                  final label = _cart.splitSale(moves);
                  await _persistHolds();
                  _showStatus('Commande séparée: $label (en attente)');
                } catch (e) {
                  _showStatus(e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', ''));
                }
              },
              onCancel: _shortcutCancel,
              onPayment: (result) {
                if (result.success) {
                  unawaited(_handlePaymentSuccess(result));
                } else {
                  _showStatus(result.message ?? 'Paiement refusé');
                }
              },
            ),
          ],
        ),
        HidScannerField(controller: _hidScanner),
        if (!_shiftOpen)
          PosSessionGate(
            registers: _registers,
            currentShiftOpen: _shiftOpen,
            loading: _shiftLoading,
            onOpen: _openShift,
            onRefresh: _loadShiftSession,
          ),
        if (_statusMessage != null) const SizedBox.shrink(),
      ],
    ),
    );

    if (widget.embedded) {
      return ColoredBox(color: AppColors.canvas, child: content);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(desktop ? 'ITARA POS · Windows' : 'Caisse POS'),
        actions: [
          IconButton(
            tooltip: 'Retour',
            onPressed: () => showPosReturnSheet(context, api: _api),
            icon: const Icon(Icons.assignment_return_outlined),
          ),
          IconButton(
            tooltip: 'Restaurant et hôtel',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HospitalityScreen()),
              );
            },
            icon: const Icon(Icons.table_restaurant),
          ),
          IconButton(
            tooltip: 'Services',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ServicesScreen()),
              );
            },
            icon: const Icon(Icons.handyman_outlined),
          ),
          IconButton(
            tooltip: 'Production',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProductionScreen()),
              );
            },
            icon: const Icon(Icons.restaurant),
          ),
          IconButton(
            tooltip: 'Comptabilité',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AccountingScreen()),
              );
            },
            icon: const Icon(Icons.account_balance_outlined),
          ),
          IconButton(
            tooltip: 'Rapports',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ReportsScreen()),
              );
            },
            icon: const Icon(Icons.bar_chart),
          ),
          NotificationBadge(
            child: IconButton(
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
                );
              },
              icon: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Fidélité et crédit',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CustomerAccountScreen()),
              );
            },
            icon: const Icon(Icons.card_membership_outlined),
          ),
          IconButton(
            tooltip: 'Dépenses',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ExpensesScreen()),
              );
            },
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: 'Actualiser catalogue',
            onPressed: _loading ? null : () => _loadCatalog(forceNetwork: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: content,
    );
  }
}

class _PosWorkspace extends StatelessWidget {
  const _PosWorkspace({
    required this.threePane,
    this.windowsDesk = false,
    required this.cartOpen,
    required this.onToggleCart,
    required this.categories,
    required this.products,
    required this.cart,
    required this.cartCount,
    required this.cartTotal,
  });

  /// Tablette / desk §18 : Sidebar + Product Grid + Cart.
  final bool threePane;
  /// §19 Windows : panneau panier / catégories élargis.
  final bool windowsDesk;
  final bool cartOpen;
  final VoidCallback onToggleCart;
  final Widget categories;
  final Widget products;
  final Widget cart;
  final int cartCount;
  final String cartTotal;

  @override
  Widget build(BuildContext context) {
    if (threePane) {
      final tablet = PosUi.isTablet(context);
      final categoryW = windowsDesk
          ? PosUi.categoryWidthWindows
          : (tablet ? 152.0 : PosUi.categoryWidth);
      final cartW = windowsDesk
          ? PosUi.cartWidthWindows
          : (tablet ? 280.0 : PosUi.cartWidth);
      return Container(
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: categoryW, child: categories),
            Expanded(child: products),
            SizedBox(width: cartW, child: cart),
          ],
        ),
      );
    }

    // Smartphone : catégories + grille, panier en tiroir tactile.
    final width = MediaQuery.sizeOf(context).width;
    final cartWidth = width < 400 ? width * 0.92 : 280.0;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: width < 360 ? 100 : 120, child: categories),
              Expanded(child: products),
            ],
          ),
          if (cartOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: onToggleCart,
                child: ColoredBox(color: AppColors.sidebar.withValues(alpha: 0.45)),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            top: 0,
            bottom: 0,
            right: cartOpen ? 0 : -cartWidth - 20,
            width: cartWidth,
            child: Material(
              color: AppColors.surface,
              elevation: 8,
              child: cart,
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.extended(
              onPressed: onToggleCart,
              backgroundColor: AppColors.brand600,
              foregroundColor: Colors.white,
              extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
              icon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('$cartCount'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
              label: Text(cartCount == 0 ? 'Panier' : cartTotal),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionChoice {
  const _OptionChoice({
    required this.quantity,
    this.variant,
    this.saleUnitId,
  });

  final PosVariant? variant;
  final String? saleUnitId;
  final int quantity;
}

class _OptionDialog extends StatefulWidget {
  const _OptionDialog({required this.product});

  final PosProduct product;

  @override
  State<_OptionDialog> createState() => _OptionDialogState();
}

class _OptionDialogState extends State<_OptionDialog> {
  late String _variantId;
  String? _saleUnitId;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _variantId = widget.product.variants.isEmpty ? '' : widget.product.variants.first.id;
    if (widget.product.saleUnits.length > 1) {
      final base = widget.product.saleUnits.cast<PosSaleUnit?>().firstWhere(
            (unit) => unit!.isBase,
            orElse: () => null,
          );
      _saleUnitId = base?.id ?? widget.product.saleUnits.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final variants = widget.product.variants;
    final saleUnits = widget.product.saleUnits;
    final selectedVariant = variants.isEmpty
        ? null
        : variants.cast<PosVariant?>().firstWhere(
              (item) => item!.id == _variantId,
              orElse: () => null,
            );
    final canSubmit = (!widget.product.hasOptions || selectedVariant != null) &&
        (saleUnits.length <= 1 || (_saleUnitId != null && _saleUnitId!.isNotEmpty));

    return AlertDialog(
      title: Text('Choisir une option · ${widget.product.name}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.product.hasOptions) ...[
              const Text('Sélectionnez l’option à vendre, puis la quantité.'),
              const SizedBox(height: 12),
              if (variants.isEmpty)
                const Text('Aucune option disponible pour cet article.')
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: variants.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final variant = variants[index];
                      final active = variant.id == _variantId;
                      return Material(
                        color: active ? AppColors.brand50 : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: () => setState(() => _variantId = variant.id),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: active ? AppColors.brand600 : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        variant.displayLabel,
                                        style: GoogleFonts.ibmPlexSans(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (variant.sku.isNotEmpty)
                                        Text(
                                          variant.sku,
                                          style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  MoneyFormatter.format(
                                    variant.price,
                                    currencyCode: AppConfig.currencyCode,
                                  ),
                                  style: GoogleFonts.ibmPlexSans(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandInk,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
            ],
            if (saleUnits.length > 1) ...[
              Text(
                'Unité de vente',
                style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              ...saleUnits.map((unit) {
                final active = unit.id == _saleUnitId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: active ? AppColors.brand50 : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => setState(() => _saleUnitId = unit.id),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: active ? AppColors.brand600 : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                unit.name,
                                style: GoogleFonts.ibmPlexSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              MoneyFormatter.format(
                                unit.price,
                                currencyCode: AppConfig.currencyCode,
                              ),
                              style: GoogleFonts.ibmPlexSans(
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandInk,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Text('Quantité', style: GoogleFonts.ibmPlexSans(color: AppColors.textPrimary)),
                const Spacer(),
                IconButton(
                  onPressed: _quantity <= 1 ? null : () => setState(() => _quantity -= 1),
                  icon: const Icon(Icons.remove),
                ),
                Text(
                  '$_quantity',
                  style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                IconButton(
                  onPressed: () => setState(() => _quantity += 1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: !canSubmit
              ? null
              : () => Navigator.pop(
                    context,
                    _OptionChoice(
                      variant: selectedVariant,
                      saleUnitId: _saleUnitId,
                      quantity: _quantity,
                    ),
                  ),
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}

class _AccompanimentDialog extends StatefulWidget {
  const _AccompanimentDialog({required this.product});

  final PosProduct product;

  @override
  State<_AccompanimentDialog> createState() => _AccompanimentDialogState();
}

class _AccompanimentDialogState extends State<_AccompanimentDialog> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final items = widget.product.accompaniments;
    return AlertDialog(
      title: Text('Accompagnements · ${widget.product.name}'),
      content: SizedBox(
        width: 420,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final checked = _selected.contains(item.productId);
            return CheckboxListTile(
              value: checked,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selected.add(item.productId);
                  } else {
                    _selected.remove(item.productId);
                  }
                });
              },
              title: Text(item.name),
              subtitle: item.sku.isEmpty ? null : Text(item.sku),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Passer')),
        FilledButton(
          onPressed: () {
            final selected = items.where((item) => _selected.contains(item.productId)).toList();
            Navigator.pop(context, selected);
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
