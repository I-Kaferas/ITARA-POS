import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../sync/offline_store.dart';
import '../../../sync/sync_engine.dart';
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
import '../data/pos_api_service.dart';
import '../domain/pos_models.dart';
import '../services/pos_cart_engine.dart';
import '../services/pos_pending_intent.dart';
import 'widgets/pos_cart_panel.dart';
import 'widgets/pos_category_sidebar.dart';
import 'widgets/pos_footer_panel.dart';
import 'widgets/pos_product_grid.dart';
import 'widgets/pos_search_bar.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _api = PosApiService();
  final _cart = PosCartEngine();
  final _searchController = TextEditingController();
  late final HidScannerController _hidScanner;

  List<PosProduct> _products = [];
  List<PosCategory> _categories = [];
  String? _selectedCategoryId;
  String _searchQuery = '';
  bool _loading = true;
  String? _error;
  String? _statusMessage;
  bool _cartOpen = false;
  DateTime? _catalogSyncedAt;
  bool _requestPayment = false;

  @override
  void initState() {
    super.initState();
    _hidScanner = HidScannerController(onScan: _onBarcodeScanned);
    _cart.addListener(_onCartChanged);
    SyncEngine.instance.addListener(_onSyncChanged);
    PosPendingIntent.notifier.addListener(_onPendingIntent);
    unawaited(_loadPendingOrders().then((_) => _consumePendingIntent()));
    _catalogSyncedAt = SyncEngine.instance.lastSyncAt;
    _loadCatalog();
  }

  @override
  void dispose() {
    PosPendingIntent.notifier.removeListener(_onPendingIntent);
    SyncEngine.instance.removeListener(_onSyncChanged);
    _cart.removeListener(_onCartChanged);
    _searchController.dispose();
    _hidScanner.dispose();
    super.dispose();
  }

  String _holdsSignature = '';

  void _onCartChanged() {
    setState(() {});
    final signature = _cart.heldSales.map((sale) => '${sale.id}:${sale.itemCount}:${sale.lines.length}:${sale.note}').join('|');
    if (signature == _holdsSignature) return;
    _holdsSignature = signature;
    unawaited(_persistHolds());
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
    final syncedAt = SyncEngine.instance.lastSyncAt;
    if (syncedAt == null || syncedAt == _catalogSyncedAt || !mounted) return;
    _catalogSyncedAt = syncedAt;
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final storeId = _api.storeId;
    final cached = storeId.isEmpty ? null : await OfflineStore.instance.loadCatalog(storeId);
    if (cached != null && mounted) {
      setState(() {
        _products = cached.products.where((p) => p.isAvailable).toList();
        _categories = cached.categories;
        _loading = false;
        _error = null;
      });
    }

    try {
      final catalog = await _api.fetchCatalog();
      await OfflineStore.instance.cacheCatalog(catalog);
      if (!mounted) return;
      setState(() {
        _products = catalog.products.where((p) => p.isAvailable).toList();
        _categories = catalog.categories;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (cached != null) {
        setState(() => _statusMessage = 'Catalogue local · sync en attente');
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<PosProduct> get _filteredProducts {
    var result = _products;

    if (_selectedCategoryId != null) {
      result = result
          .where((product) => product.categoryId == _selectedCategoryId)
          .toList();
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((product) {
        return product.name.toLowerCase().contains(query) ||
            product.sku.toLowerCase().contains(query) ||
            (product.barcode?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return result;
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

    if (product.hasOptions) {
      final choice = await showDialog<_OptionChoice>(
        context: context,
        builder: (context) => _OptionDialog(product: product),
      );
      if (choice == null || !mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      _cart.addProduct(product, quantity: choice.quantity, variant: choice.variant);
      return;
    }

    _cart.addProduct(product);
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
    setState(() => _searchQuery = value);
  }

  void _onSearchSubmitted(String value) {
    if (value.trim().isEmpty) return;
    _onBarcodeScanned(value.trim());
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        Column(
          children: [
            PosSearchBar(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
              onScanTap: () => _onSearchSubmitted(_searchController.text),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorView(error: _error!, onRetry: _loadCatalog)
                      : _PosWorkspace(
                          wide: MediaQuery.sizeOf(context).width >= 980,
                          cartOpen: _cartOpen,
                          onToggleCart: () => setState(() => _cartOpen = !_cartOpen),
                          categories: PosCategorySidebar(
                            categories: _categories,
                            selectedCategoryId: _selectedCategoryId,
                            totalCount: _products.length,
                            counts: {
                              for (final category in _categories)
                                category.id: _products
                                    .where((product) => product.categoryId == category.id)
                                    .length,
                            },
                            onCategorySelected: (id) {
                              setState(() => _selectedCategoryId = id);
                            },
                          ),
                          products: PosProductGrid(
                            products: _filteredProducts,
                            onProductTap: (product) {
                              _addProduct(product);
                              if (MediaQuery.sizeOf(context).width < 980) {
                                setState(() => _cartOpen = true);
                              }
                            },
                          ),
                          cart: PosCartPanel(
                            cart: _cart,
                            onIncrement: _cart.incrementQuantity,
                            onDecrement: _cart.decrementQuantity,
                            onRemove: _cart.removeLine,
                          ),
                          cartCount: _cart.itemCount,
                          cartTotal: MoneyFormatter.format(_cart.total),
                        ),
            ),
            PosFooterPanel(
              cart: _cart,
              api: _api,
              requestPayment: _requestPayment,
              onPaymentRequestHandled: () => setState(() => _requestPayment = false),
              onHold: () async {
                try {
                  final label = _cart.holdSale();
                  await _persistHolds();
                  _showStatus('Commande gardée en local: $label');
                } catch (e) {
                  _showStatus(e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', ''));
                }
              },
              onNewSale: () async {
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
              },
              onRetrieve: (id, {bool parkCurrentFirst = false}) async {
                final openCartAfter = MediaQuery.sizeOf(context).width < 980;
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
              onCancel: () {
                _cart.cancel();
                _showStatus('Vente annulée');
              },
              onPayment: (result) {
                if (result.success) {
                  final change = result.change > 0
                      ? ' — Monnaie: ${MoneyFormatter.format(result.change)}'
                      : '';
                  final balance = result.outstandingAmount > 0
                      ? ' — Solde: ${MoneyFormatter.format(result.outstandingAmount)}'
                      : '';
                  _showStatus('${result.message}$change$balance');
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
    );

    if (widget.embedded) {
      return ColoredBox(color: AppColors.canvas, child: content);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caisse POS'),
        actions: [
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
            onPressed: _loading ? null : _loadCatalog,
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
    required this.wide,
    required this.cartOpen,
    required this.onToggleCart,
    required this.categories,
    required this.products,
    required this.cart,
    required this.cartCount,
    required this.cartTotal,
  });

  final bool wide;
  final bool cartOpen;
  final VoidCallback onToggleCart;
  final Widget categories;
  final Widget products;
  final Widget cart;
  final int cartCount;
  final String cartTotal;

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 168, child: categories),
            Expanded(child: products),
            SizedBox(width: 248, child: cart),
          ],
        ),
      );
    }

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
              SizedBox(width: 168, child: categories),
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
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            top: 0,
            bottom: 0,
            right: cartOpen ? 0 : -280,
            width: 260,
            child: Material(
              color: AppColors.surface,
              elevation: 12,
              child: cart,
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: onToggleCart,
              backgroundColor: AppColors.brand600,
              foregroundColor: Colors.white,
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
  const _OptionChoice({required this.variant, required this.quantity});

  final PosVariant variant;
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
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _variantId = widget.product.variants.isEmpty ? '' : widget.product.variants.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final variants = widget.product.variants;
    final selected = variants.cast<PosVariant?>().firstWhere(
          (item) => item!.id == _variantId,
          orElse: () => null,
        );

    return AlertDialog(
      title: Text('Choisir une option · ${widget.product.name}'),
      content: SizedBox(
        width: 420,
        child: variants.isEmpty
            ? const Text('Aucune option disponible pour cet article.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Sélectionnez l’option à vendre, puis la quantité.'),
                  const SizedBox(height: 12),
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
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (variant.sku.isNotEmpty)
                                          Text(
                                            variant.sku,
                                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    MoneyFormatter.format(
                                      variant.price,
                                      currencyCode: AppConfig.currencyCode,
                                    ),
                                    style: GoogleFonts.inter(
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
                  Row(
                    children: [
                      Text('Quantité', style: GoogleFonts.inter(color: AppColors.textPrimary)),
                      const Spacer(),
                      IconButton(
                        onPressed: _quantity <= 1 ? null : () => setState(() => _quantity -= 1),
                        icon: const Icon(Icons.remove),
                      ),
                      Text(
                        '$_quantity',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
          onPressed: selected == null
              ? null
              : () => Navigator.pop(
                    context,
                    _OptionChoice(variant: selected, quantity: _quantity),
                  ),
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
