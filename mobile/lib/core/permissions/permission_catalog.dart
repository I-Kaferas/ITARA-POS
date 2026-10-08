/// Capability checks used across features (Clean Architecture — core/permissions).
class PermissionCatalog {
  const PermissionCatalog(this.permissions);

  final List<String> permissions;

  static const PermissionCatalog empty = PermissionCatalog([]);

  bool can(String permission) {
    if (permissions.isEmpty) return false;
    if (permissions.contains('*') || permissions.contains('admin')) return true;
    return permissions.contains(permission);
  }

  bool canAny(Iterable<String> required) => required.any(can);

  bool canAll(Iterable<String> required) => required.every(can);

  bool get canSell => canAny(const ['pos.sell', 'sales.create', 'pos.access']);

  bool get canRefund => canAny(const ['sales.refund', 'pos.refund']);

  bool get canManagePrinters =>
      canAny(const ['printers.manage', 'devices.manage', 'settings.manage']);

  bool get canManageDevices =>
      canAny(const ['devices.manage', 'settings.manage']);

  bool get canSync => canAny(const ['sync.run', 'sync.manage', 'admin']);
}
