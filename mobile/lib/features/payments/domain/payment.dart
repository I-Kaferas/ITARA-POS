class Payment {
  const Payment({
    required this.id,
    required this.amount,
    this.method = 'cash',
    this.currency = 'USD',
  });

  final String id;
  final num amount;
  final String method;
  final String currency;
}
