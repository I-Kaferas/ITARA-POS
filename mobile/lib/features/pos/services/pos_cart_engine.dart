import 'package:flutter/foundation.dart';

import '../domain/pos_models.dart';

class PosCartEngine extends ChangeNotifier {
  final List<PosCartLine> _lines = [];
  final List<PosHeldSale> _heldSales = [];
  int _heldCounter = 0;

  PosCustomer? customer;
  String? note;
  int discountAmount = 0;
  double discountPercent = 0;

  List<PosCartLine> get lines => List.unmodifiable(_lines);
  List<PosHeldSale> get heldSales => List.unmodifiable(_heldSales);
  bool get isEmpty => _lines.isEmpty;

  int get subtotal => _lines.fold(0, (sum, line) => sum + line.lineSubtotal);

  int get taxTotal => _lines.fold(0, (sum, line) => sum + line.lineTax);

  int get discountTotal {
    if (discountPercent > 0) {
      return (subtotal * discountPercent / 100).round();
    }
    return discountAmount.clamp(0, subtotal);
  }

  int get total => (subtotal + taxTotal - discountTotal).clamp(0, 1 << 31);

  int get itemCount => _lines.fold(0, (sum, line) => sum + line.quantity);

  void addProduct(PosProduct product, {int quantity = 1}) {
    final existing = _lines.cast<PosCartLine?>().firstWhere(
          (line) => line!.product.productId == product.productId,
          orElse: () => null,
        );

    if (existing != null) {
      existing.quantity += quantity;
    } else {
      _lines.add(
        PosCartLine(
          lineId: '${product.productId}-${DateTime.now().microsecondsSinceEpoch}',
          product: product,
          unitPrice: product.price,
          quantity: quantity,
          taxRate: product.taxRate,
        ),
      );
    }
    notifyListeners();
  }

  void removeLine(String lineId) {
    _lines.removeWhere((line) => line.lineId == lineId);
    notifyListeners();
  }

  void updateQuantity(String lineId, int quantity) {
    final line = _lines.cast<PosCartLine?>().firstWhere(
          (l) => l!.lineId == lineId,
          orElse: () => null,
        );
    if (line == null) return;

    if (quantity <= 0) {
      removeLine(lineId);
      return;
    }

    line.quantity = quantity;
    notifyListeners();
  }

  void incrementQuantity(String lineId) {
    final line = _lineById(lineId);
    if (line != null) updateQuantity(lineId, line.quantity + 1);
  }

  void decrementQuantity(String lineId) {
    final line = _lineById(lineId);
    if (line != null) updateQuantity(lineId, line.quantity - 1);
  }

  void setCustomer(PosCustomer? value) {
    customer = value;
    notifyListeners();
  }

  void setNote(String? value) {
    note = value?.trim().isEmpty == true ? null : value?.trim();
    notifyListeners();
  }

  void setDiscountAmount(int amount) {
    discountAmount = amount.clamp(0, subtotal);
    discountPercent = 0;
    notifyListeners();
  }

  void setDiscountPercent(double percent) {
    discountPercent = percent.clamp(0, 100);
    discountAmount = 0;
    notifyListeners();
  }

  void clearDiscount() {
    discountAmount = 0;
    discountPercent = 0;
    notifyListeners();
  }

  String holdSale() {
    if (_lines.isEmpty) {
      throw StateError('Cannot hold an empty sale');
    }

    _heldCounter += 1;
    final id = 'hold-$_heldCounter';
    final label = 'Vente #$heldCounter — $itemCount art.';

    _heldSales.insert(
      0,
      PosHeldSale(
        id: id,
        label: label,
        lines: _lines.map((line) => line.copy()).toList(),
        heldAt: DateTime.now(),
        customer: customer,
        note: note,
        discountAmount: discountAmount,
        discountPercent: discountPercent,
      ),
    );

    _clearCurrentSale(notify: false);
    notifyListeners();
    return label;
  }

  int get heldCounter => _heldCounter;

  void retrieveSale(String heldSaleId) {
    if (_lines.isNotEmpty) {
      throw StateError('Clear or hold the current sale before retrieving');
    }

    final index = _heldSales.indexWhere((sale) => sale.id == heldSaleId);
    if (index < 0) return;

    final held = _heldSales.removeAt(index);
    _lines.addAll(held.lines.map((line) => line.copy()));
    customer = held.customer;
    note = held.note;
    discountAmount = held.discountAmount;
    discountPercent = held.discountPercent;
    notifyListeners();
  }

  void deleteHeldSale(String heldSaleId) {
    _heldSales.removeWhere((sale) => sale.id == heldSaleId);
    notifyListeners();
  }

  void cancel() {
    _clearCurrentSale();
  }

  PosPaymentResult pay({required String method, int amountTendered = 0}) {
    if (_lines.isEmpty) {
      return const PosPaymentResult(
        success: false,
        total: 0,
        method: '',
        message: 'Le panier est vide',
      );
    }

    final saleTotal = total;
    if (method == 'cash' && amountTendered < saleTotal) {
      return PosPaymentResult(
        success: false,
        total: saleTotal,
        method: method,
        message: 'Montant insuffisant',
      );
    }

    final change = method == 'cash' ? amountTendered - saleTotal : 0;
    _clearCurrentSale(notify: false);

    final result = PosPaymentResult(
      success: true,
      total: saleTotal,
      method: method,
      change: change,
      message: 'Paiement accepté',
    );
    notifyListeners();
    return result;
  }

  PosCartLine? _lineById(String lineId) {
    for (final line in _lines) {
      if (line.lineId == lineId) return line;
    }
    return null;
  }

  void _clearCurrentSale({bool notify = true}) {
    _lines.clear();
    customer = null;
    note = null;
    discountAmount = 0;
    discountPercent = 0;
    if (notify) notifyListeners();
  }
}
