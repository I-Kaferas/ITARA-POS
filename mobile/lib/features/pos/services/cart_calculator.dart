class CartCalculationLine {
  const CartCalculationLine({
    required this.unitPrice,
    required this.quantity,
    required this.taxRatePpm,
    this.taxInclusive = false,
    this.lineDiscountFixed = 0,
  });

  final int unitPrice;
  final int quantity;
  final int taxRatePpm;
  final bool taxInclusive;
  final int lineDiscountFixed;
}

class CartCalculationInput {
  const CartCalculationInput({
    required this.lines,
    this.globalDiscountFixed = 0,
    this.globalDiscountPercentPpm = 0,
    this.fees = const [],
  });

  final List<CartCalculationLine> lines;
  final int globalDiscountFixed;
  final int globalDiscountPercentPpm;
  final List<int> fees;
}

class CartCalculationResult {
  const CartCalculationResult({required this.grandTotal});

  final int grandTotal;
}

class CartCalculator {
  static int ratePpmFromPercent(String percent) {
    final value = double.tryParse(percent) ?? 0;
    return (value * 10000).round();
  }

  static CartCalculationResult calculate(CartCalculationInput input) {
    var net = 0;
    var tax = 0;

    for (final line in input.lines) {
      final gross = line.unitPrice * line.quantity;
      final discounted = (gross - line.lineDiscountFixed).clamp(0, 1 << 31);
      final taxAmount = (discounted * line.taxRatePpm / 1000000).round();
      if (line.taxInclusive) {
        net += (discounted - taxAmount).clamp(0, discounted);
        tax += taxAmount;
      } else {
        net += discounted;
        tax += taxAmount;
      }
    }

    final discount = input.globalDiscountPercentPpm > 0
        ? (net * input.globalDiscountPercentPpm / 1000000).round()
        : input.globalDiscountFixed.clamp(0, net);
    final fees = input.fees.fold<int>(0, (sum, fee) => sum + fee);
    final total = (net + tax - discount + fees).clamp(0, 1 << 31);

    return CartCalculationResult(grandTotal: total);
  }
}
