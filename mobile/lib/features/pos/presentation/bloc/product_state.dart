part of 'product_bloc.dart';

enum ProductStatus { initial, loading, ready, failure }

final class ProductState extends Equatable {
  const ProductState({
    this.status = ProductStatus.initial,
    this.products = const [],
    this.categories = const [],
    this.selectedCategoryId,
    this.searchQuery = '',
    this.errorMessage,
    this.statusMessage,
  });

  final ProductStatus status;
  final List<PosProduct> products;
  final List<PosCategory> categories;
  final String? selectedCategoryId;
  final String searchQuery;
  final String? errorMessage;
  final String? statusMessage;

  bool get isLoading => status == ProductStatus.loading;

  Map<String, int> get categoryCounts {
    final counts = <String, int>{};
    for (final product in products) {
      final id = product.categoryId;
      if (id == null || id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  List<PosProduct> get filteredProducts {
    Iterable<PosProduct> result = products;
    final categoryId = selectedCategoryId;
    if (categoryId != null && categoryId.isNotEmpty) {
      result = result.where((p) => p.categoryId == categoryId);
    }
    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((product) {
        return product.name.toLowerCase().contains(query) ||
            product.sku.toLowerCase().contains(query) ||
            (product.barcode?.toLowerCase().contains(query) ?? false);
      });
    }
    return result.toList();
  }

  ProductState copyWith({
    ProductStatus? status,
    List<PosProduct>? products,
    List<PosCategory>? categories,
    String? selectedCategoryId,
    String? searchQuery,
    String? errorMessage,
    String? statusMessage,
    bool clearError = false,
    bool clearStatusMessage = false,
    bool clearCategory = false,
  }) {
    return ProductState(
      status: status ?? this.status,
      products: products ?? this.products,
      categories: categories ?? this.categories,
      selectedCategoryId:
          clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusMessage:
          clearStatusMessage ? null : (statusMessage ?? this.statusMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        products,
        categories,
        selectedCategoryId,
        searchQuery,
        errorMessage,
        statusMessage,
      ];
}
