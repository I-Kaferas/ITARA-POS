class Product {
  const Product({
    required this.id,
    required this.name,
    this.sku = '',
    this.price = 0,
    this.categoryId = '',
  });

  final String id;
  final String name;
  final String sku;
  final num price;
  final String categoryId;
}
