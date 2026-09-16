enum ConnectivityState {
  offline,
  online,
  syncing,
  syncError,
  localAvailable,
  cloudAvailable,
}

enum SyncQueueStatus {
  pending,
  processing,
  synced,
  retrying,
  failed,
  conflict,
}

class SyncSnapshot {
  const SyncSnapshot({
    required this.connectivity,
    required this.pending,
    required this.failed,
    required this.synced,
    required this.conflicts,
    this.lastSyncAt,
    this.lastError,
    this.target,
  });

  final ConnectivityState connectivity;
  final int pending;
  final int failed;
  final int synced;
  final int conflicts;
  final DateTime? lastSyncAt;
  final String? lastError;
  final String? target;

  String get label => switch (connectivity) {
        ConnectivityState.syncing => 'Synchronisation',
        ConnectivityState.offline => 'Hors ligne',
        ConnectivityState.syncError => 'Erreur de synchro',
        ConnectivityState.localAvailable => 'Réseau local',
        ConnectivityState.cloudAvailable => 'Cloud',
        ConnectivityState.online => 'En ligne',
      };
}

/// Détail d'une synchronisation (téléchargement / envoi).
class SyncReport {
  const SyncReport({
    this.ok = true,
    this.message = '',
    this.products = 0,
    this.categories = 0,
    this.customers = 0,
    this.paymentMethods = 0,
    this.units = 0,
    this.users = 0,
    this.roles = 0,
    this.permissions = 0,
    this.currencies = 0,
    this.taxes = 0,
    this.sent = 0,
  });

  final bool ok;
  final String message;
  final int products;
  final int categories;
  final int customers;
  final int paymentMethods;
  final int units;
  final int users;
  final int roles;
  final int permissions;
  final int currencies;
  final int taxes;
  final int sent;

  bool get hasDetails =>
      products > 0 ||
      categories > 0 ||
      customers > 0 ||
      paymentMethods > 0 ||
      units > 0 ||
      users > 0 ||
      roles > 0 ||
      permissions > 0 ||
      currencies > 0 ||
      taxes > 0 ||
      sent > 0;

  List<({String label, int count})> get lines => [
        (label: 'Produits', count: products),
        (label: 'Catégories', count: categories),
        (label: 'Clients', count: customers),
        (label: 'Moyens de paiement', count: paymentMethods),
        (label: 'Unités', count: units),
        (label: 'Utilisateurs', count: users),
        (label: 'Rôles', count: roles),
        (label: 'Permissions', count: permissions),
        (label: 'Devises', count: currencies),
        (label: 'Taxes', count: taxes),
        if (sent > 0) (label: 'Événements envoyés', count: sent),
      ];

  String get summary {
    if (message.isNotEmpty && !hasDetails) return message;
    final parts = <String>[
      if (products > 0) '$products produit${products > 1 ? 's' : ''}',
      if (categories > 0) '$categories catégorie${categories > 1 ? 's' : ''}',
      if (customers > 0) '$customers client${customers > 1 ? 's' : ''}',
      if (paymentMethods > 0) '$paymentMethods moyen${paymentMethods > 1 ? 's' : ''} de paiement',
      if (units > 0) '$units unité${units > 1 ? 's' : ''}',
      if (users > 0) '$users utilisateur${users > 1 ? 's' : ''}',
      if (roles > 0) '$roles rôle${roles > 1 ? 's' : ''}',
      if (permissions > 0) '$permissions permission${permissions > 1 ? 's' : ''}',
      if (currencies > 0) '$currencies devise${currencies > 1 ? 's' : ''}',
      if (taxes > 0) '$taxes taxe${taxes > 1 ? 's' : ''}',
      if (sent > 0) '$sent envoyé${sent > 1 ? 's' : ''}',
    ];
    if (parts.isEmpty) return message.isNotEmpty ? message : 'Rien à synchroniser';
    final detail = parts.join(' · ');
    return message.isEmpty ? detail : '$message\n$detail';
  }

  SyncReport copyWith({
    bool? ok,
    String? message,
    int? products,
    int? categories,
    int? customers,
    int? paymentMethods,
    int? units,
    int? users,
    int? roles,
    int? permissions,
    int? currencies,
    int? taxes,
    int? sent,
  }) {
    return SyncReport(
      ok: ok ?? this.ok,
      message: message ?? this.message,
      products: products ?? this.products,
      categories: categories ?? this.categories,
      customers: customers ?? this.customers,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      units: units ?? this.units,
      users: users ?? this.users,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      currencies: currencies ?? this.currencies,
      taxes: taxes ?? this.taxes,
      sent: sent ?? this.sent,
    );
  }
}
