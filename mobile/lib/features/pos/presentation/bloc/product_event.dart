part of 'product_bloc.dart';

sealed class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object?> get props => const [];
}

final class ProductCatalogLoadRequested extends ProductEvent {
  const ProductCatalogLoadRequested({this.forceNetwork = true});

  final bool forceNetwork;

  @override
  List<Object?> get props => [forceNetwork];
}

final class ProductSearchChanged extends ProductEvent {
  const ProductSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class ProductCategoryFilterChanged extends ProductEvent {
  const ProductCategoryFilterChanged(this.categoryId);

  final String? categoryId;

  @override
  List<Object?> get props => [categoryId];
}

final class ProductSynced extends ProductEvent {
  const ProductSynced();
}
