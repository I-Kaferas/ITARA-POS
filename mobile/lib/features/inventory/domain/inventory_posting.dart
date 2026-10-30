import 'inventory_movement_type.dart';

/// Result of one stock movement written to the local ledger.
class InventoryPosting {
  const InventoryPosting({
    required this.id,
    required this.productId,
    required this.type,
    required this.signedQuantity,
    required this.quantityOnHand,
    this.warehouseId,
    this.alreadyProcessed = false,
  });

  final String id;
  final String productId;
  final InventoryMovementType type;

  /// Base units, positive in, negative out.
  final int signedQuantity;

  /// Catalog on-hand after the movement (what the POS sells from).
  final int quantityOnHand;
  final String? warehouseId;

  /// The movement id was already in the ledger; nothing was applied again.
  final bool alreadyProcessed;
}

class InventoryMovementRecord {
  const InventoryMovementRecord({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.createdAt,
    this.warehouseId,
    this.syncStatus,
  });

  final String id;
  final String productId;
  final String productName;
  final String type;
  final int quantity;
  final DateTime createdAt;
  final String? warehouseId;

  /// Outbox status (`PENDING`, `SYNCED`…); null when never queued.
  final String? syncStatus;

  InventoryMovementType? get movementType => InventoryMovementType.tryParse(type);

  bool get awaitingSync => syncStatus != null && syncStatus != 'SYNCED';
}

class InventoryWarehouse {
  const InventoryWarehouse({required this.id, required this.name, this.isSale = false});

  final String id;
  final String name;
  final bool isSale;

  factory InventoryWarehouse.fromJson(Map<String, dynamic> json, {String? saleWarehouseId}) {
    final id = json['id']?.toString() ?? '';
    final code = json['code']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    return InventoryWarehouse(
      id: id,
      name: name.isNotEmpty ? name : (code.isNotEmpty ? code : id),
      isSale: json['is_sale'] == true || (saleWarehouseId != null && saleWarehouseId == id),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'is_sale': isSale};
}
