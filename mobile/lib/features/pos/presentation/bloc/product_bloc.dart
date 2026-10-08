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
    _sync.addListener(_onSyncChanged);
  }

  final PosApiService _api;
  final OfflineStore _offline;
  final SyncEngine _sync;
  int _lastRevision = -1;

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
    final showSpinner = state.products.isEmpty;
    if (showSpinner) {
      emit(state.copyWith(status: ProductStatus.loading, clearError: true));
    }

    final cached = storeId.isEmpty ? null : await _offline.loadCatalog(storeId);
    if (cached != null) {
      emit(state.copyWith(
        status: ProductStatus.ready,
        products: cached.products.where((p) => p.isAvailable).toList(),
        categories: cached.categories,
        clearError: true,
        clearStatusMessage: true,
      ));
    }

    if (!event.forceNetwork) {
      if (cached == null) {
        emit(state.copyWith(status: ProductStatus.ready));
      }
      return;
    }

    try {
      final catalog = await _api.fetchCatalog();
      await _offline.cacheCatalog(catalog);
      emit(state.copyWith(
        status: ProductStatus.ready,
        products: catalog.products.where((p) => p.isAvailable).toList(),
        categories: catalog.categories,
        clearError: true,
        clearStatusMessage: true,
      ));
    } catch (error) {
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
