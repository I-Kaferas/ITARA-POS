import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/architecture/business_continuity.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/layout/android_form_factor.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/app_calculator.dart';
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
import '../../settings/domain/cashier_preferences.dart';
import '../../barcode/presentation/widgets/hid_scanner_field.dart';
import '../../barcode/services/hid_scanner_controller.dart';
import '../../receipt/domain/receipt_models.dart';
import '../../receipt/services/cash_drawer_service.dart';
import '../../receipt/services/kitchen_ticket_service.dart';
import '../../receipt/services/print_once.dart';
import '../../receipt/services/receipt_print_service.dart';
import '../../shifts/data/local_shifts_store.dart';
import '../data/pos_api_service.dart';
import '../domain/pos_models.dart';
import '../services/customer_display_bus.dart';
import '../services/pos_cart_engine.dart';
import '../services/pos_favorites_store.dart';
import '../services/pos_pending_intent.dart';
import 'widgets/delivery_map_card.dart';
import 'widgets/hold_order_dialog.dart';
import 'widgets/pos_cart_panel.dart';
import 'widgets/pos_edit_line_dialog.dart';
import 'customer_display_launcher.dart';
import 'widgets/pos_category_sidebar.dart';
import 'widgets/pos_desktop_shortcuts.dart';
import 'widgets/pos_footer_panel.dart';
import 'widgets/pos_phone_catalog_bar.dart';
import 'widgets/pos_product_grid.dart';
import 'widgets/pos_quick_products_bar.dart';
import 'widgets/pos_return_sheet.dart';
import 'widgets/pos_search_bar.dart';
import 'widgets/pos_table_picker.dart';
import 'widgets/pos_ui.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

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
  final _shiftsApi = LocalShiftsStore.instance;
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
  bool _phoneList = false;
  bool _phoneSearch = false;
  bool _requestPayment = false;
  bool _requestCustomer = false;
  bool _requestRetrieve = false;
  bool _requestDiscount = false;
  bool _requestNote = false;
  bool _requestLoyalty = false;
  bool _requestSplit = false;
  bool _shiftOpen = false;

  bool get _isDesktopPos {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }
  Timer? _recalcTimer;
  Timer? _searchDebounce;
  int _catalogRevision = -1;
  String _activeStoreId = '';
  bool _suppressHoldPersist = false;
  bool _holdPromptOpen = false;
  int _holdWrites = 0;
  int _holdsEpoch = 0;
  bool? _posTabActive;
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
    OfflineStore.instance.holdsRevision.addListener(_onLocalHoldsChanged);
    PosPendingIntent.notifier.addListener(_onPendingIntent);
    _favorites.addListener(_onFavoritesChanged);
    unawaited(_favorites.ensureLoaded());
    _activeStoreId = TerminalConfigRepository.instance.config.storeId;
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
    TerminalConfigRepository.instance.addListener(_onShiftConfigChanged);
    CashierPreferences.instance.addListener(_onBusinessModeChanged);
    _publishCustomerDisplay();
  }

  void _onBusinessModeChanged() {
    if (!mounted) return;
    if (CashierPreferences.instance.standardPos && _cart.hasTable) _cart.setTableId(null);
    setState(() {});
  }

  Future<void> _selectTable() async {
    final choice = await showPosTablePicker(
      context,
      selectedId: _cart.tableId,
      busyIds: {
        for (final sale in _cart.heldSales)
          if ((sale.tableId ?? '').isNotEmpty) sale.tableId!,
      },
    );
    if (choice == null || !mounted) return;
    if (choice.isNone) {
      _cart.setTableId(null);
      _showStatus('Table retirée');
      return;
    }
    _cart.setTableId(choice.id, label: choice.label);
    _showStatus('Table ${choice.label}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context);
    final returned = _posTabActive == false && active;
    _posTabActive = active;
    if (returned) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_refreshPosOnReturn());
      });
    }
  }

  /// The cashier branch stays mounted, so a stuck hold or an empty cart
  /// drawer would otherwise still be there when the register is opened again.
  Future<void> _refreshPosOnReturn() async {
    await _loadPendingOrders();
    if (!mounted || _holdPromptOpen || !_cart.isEmpty) return;
    setState(() {
      _cartOpen = false;
      _requestPayment = false;
      _requestCustomer = false;
      _requestRetrieve = false;
      _requestDiscount = false;
      _requestNote = false;
      _requestLoyalty = false;
      _requestSplit = false;
    });
  }

  @override
  void dispose() {
    _recalcTimer?.cancel();
    _searchDebounce?.cancel();
    _productSub?.cancel();
    PosPendingIntent.notifier.removeListener(_onPendingIntent);
    SyncEngine.instance.removeListener(_onSyncChanged);
    OfflineStore.instance.holdsRevision.removeListener(_onLocalHoldsChanged);
    _favorites.removeListener(_onFavoritesChanged);
    TerminalConfigRepository.instance.removeListener(_onShiftConfigChanged);
    CashierPreferences.instance.removeListener(_onBusinessModeChanged);
    _cart.removeListener(_onCartChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _hidScanner.dispose();
    super.dispose();
  }

  void _onServiceMode(String mode) {
    if (mode == 'delivery') {
      _cart.setServiceMode('delivery');
      return;
    }
    _cart.setServiceMode('takeaway');
  }

  void _pickDeliveryLocation(String address) {
    _cart.setServiceMode('delivery');
    _cart.setDeliveryAddress(address);
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
    if (_cart.isEmpty || _holdPromptOpen) return;
    _holdPromptOpen = true;
    var printKitchen = false;
    try {
      final choice = await showHoldOrderDialog(context);
      if (choice == null || !mounted) return;
      printKitchen = choice;
      final snapshot = _cart.lines.map((l) => l.copy()).toList();
      final customer = _cart.customer;
      final note = _cart.note;
      final discountAmount = _cart.discountAmount;
      final discountPercent = _cart.discountPercent;
      final tableId = _cart.tableId;
      final serverId = _cart.pendingServerId;
      final label = _cart.holdSale();
      await _persistHolds();
      unawaited(_refreshRegister());
      unawaited(_syncHoldToServer(
        label: label,
        lines: snapshot,
        customer: customer,
        note: note,
        discountAmount: discountAmount,
        discountPercent: discountPercent,
        tableId: tableId,
        saleId: serverId,
      ));
      if (printKitchen) {
        try {
          final held = _cart.heldSales.where((sale) => sale.label == label).firstOrNull;
          await KitchenTicketService().printHeldSale(
            held ??
                PosHeldSale(
                  id: label,
                  label: label,
                  lines: snapshot,
                  heldAt: DateTime.now(),
                  customer: customer,
                  note: note,
                  discountAmount: discountAmount,
                  discountPercent: discountPercent,
                  tableId: tableId,
                ),
          );
        } on PrintAlreadyDone {
          if (mounted) _showReadyForNextSale('Déjà imprimé');
        } catch (_) {
          if (mounted) {
            _showReadyForNextSale('Impression cuisine échouée — la commande reste en attente');
          }
          return;
        }
      }
      if (mounted) _showReadyForNextSale('Commande en attente: $label');
    } catch (e) {
      if (mounted) {
        _showStatus(e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', ''));
      }
    } finally {
      _holdPromptOpen = false;
    }
  }

  void _showReadyForNextSale(String message) {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _cartOpen = false;
    });
    _showStatus(message);
  }

  Future<void> _syncHoldToServer({
    required String label,
    required List<PosCartLine> lines,
    PosCustomer? customer,
    String? note,
    int discountAmount = 0,
    double discountPercent = 0,
    String? tableId,
    String? saleId,
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
      final existingId = saleId?.trim() ?? '';
      final data = await _api.holdSale(
        payload,
        saleId: existingId.isEmpty ? null : existingId,
      );
      if (existingId.isNotEmpty) return;
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
      unawaited(_refreshRegister());
      _showStatus('Commande mise en attente ($label) — nouvelle commande prête');
    } catch (e) {
      _showStatus(e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', ''));
    }
  }

  void _shortcutPayment() {
    if (!_shiftOpen) {
      _showStatus('Ouvrez un shift avant d\'encaisser.');
      return;
    }
    if (_cart.isEmpty) {
      _showStatus('Panier vide — ajoutez un article avant de payer');
      return;
    }
    // Close the mobile cart drawer so the payment sheet is not trapped under it.
    setState(() {
      _cartOpen = false;
      _requestPayment = true;
    });
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
    unawaited(_clearOrDeleteOpenSale());
  }

  Future<void> _clearOrDeleteOpenSale() async {
    final pending = _cart.isEditingHold;
    final serverId = _cart.pendingServerId?.trim() ?? '';
    if (_cart.isEmpty && !pending) {
      _showStatus('Rien à annuler');
      return;
    }
    _cart.cancel();
    if (pending && serverId.isNotEmpty) {
      try {
        await _api.discardHold(serverId);
      } catch (_) {}
    }
    if (pending) await _persistHolds();
    if (!mounted) return;
    setState(() => _cartOpen = false);
    _showStatus(pending ? 'Commande en attente supprimée' : 'Vente annulée');
  }

  String _holdsSignature = '';

  String get _menuTitle {
    final name = TerminalConfigRepository.instance.config.deviceName.trim();
    return name.isEmpty ? 'Menu' : '$name Menu';
  }

  int _quantityOf(PosProduct product) {
    var total = 0;
    for (final line in _cart.lines) {
      if (line.product.productId == product.productId && !line.isAccompaniment) {
        total += line.stockQuantity;
      }
    }
    return total;
  }

  void _publishCustomerDisplay() {
    final config = TerminalConfigRepository.instance.config;
    final currency = config.currencyCode.trim().isEmpty ? AppConfig.currencyCode : config.currencyCode;
    CustomerDisplayBus.instance.publishCart(
      _cart,
      brandName: config.brandName,
      currencyCode: currency,
    );
  }

  void _onCartChanged() {
    _publishCustomerDisplay();
    setState(() {});
    _scheduleRecalc();
    final signature = _cart.heldSales.map((sale) => '${sale.id}:${sale.itemCount}:${sale.lines.length}:${sale.note}').join('|');
    if (signature == _holdsSignature) return;
    _holdsSignature = signature;
    unawaited(_persistHolds());
  }

  void _onShiftConfigChanged() {
    final storeId = TerminalConfigRepository.instance.config.storeId;
    if (storeId != _activeStoreId) {
      final previousStoreId = _activeStoreId;
      unawaited(_applyStoreChange(previousStoreId, storeId));
    }
    unawaited(_loadShiftSession());
  }

  Future<void> _applyStoreChange(String previousStoreId, String storeId) async {
    _suppressHoldPersist = true;
    try {
      await _writeHolds(previousStoreId);
      _activeStoreId = storeId;
      _cart.discardOpenSale();
      _searchController.clear();
      _searchQuery = '';
      _selectedCategoryId = null;
      _filteredCategoryId = null;
      _filteredQuery = '';
      _filteredCache = const [];
      if (mounted) setState(() {});
      await _loadPendingOrders();
    } finally {
      _suppressHoldPersist = false;
    }
    if (!mounted) return;
    await _loadCatalog(forceNetwork: true);
  }

  Future<void> _loadShiftSession() async {
    if (!mounted) return;
    try {
      // Shift is owned by the connected cashier for the active store.
      final mine = await _shiftsApi.openShift();
      if (!mounted) return;
      setState(() => _shiftOpen = mine != null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _shiftOpen = false);
    }
  }

  bool _refuseWithoutShift() {
    if (_shiftOpen) return false;
    const message =
        'Aucun shift ouvert. Ouvrez un shift, puis revenez ajouter les articles au panier.';
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(tr(message)),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: tr('Shifts'),
          onPressed: () => context.go(AppRoutes.shifts),
        ),
      ),
    );
    return true;
  }

  Future<void> _recalculateCart() async {
    _cart.clearServerTotals();
  }

  void _scheduleRecalc() {
    _recalcTimer?.cancel();
    _recalcTimer = Timer(const Duration(milliseconds: 280), () => unawaited(_recalculateCart()));
  }

  Future<void> _persistHolds() async {
    if (_suppressHoldPersist) return;
    await _writeHolds(_activeStoreId);
  }

  Future<void> _writeHolds(String storeId) async {
    _holdsEpoch++;
    final existing = await OfflineStore.instance.loadLocalHolds();
    final storedById = {
      for (final row in existing)
        if ((row['id']?.toString() ?? '').isNotEmpty) row['id'].toString(): row,
    };
    final payload = _cart.heldSales.map((sale) {
      final json = sale.toLocalJson();
      final stored = storedById[sale.id];
      final storedServerId = stored?['server_id']?.toString();
      if ((json['server_id'] == null || json['server_id'].toString().isEmpty) &&
          storedServerId != null &&
          storedServerId.isNotEmpty) {
        json['server_id'] = storedServerId;
      }
      for (final key in ['uploaded_at', 'sync_error']) {
        final current = json[key]?.toString().trim() ?? '';
        final previous = stored?[key]?.toString().trim() ?? '';
        if (current.isEmpty && previous.isNotEmpty) json[key] = previous;
      }
      if (storeId.trim().isNotEmpty) json['store_id'] = storeId.trim();
      return json;
    }).toList();
    final currentIds = payload.map((row) => row['id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();
    final scope = storeId.trim();
    final kept = existing.where((row) {
      final id = row['id']?.toString() ?? '';
      if (currentIds.contains(id)) return false;
      final rowStore = row['store_id']?.toString().trim() ?? '';
      if (rowStore.isEmpty) return true;
      return scope.isNotEmpty && rowStore != scope;
    }).toList();
    _holdWrites++;
    try {
      await OfflineStore.instance.saveLocalHolds([...payload, ...kept]);
    } finally {
      _holdWrites--;
      _holdsEpoch++;
    }
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

  String _majorAmount(int minor) {
    final major = minor / 100;
    return major == major.roundToDouble()
        ? major.toStringAsFixed(0)
        : major.toStringAsFixed(2);
  }

  int _parseMajorAmount(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
    return ((double.tryParse(cleaned) ?? 0) * 100).round().clamp(0, 1 << 31);
  }

  Future<void> _showEditLineDialog(String lineId) async {
    final line = _cart.lines.cast<PosCartLine?>().firstWhere(
          (l) => l!.lineId == lineId,
          orElse: () => null,
        );
    if (line == null || line.isAccompaniment) return;

    final result = await showPosEditLineDialog(
      context: context,
      line: line,
      money: (amount) => MoneyFormatter.format(amount, currencyCode: AppConfig.currencyCode),
      major: _majorAmount,
      parseMajor: _parseMajorAmount,
    );
    if (result == null || !mounted) return;
    _cart.updateLine(
      lineId: lineId,
      quantity: result.quantity,
      unitPrice: result.unitPrice,
    );
    _scheduleRecalc();
  }

  /// Puts the register back to a clean sale: search, category, cart panel, and stock.
  Future<void> _refreshRegister({bool forceNetwork = true}) async {
    if (!mounted) return;
    _searchController.clear();
    final products = context.read<ProductBloc>();
    products.add(const ProductSearchChanged(''));
    products.add(const ProductCategoryFilterChanged(null));
    setState(() {
      _searchQuery = '';
      _selectedCategoryId = null;
      _filteredCategoryId = null;
      _filteredQuery = '';
      _filteredCache = const [];
      _cartOpen = false;
    });
    await _loadCatalog(forceNetwork: forceNetwork);
    if (!mounted) return;
    await _loadPendingOrders();
    if (mounted) setState(() {});
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
      SnackBar(content: Text(tr(message)), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _addProduct(PosProduct product) async {
    if (_refuseWithoutShift()) return;
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

  void _onLocalHoldsChanged() {
    // Our own save bumps this revision. Reloading that echo put the ticket
    // we just held back into the list and the next Hold stacked a copy.
    if (!mounted || _holdWrites > 0 || _suppressHoldPersist) return;
    unawaited(_loadPendingOrders());
  }

  Future<void> _loadPendingOrders() async {
    final epoch = _holdsEpoch;
    try {
      final local = OfflineStore.instance.holdsForStore(
        await OfflineStore.instance.loadLocalHolds(),
        _activeStoreId,
      );
      if (!mounted || epoch != _holdsEpoch) return;
      _cart.restoreHeldSales(local.map(PosHeldSale.fromLocalJson).where((sale) => sale.lines.isNotEmpty).toList());
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
        if (!_shiftOpen) {
          _showStatus('Ouvrez un shift avant d\'encaisser.');
        } else {
          setState(() => _requestPayment = true);
        }
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
    // Apply stock to the grid immediately. Avoid bumping catalogRevision —
    // that reloads SQLite/catalog and was restoring the pre-sale quantity.
    if (result.stockUpdates.isNotEmpty) {
      context.read<ProductBloc>().add(ProductStockAdjusted(result.stockUpdates));
      SyncEngine.instance.markCatalogChanged(
        stock: result.stockUpdates,
        bumpRevision: false,
      );
    }
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategoryId = null;
      _filteredCategoryId = null;
      _filteredQuery = '';
      _filteredCache = const [];
      _cartOpen = false;
    });
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
            if (!_shiftOpen) _ShiftRequiredNotice(onOpen: () => context.go(AppRoutes.shifts)),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorView(error: _error!, onRetry: () => _loadCatalog(forceNetwork: true))
                      : _PosWorkspace(
                          search: PosUi.isPhone(context)
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    PosPhoneCatalogBar(
                                      categories: _categories,
                                      selectedCategoryId: _selectedCategoryId,
                                      onCategorySelected: (id) {
                                        context.read<ProductBloc>().add(ProductCategoryFilterChanged(id));
                                        context.read<CategoryBloc>().add(CategorySelected(id));
                                        setState(() => _selectedCategoryId = id);
                                      },
                                      searchOpen: _phoneSearch,
                                      onToggleSearch: () => setState(() => _phoneSearch = !_phoneSearch),
                                      listMode: _phoneList,
                                      onListMode: (value) => setState(() => _phoneList = value),
                                    ),
                                    if (_phoneSearch)
                                      PosSearchBar(
                                        controller: _searchController,
                                        focusNode: _searchFocus,
                                        onChanged: _onSearchChanged,
                                        onSubmitted: _onSearchSubmitted,
                                        onScanTap: () => _onSearchSubmitted(_searchController.text),
                                      ),
                                    if (_cart.serviceMode == 'delivery' && (_cart.tableId == null || _cart.tableId!.isEmpty))
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                                        child: DeliveryMapCard(
                                          selectedAddress: _cart.deliveryAddress,
                                          onPicked: _pickDeliveryLocation,
                                        ),
                                      ),
                                  ],
                                )
                              : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (PosUi.usePosThreePane(context))
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: PosSearchBar(
                                        controller: _searchController,
                                        focusNode: _searchFocus,
                                        onChanged: _onSearchChanged,
                                        onSubmitted: _onSearchSubmitted,
                                        onScanTap: () => _onSearchSubmitted(_searchController.text),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8, right: 12),
                                      child: _ServiceModeSwitch(
                                        mode: _cart.serviceMode,
                                        onChanged: _onServiceMode,
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                PosSearchBar(
                                  controller: _searchController,
                                  focusNode: _searchFocus,
                                  onChanged: _onSearchChanged,
                                  onSubmitted: _onSearchSubmitted,
                                  onScanTap: () => _onSearchSubmitted(_searchController.text),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12, bottom: 4),
                                    child: _ServiceModeSwitch(
                                      mode: _cart.serviceMode,
                                      onChanged: _onServiceMode,
                                    ),
                                  ),
                                ),
                              ],
                              if (_cart.serviceMode == 'delivery' && (_cart.tableId == null || _cart.tableId!.isEmpty))
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                  child: DeliveryMapCard(
                                    selectedAddress: _cart.deliveryAddress,
                                    onPicked: _pickDeliveryLocation,
                                  ),
                                ),
                            ],
                          ),
                          threePane: PosUi.usePosThreePane(context),
                          windowsDesk: PosUi.isWindowsDesk(context),
                          cartOpen: _cartOpen,
                          onToggleCart: () => setState(() => _cartOpen = !_cartOpen),
                          categories: PosUi.isPhone(context)
                              ? const SizedBox.shrink()
                              : PosCategorySidebar(
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
                              if (!PosUi.isDesk(context) && !PosUi.isPhone(context))
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
                                  menuTitle: _menuTitle,
                                  products: _filteredProducts,
                                  favoriteIds: _favorites.favorites,
                                  quantityOf: _quantityOf,
                                  listMode: PosUi.isPhone(context) && _phoneList,
                                  bottomReserve: PosUi.isPhone(context) && _cart.itemCount > 0 ? 92 : 16,
                                  onToggleFavorite: (product) => unawaited(
                                    _favorites.toggleFavorite(product.productId),
                                  ),
                                  onProductTap: (product) {
                                    _addProduct(product);
                                    if (!PosUi.usePosThreePane(context) && !PosUi.isPhone(context)) {
                                      setState(() => _cartOpen = true);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          cart: _phoneCartShell(
                            context,
                            PosCartPanel(
                            cart: _cart,
                            onIncrement: (lineId) {
                              if (_refuseWithoutShift()) return;
                              _cart.incrementQuantity(lineId);
                            },
                            onDecrement: _cart.decrementQuantity,
                            onRemove: _cart.removeLine,
                            onEditLine: _showEditLineDialog,
                            onSearchCustomer: _shortcutCustomer,
                            onSelectTable: CashierPreferences.instance.standardPos ? null : _selectTable,
                            onCustomerDisplay: () {
                              CustomerDisplayLauncher.open(context);
                            },
                            // Always show Pay & Close in the cart (phone drawer + desk).
                            showCheckout: true,
                            onHold: () => unawaited(_shortcutHold()),
                            onClear: () => unawaited(_clearOrDeleteOpenSale()),
                            onPay: _shortcutPayment,
                            onDiscount: () => setState(() => _requestDiscount = true),
                          ),
                          ),
                          cartCount: _cart.itemCount,
                          cartTotal: MoneyFormatter.format(_cart.total),
                        ),
            ),
            PosFooterPanel(
              cart: _cart,
              api: _api,
              hideChrome: PosUi.usePosThreePane(context),
              showShortcutLabels: desktop,
              requestPayment: _requestPayment,
              onPaymentRequestHandled: () => setState(() => _requestPayment = false),
              requestCustomer: _requestCustomer,
              onCustomerRequestHandled: () => setState(() => _requestCustomer = false),
              requestRetrieve: _requestRetrieve,
              onRetrieveRequestHandled: () => setState(() => _requestRetrieve = false),
              requestDiscount: _requestDiscount,
              onDiscountRequestHandled: () => setState(() => _requestDiscount = false),
              requestNote: _requestNote,
              onNoteRequestHandled: () => setState(() => _requestNote = false),
              requestLoyalty: _requestLoyalty,
              onLoyaltyRequestHandled: () => setState(() => _requestLoyalty = false),
              requestSplit: _requestSplit,
              onSplitRequestHandled: () => setState(() => _requestSplit = false),
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
        if (_statusMessage != null) const SizedBox.shrink(),
      ],
    ),
    );

    if (widget.embedded) {
      return ColoredBox(color: PosUi.deskNight, child: content);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(desktop ? 'ITARA POS · Windows' : 'Caisse POS')),
        actions: [
          const CalculatorButton(),
          IconButton(
            tooltip: tr('Retour'),
            onPressed: () => showPosReturnSheet(context, api: _api),
            icon: const Icon(Icons.assignment_return_outlined),
          ),
          IconButton(
            tooltip: tr('Restaurant et hôtel'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HospitalityScreen()),
              );
            },
            icon: const Icon(Icons.table_restaurant),
          ),
          IconButton(
            tooltip: tr('Services'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ServicesScreen()),
              );
            },
            icon: const Icon(Icons.handyman_outlined),
          ),
          IconButton(
            tooltip: tr('Production'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProductionScreen()),
              );
            },
            icon: const Icon(Icons.restaurant),
          ),
          IconButton(
            tooltip: tr('Comptabilité'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AccountingScreen()),
              );
            },
            icon: const Icon(Icons.account_balance_outlined),
          ),
          IconButton(
            tooltip: tr('Rapports'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ReportsScreen()),
              );
            },
            icon: const Icon(Icons.bar_chart),
          ),
          NotificationBadge(
            child: IconButton(
              tooltip: tr('Notifications'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
                );
              },
              icon: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: tr('Fidélité et crédit'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CustomerAccountScreen()),
              );
            },
            icon: const Icon(Icons.card_membership_outlined),
          ),
          IconButton(
            tooltip: tr('Dépenses'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ExpensesScreen()),
              );
            },
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: tr('Actualiser catalogue'),
            onPressed: _loading ? null : () => _loadCatalog(forceNetwork: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _phoneCartShell(BuildContext context, Widget cart) {
    if (!PosUi.isPhone(context)) return cart;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _ServiceModeSwitch(
              mode: _cart.serviceMode,
              onChanged: _onServiceMode,
            ),
          ),
        ),
        Expanded(child: cart),
      ],
    );
  }
}

