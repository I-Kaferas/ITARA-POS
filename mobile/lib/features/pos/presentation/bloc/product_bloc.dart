import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../sync/offline_store.dart';
import '../../../../sync/sync_engine.dart';
import '../../data/pos_api_service.dart';
import '../../domain/pos_models.dart';

part 'product_event.dart';
part 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  ProductBloc({
    PosApiService? api,
    OfflineStore? offlineStore,
    SyncEngine? syncEngine,
  })  : _api = api ?? PosApiService(),
        _offline = offlineStore ?? OfflineStore.instance,
        _sync = syncEngine ?? SyncEngine.instance,
        super(const ProductState()) {
    on<ProductCatalogLoadRequested>(_onLoad);
    on<ProductSearchChanged>(_onSearch);
    on<ProductCategoryFilterChanged>(_onCategoryFilter);
    on<ProductSynced>(_onSynced);
    on<ProductStockAdjusted>(_onStockAdjusted);
    _sync.addListener(_onSyncChanged);
  }

  final PosApiService _api;
  final OfflineStore _offline;
  final SyncEngine _sync;
  int _lastRevision = -1;
  String _loadedStoreId = '';

  void _onSyncChanged() {
    if (_sync.catalogRevision == _lastRevision) return;
    _lastRevision = _sync.catalogRevision;
    add(const ProductSynced());
  }

  Future<void> _onLoad(
    ProductCatalogLoadRequested event,
    Emitter<ProductState> emit,
  ) async {
    final storeId = _api.storeId;
    final storeChanged = storeId != _loadedStoreId;
    final showSpinner = state.products.isEmpty || storeChanged;
    if (showSpinner) {
      emit(state.copyWith(
        status: ProductStatus.loading,
        products: storeChanged ? const [] : null,
        categories: storeChanged ? const [] : null,
        searchQuery: storeChanged ? '' : null,
        clearCategory: storeChanged,
        clearError: true,
        clearStatusMessage: true,
      ));
    }

    final cached = storeId.isEmpty ? null : await _offline.loadCatalog(storeId);
    if (_api.storeId != storeId) return;
    if (cached != null) {
      _loadedStoreId = storeId;
      emit(state.copyWith(
        status: ProductStatus.ready,
        products: cached.products.where((p) => p.isAvailable).toList(),
        categories: cached.categories,
        clearError: true,
        clearStatusMessage: true,
      ));
    } else if (storeChanged) {
      _loadedStoreId = storeId;
      emit(state.copyWith(
        status: ProductStatus.ready,
        products: const [],
        categories: const [],
        clearCategory: true,
        searchQuery: '',
        clearError: true,
        clearStatusMessage: true,
      ));
    }

    if (!event.forceNetwork && !storeChanged) {
      if (cached == null) {
        emit(state.copyWith(status: ProductStatus.ready));
      }
      return;
    }

    try {
      final catalog = await _api.fetchCatalog();
      if (_api.storeId != storeId) return;
      await _offline.cacheCatalog(catalog);
      _loadedStoreId = storeId;
      final stored = await _offline.loadCatalog(storeId);
      final visible = (stored?.products ?? catalog.products).where((product) => product.isAvailable).toList();
      final categories = stored?.categories ?? catalog.categories;
      emit(state.copyWith(
        status: ProductStatus.ready,
        products: visible,
        categories: categories,
        clearError: true,
        clearStatusMessage: true,
      ));
      await _paintImages(storeId, PosCatalog(storeId: storeId, products: visible, categories: categories), visible, emit);
      final fresh = await _offline.loadCatalog(storeId);
      if (fresh == null || _api.storeId != storeId || isClosed) return;
      emit(state.copyWith(
        status: ProductStatus.ready,
        products: fresh.products.where((product) => product.isAvailable).toList(),
        categories: fresh.categories,
        clearError: true,
      ));
    } catch (error) {
      if (_api.storeId != storeId) return;
      if (cached != null) {
        emit(state.copyWith(
          status: ProductStatus.ready,
          statusMessage: 'Catalogue local · sync en attente',
        ));
        return;
      }
      emit(state.copyWith(
        status: ProductStatus.failure,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _paintImages(
    String storeId,
    PosCatalog catalog,
    List<PosProduct> visible,
    Emitter<ProductState> emit,
  ) async {
    Map<String, String> urls;
    try {
      urls = await _api.fetchPosImages();
    } catch (_) {
      return;
    }
    if (urls.isEmpty || _api.storeId != storeId || isClosed) return;

    final ids = urls.keys.toList();
    var products = visible;
    const chunk = 12;
    for (var index = 0; index < ids.length; index += chunk) {
      if (_api.storeId != storeId || isClosed) return;
      final end = index + chunk > ids.length ? ids.length : index + chunk;
      final slice = ids.sublist(index, end);
      products = [
        for (final product in products)
          if (slice.contains(product.productId) && urls[product.productId] != null)
            product.withPrimaryImage(urls[product.productId]!)
          else
            product,
      ];
      emit(state.copyWith(
        status: ProductStatus.ready,
        products: products,
        categories: catalog.categories,
      ));
      if (end < ids.length) {
        await Future<void>.delayed(const Duration(milliseconds: 70));
      }
    }

    try {
      await _offline.cacheCatalog(
        PosCatalog(
          storeId: catalog.storeId,
          products: products,
          categories: catalog.categories,
        ),
        stockFromCloud: false,
      );
    } catch (_) {}
  }

  void _onSearch(
    ProductSearchChanged event,
    Emitter<ProductState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onCategoryFilter(
    ProductCategoryFilterChanged event,
    Emitter<ProductState> emit,
  ) {
    emit(state.copyWith(
      selectedCategoryId: event.categoryId,
      clearCategory: event.categoryId == null,
    ));
  }

  void _onStockAdjusted(
    ProductStockAdjusted event,
    Emitter<ProductState> emit,
  ) {
    if (event.updates.isEmpty || state.products.isEmpty) return;
    final byId = <String, Map<String, dynamic>>{};
    for (final row in event.updates) {
      for (final key in [
        row['product_id']?.toString(),
        row['store_product_id']?.toString(),
        row['catalog_product_id']?.toString(),
      ]) {
        if (key != null && key.isNotEmpty) byId[key] = row;
      }
    }
    if (byId.isEmpty) return;
    emit(state.copyWith(
      products: [
        for (final product in state.products)
          if (byId[product.productId] ?? byId[product.storeProductId] case final row?)
            product.withStock(
              quantityOnHand: _stockInt(row['quantity_on_hand']) ?? product.quantityOnHand ?? 0,
              stockVersion: _stockInt(row['stock_version']) ?? product.stockVersion,
            )
          else
            product,
      ],
    ));
  }

  int? _stockInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  Future<void> _onSynced(
    ProductSynced event,
    Emitter<ProductState> emit,
  ) async {
    add(const ProductCatalogLoadRequested(forceNetwork: false));
  }

  @override
  Future<void> close() {
    _sync.removeListener(_onSyncChanged);
    return super.close();
  }
}
