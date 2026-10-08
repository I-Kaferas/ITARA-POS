part of 'category_bloc.dart';

sealed class CategoryEvent extends Equatable {
  const CategoryEvent();

  @override
  List<Object?> get props => const [];
}

final class CategoryCatalogUpdated extends CategoryEvent {
  const CategoryCatalogUpdated({
    required this.categories,
    this.counts = const {},
  });

  final List<PosCategory> categories;
  final Map<String, int> counts;

  @override
  List<Object?> get props => [categories, counts];
}

final class CategorySelected extends CategoryEvent {
  const CategorySelected(this.categoryId);

  final String? categoryId;

  @override
  List<Object?> get props => [categoryId];
}

final class CategoryCleared extends CategoryEvent {
  const CategoryCleared();
}
