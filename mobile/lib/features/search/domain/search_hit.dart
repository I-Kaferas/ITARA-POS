class SearchHit {
  const SearchHit({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final SearchKind kind;
  final String id;
  final String title;
  final String subtitle;
}

enum SearchKind {
  product,
  sale,
  customer,
  order,
  table,
  supplier;

  String get label => switch (this) {
        SearchKind.product => 'Produits',
        SearchKind.sale => 'Ventes',
        SearchKind.customer => 'Clients',
        SearchKind.order => 'Commandes',
        SearchKind.table => 'Tables',
        SearchKind.supplier => 'Fournisseurs',
      };
}
