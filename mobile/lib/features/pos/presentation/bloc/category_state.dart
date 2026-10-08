part of 'category_bloc.dart';

final class CategoryState extends Equatable {
  const CategoryState({
    this.categories = const [],
    this.selectedCategoryId,
    this.counts = const {},
  });

  final List<PosCategory> categories;
  final String? selectedCategoryId;
  final Map<String, int> counts;

  CategoryState copyWith({
    List<PosCategory>? categories,
    String? selectedCategoryId,
    Map<String, int>? counts,
    bool clearSelection = false,
  }) {
    return CategoryState(
      categories: categories ?? this.categories,
      selectedCategoryId:
          clearSelection ? null : (selectedCategoryId ?? this.selectedCategoryId),
      counts: counts ?? this.counts,
    );
  }

  @override
  List<Object?> get props => [categories, selectedCategoryId, counts];
}
