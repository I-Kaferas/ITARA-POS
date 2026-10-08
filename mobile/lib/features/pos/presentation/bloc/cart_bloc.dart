import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/pos_models.dart';
import '../../services/pos_cart_engine.dart';

part 'cart_event.dart';
part 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc({PosCartEngine? engine})
      : _engine = engine ?? PosCartEngine(),
        super(const CartState()) {
    _engine.addListener(_onEngineChanged);
    on<CartSynced>(_onSynced);
    on<CartProductAdded>(_onProductAdded);
    on<CartLineRemoved>(_onLineRemoved);
    on<CartQuantityUpdated>(_onQuantityUpdated);
    on<CartCleared>(_onCleared);
    on<CartCustomerSet>(_onCustomerSet);
    on<CartDiscountSet>(_onDiscountSet);
    on<CartNoteSet>(_onNoteSet);
    add(const CartSynced());
  }

  final PosCartEngine _engine;

  PosCartEngine get engine => _engine;

  void _onEngineChanged() => add(const CartSynced());

  void _onSynced(CartSynced event, Emitter<CartState> emit) {
    emit(CartState.fromEngine(_engine));
  }

  void _onProductAdded(CartProductAdded event, Emitter<CartState> emit) {
    _engine.addProduct(
      event.product,
      quantity: event.quantity,
      variant: event.variant,
      saleUnitId: event.saleUnitId,
    );
  }

  void _onLineRemoved(CartLineRemoved event, Emitter<CartState> emit) {
    _engine.removeLine(event.lineId);
  }

  void _onQuantityUpdated(CartQuantityUpdated event, Emitter<CartState> emit) {
    _engine.updateQuantity(event.lineId, event.quantity);
  }

  void _onCleared(CartCleared event, Emitter<CartState> emit) {
    _engine.cancel();
  }

  void _onCustomerSet(CartCustomerSet event, Emitter<CartState> emit) {
    _engine.setCustomer(event.customer);
  }

  void _onDiscountSet(CartDiscountSet event, Emitter<CartState> emit) {
    if (event.percent > 0) {
      _engine.setDiscountPercent(event.percent);
    } else {
      _engine.setDiscountAmount(event.amount);
    }
  }

  void _onNoteSet(CartNoteSet event, Emitter<CartState> emit) {
    _engine.setNote(event.note);
  }

  @override
  Future<void> close() {
    _engine.removeListener(_onEngineChanged);
    return super.close();
  }
}