class _ShiftRequiredNotice extends StatelessWidget {
  const _ShiftRequiredNotice({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warningBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_outlined, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr('Aucun shift ouvert. Ouvrez un shift avant d’ajouter des articles au panier.'),
                style: AppTypography.text(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onOpen,
              child: Text(
                tr('Ouvrir un shift'),
                style: AppTypography.text(fontWeight: FontWeight.w700, color: AppColors.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceModeSwitch extends StatelessWidget {
  const _ServiceModeSwitch({required this.mode, required this.onChanged});

  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pill('takeaway', 'Takeaway', Icons.shopping_bag_outlined),
        const SizedBox(width: 8),
        _pill('delivery', 'Delivery', Icons.delivery_dining_outlined),
      ],
    );
  }

  Widget _pill(String value, String label, IconData icon) {
    final selected = mode == value;
    final fg = selected ? PosUi.deskInk : PosUi.deskText;
    return Material(
      color: selected ? PosUi.deskAccent : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? PosUi.deskAccent : PosUi.deskLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                tr(label),
                style: PosUi.body(weight: FontWeight.w700, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosWorkspace extends StatelessWidget {
  const _PosWorkspace({
    required this.search,
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

  final Widget search;

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
      return ColoredBox(
        color: PosUi.deskNight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tablet = PosUi.isTablet(context);
            final cartW = AndroidLayout.posCartWidth(
              parentWidth: constraints.maxWidth,
              windowsDesk: windowsDesk,
              tablet: tablet,
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      search,
                      categories,
                      Expanded(child: products),
                    ],
                  ),
                ),
                SizedBox(width: cartW, child: cart),
              ],
            );
          },
        ),
      );
    }

    // Smartphone / tablette portrait : grille + panier en tiroir.
    final width = MediaQuery.sizeOf(context).width;
    final cartWidth = AndroidLayout.phoneCartWidth(width);
    return ColoredBox(
      color: PosUi.deskNight,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              categories,
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
            duration: AppMotion.resolve(context, AppMotion.micro),
            curve: AppMotion.standard,
            top: 0,
            bottom: 0,
            right: cartOpen ? 0 : -cartWidth - 20,
            width: cartWidth,
            child: Material(
              color: PosUi.deskPanel,
              elevation: 8,
              child: cart,
            ),
          ),
          if (PosUi.isPhone(context) && cartCount > 0 && !cartOpen)
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Material(
                color: AppColors.brand700,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onToggleCart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          trf('{0} éléments', [cartCount]),
                          style: AppTypography.plex(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          trf('Total: {0}', [cartTotal]),
                          style: AppTypography.plex(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else if (!PosUi.isPhone(context))
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.extended(
                onPressed: onToggleCart,
                backgroundColor: PosUi.deskAccent,
                foregroundColor: PosUi.deskInk,
                extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
                icon: Badge(
                  isLabelVisible: cartCount > 0,
                  label: Text('$cartCount'),
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
                label: Text(tr(cartCount == 0 ? 'Panier' : cartTotal)),
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
      title: Text(trf('Choisir une option · {0}', [widget.product.name])),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.product.hasOptions) ...[
              Text(tr('Sélectionnez l’option à vendre, puis la quantité.')),
              const SizedBox(height: 12),
              if (variants.isEmpty)
                Text(tr('Aucune option disponible pour cet article.'))
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
                                        tr(variant.displayLabel),
                                        style: AppTypography.text(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (variant.sku.isNotEmpty)
                                        Text(
                                          tr(variant.sku),
                                          style: AppTypography.text(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  tr(MoneyFormatter.format(
                                    variant.price,
                                    currencyCode: AppConfig.currencyCode,
                                  )),
                                  style: AppTypography.text(
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
                tr('Unité de vente'),
                style: AppTypography.text(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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
                                tr(unit.name),
                                style: AppTypography.text(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              tr(MoneyFormatter.format(
                                unit.price,
                                currencyCode: AppConfig.currencyCode,
                              )),
                              style: AppTypography.text(
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
                Text(tr('Quantité'), style: AppTypography.text(color: AppColors.textPrimary)),
                const Spacer(),
                IconButton(
                  onPressed: _quantity <= 1 ? null : () => setState(() => _quantity -= 1),
                  icon: const Icon(Icons.remove),
                ),
                Text(
                  '$_quantity',
                  style: AppTypography.text(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Annuler'))),
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
          child: Text(tr('Ajouter')),
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
      title: Text(trf('Accompagnements · {0}', [widget.product.name])),
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
              title: Text(tr(item.name)),
              subtitle: item.sku.isEmpty ? null : Text(tr(item.sku)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Passer'))),
        FilledButton(
          onPressed: () {
            final selected = items.where((item) => _selected.contains(item.productId)).toList();
            Navigator.pop(context, selected);
          },
          child: Text(tr('Ajouter')),
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
            Text(tr(error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(tr('Réessayer')),
            ),
          ],
        ),
      ),
    );
  }
}

