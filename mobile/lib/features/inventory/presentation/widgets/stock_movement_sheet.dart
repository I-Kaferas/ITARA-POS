import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/i18n/tr.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../pos/domain/pos_models.dart';
import '../../../pos/presentation/widgets/pos_ui.dart';
import '../../domain/inventory_movement_type.dart';
import '../../domain/inventory_posting.dart';
import '../../domain/unit_converter.dart';
import '../bloc/inventory_bloc.dart';

/// Form for one stock movement or a depot transfer. Pops the event to submit.
class StockMovementSheet extends StatefulWidget {
  const StockMovementSheet({
    super.key,
    required this.product,
    required this.units,
    required this.warehouses,
    this.transfer = false,
    this.initialType = InventoryMovementType.purchase,
  });

  final PosProduct product;
  final List<InventoryUnit> units;
  final List<InventoryWarehouse> warehouses;
  final bool transfer;
  final InventoryMovementType initialType;

  @override
  State<StockMovementSheet> createState() => _StockMovementSheetState();
}

class _StockMovementSheetState extends State<StockMovementSheet> {
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  late InventoryMovementType _type = widget.initialType;
  late InventoryUnit _unit = widget.units.first;
  String? _warehouseId;
  String? _destinationId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final sale = widget.warehouses.where((w) => w.isSale).firstOrNull ?? widget.warehouses.firstOrNull;
    _warehouseId = sale?.id;
    _destinationId = widget.warehouses.where((w) => w.id != _warehouseId).firstOrNull?.id;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  num? get _entered => num.tryParse(_quantity.text.trim().replaceAll(',', '.'));

  int? get _baseQuantity {
    final value = _entered;
    if (value == null || value <= 0) return null;
    try {
      return UnitConverter.toBase(quantity: value, factor: _unit.factor);
    } on UnitConversionException {
      return null;
    }
  }

  void _submit() {
    final quantity = _entered;
    if (quantity == null || quantity <= 0 || _baseQuantity == null) {
      setState(() => _error = tr('Saisissez une quantité valide'));
      return;
    }
    final reason = _reason.text.trim();
    if (widget.transfer) {
      if (_warehouseId == null || _destinationId == null || _warehouseId == _destinationId) {
        setState(() => _error = tr('Choisissez deux dépôts différents'));
        return;
      }
      Navigator.of(context).pop(InventoryTransferSubmitted(
        product: widget.product,
        quantity: quantity,
        unit: _unit,
        sourceWarehouseId: _warehouseId!,
        destinationWarehouseId: _destinationId!,
        reason: reason.isEmpty ? null : reason,
      ));
      return;
    }
    if (_type.isWaste && reason.isEmpty) {
      setState(() => _error = tr('Indiquez le motif de la casse ou de la perte'));
      return;
    }
    Navigator.of(context).pop(InventoryMovementSubmitted(
      product: widget.product,
      type: _type,
      quantity: quantity,
      unit: _unit,
      warehouseId: _warehouseId,
      reason: reason.isEmpty ? null : reason,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final onHand = widget.product.quantityOnHand ?? 0;
    final base = _baseQuantity;
    final preview = base == null
        ? null
        : widget.transfer
            ? onHand
            : onHand + _type.sign * base;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.transfer ? tr('Transfert entre dépôts') : tr('Mouvement de stock'),
              style: PosUi.cardTitle(),
            ),
            const SizedBox(height: 4),
            Text(
              trf('{0} · en stock {1}', [widget.product.name, onHand]),
              style: PosUi.caption(),
            ),
            const SizedBox(height: 14),
            if (!widget.transfer) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in InventoryMovementType.manual)
                    ChoiceChip(
                      label: Text(tr(type.label)),
                      selected: _type == type,
                      selectedColor: type.isInbound ? AppColors.successBg : AppColors.dangerBg,
                      onSelected: (_) => setState(() {
                        _type = type;
                        _error = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            if (widget.warehouses.length > 1) ...[
              DropdownButtonFormField<String>(
                initialValue: _warehouseId,
                decoration: InputDecoration(
                  labelText: widget.transfer ? tr('Dépôt source') : tr('Dépôt'),
                ),
                items: [
                  for (final warehouse in widget.warehouses)
                    DropdownMenuItem(
                      value: warehouse.id,
                      child: Text(warehouse.isSale ? '${warehouse.name} · ${tr('vente')}' : warehouse.name),
                    ),
                ],
                onChanged: (value) => setState(() => _warehouseId = value),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.transfer) ...[
              DropdownButtonFormField<String>(
                initialValue: _destinationId,
                decoration: InputDecoration(labelText: tr('Dépôt de destination')),
                items: [
                  for (final warehouse in widget.warehouses)
                    DropdownMenuItem(value: warehouse.id, child: Text(warehouse.name)),
                ],
                onChanged: (value) => setState(() => _destinationId = value),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantity,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: InputDecoration(labelText: tr('Quantité')),
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                if (widget.units.length > 1) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit.id,
                      decoration: InputDecoration(labelText: tr('Unité')),
                      items: [
                        for (final unit in widget.units)
                          DropdownMenuItem(value: unit.id, child: Text(tr(unit.label), overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (value) => setState(() {
                        _unit = widget.units.firstWhere((unit) => unit.id == value);
                      }),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              decoration: InputDecoration(
                labelText: _type.isWaste && !widget.transfer ? tr('Motif (obligatoire)') : tr('Motif / référence'),
              ),
            ),
            const SizedBox(height: 12),
            if (base != null)
              Text(
                widget.transfer
                    ? trf('{0} unités de base déplacées', [base])
                    : trf('{0} unités de base · stock après : {1}', ['${_type.sign > 0 ? '+' : '−'}$base', preview]),
                style: PosUi.body(color: (preview ?? 0) < 0 ? AppColors.danger : AppColors.textSecondary),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: PosUi.body(color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            AppButton.primary(
              label: widget.transfer ? tr('Transférer') : tr('Enregistrer'),
              icon: widget.transfer ? Icons.swap_horiz : Icons.check,
              expanded: true,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
