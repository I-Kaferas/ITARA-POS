import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/pos_models.dart';

part 'category_event.dart';
part 'category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  CategoryBloc() : super(const CategoryState()) {
    on<CategoryCatalogUpdated>(_onCatalogUpdated);
    on<CategorySelected>(_onSelected);
    on<CategoryCleared>(_onCleared);
  }

  void _onCatalogUpdated(
    CategoryCatalogUpdated event,
    Emitter<CategoryState> emit,
  ) {
    emit(state.copyWith(categories: event.categories, counts: event.counts));
  }

  void _onSelected(
    CategorySelected event,
    Emitter<CategoryState> emit,
  ) {
    emit(state.copyWith(selectedCategoryId: event.categoryId));
  }

  void _onCleared(
    CategoryCleared event,
    Emitter<CategoryState> emit,
  ) {
    emit(state.copyWith(clearSelection: true));
  }
}
