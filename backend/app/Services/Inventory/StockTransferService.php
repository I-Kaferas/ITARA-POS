<?php

namespace App\Services\Inventory;

use App\Enums\InventoryMovementType;
use App\Enums\StockTransferStatus;
use App\Models\Product;
use App\Models\StockTransfer;
use App\Models\StockTransferItem;
use App\Models\User;
use App\Models\Warehouse;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class StockTransferService
{
    public function __construct(
        private readonly InventoryMovementService $movementService,
    ) {}

    /**
     * @param  list<array{
     *     product_id: string,
     *     quantity: int,
     *     product_variant_id?: string|null,
     *     batch_id?: string|null,
     * }>  $items
     */
    public function create(
        Warehouse $source,
        Warehouse $destination,
        array $items,
        ?User $requestedBy = null,
        ?string $notes = null,
    ): StockTransfer {
        if ($source->id === $destination->id) {
            throw ValidationException::withMessages([
                'destination_warehouse_id' => ['Source and destination warehouses must differ.'],
            ]);
        }

        if ($items === []) {
            throw ValidationException::withMessages([
                'items' => ['At least one item is required.'],
            ]);
        }

        return DB::transaction(function () use ($source, $destination, $items, $requestedBy, $notes): StockTransfer {
            $transfer = StockTransfer::query()->create([
                'tenant_id' => $source->tenant_id,
                'transfer_number' => $this->nextTransferNumber($source->tenant_id),
                'source_warehouse_id' => $source->id,
                'destination_warehouse_id' => $destination->id,
                'status' => StockTransferStatus::Draft,
                'requested_by' => $requestedBy?->id,
                'notes' => $notes,
            ]);

            foreach ($items as $item) {
                Product::query()->findOrFail($item['product_id'])->assertStockable();

                StockTransferItem::query()->create([
                    'tenant_id' => $source->tenant_id,
                    'stock_transfer_id' => $transfer->id,
                    'product_id' => $item['product_id'],
                    'product_variant_id' => $item['product_variant_id'] ?? null,
                    'batch_id' => $item['batch_id'] ?? null,
                    'quantity_requested' => $item['quantity'],
                ]);
            }

            return $transfer->load(['items.product:id,sku,name', 'sourceWarehouse', 'destinationWarehouse']);
        });
    }

    public function confirm(StockTransfer $transfer, ?User $confirmedBy = null): StockTransfer
    {
        if ($transfer->status !== StockTransferStatus::Draft) {
            throw ValidationException::withMessages([
                'status' => ['Seule une saisie peut être confirmée.'],
            ]);
        }

        if ($transfer->items()->count() === 0) {
            throw ValidationException::withMessages([
                'items' => ['Ajoutez au moins un article avant de confirmer.'],
            ]);
        }

        $transfer->update([
            'status' => StockTransferStatus::Pending,
        ]);

        return $transfer->fresh(['items.product:id,sku,name', 'sourceWarehouse', 'destinationWarehouse']);
    }

    public function approve(StockTransfer $transfer, ?User $approvedBy = null): StockTransfer
    {
        if ($transfer->status !== StockTransferStatus::Pending) {
            throw ValidationException::withMessages([
                'status' => ['Seule une demande peut être validée.'],
            ]);
        }

        $transfer->update([
            'status' => StockTransferStatus::Approved,
            'approved_by' => $approvedBy?->id,
        ]);

        return $transfer->fresh(['items.product:id,sku,name', 'sourceWarehouse', 'destinationWarehouse']);
    }

    public function ship(StockTransfer $transfer, ?User $performedBy = null): StockTransfer
    {
        if ($transfer->status !== StockTransferStatus::Approved) {
            throw ValidationException::withMessages([
                'status' => ['Validez le transfert avant l’expédition.'],
            ]);
        }

        $transfer->load(['items.product', 'sourceWarehouse', 'destinationWarehouse']);

        return DB::transaction(function () use ($transfer, $performedBy): StockTransfer {
            foreach ($transfer->items as $item) {
                $quantity = $item->quantity_requested;

                $this->movementService->record([
                    'warehouse' => $transfer->sourceWarehouse,
                    'product' => $item->product,
                    'movement_type' => InventoryMovementType::TransferOut,
                    'quantity' => $quantity,
                    'product_variant_id' => $item->product_variant_id,
                    'batch_id' => $item->batch_id,
                    'reference' => $transfer,
                    'source_warehouse_id' => $transfer->source_warehouse_id,
                    'destination_warehouse_id' => $transfer->destination_warehouse_id,
                    'performed_by' => $performedBy?->id,
                    'notes' => 'Expédition '.$transfer->transfer_number,
                ]);

                $item->update(['quantity_shipped' => $quantity]);
            }

            $transfer->update([
                'status' => StockTransferStatus::InTransit,
                'shipped_at' => now(),
            ]);

            return $transfer->fresh(['items.product:id,sku,name', 'sourceWarehouse', 'destinationWarehouse']);
        });
    }

    public function receive(StockTransfer $transfer, ?User $performedBy = null): StockTransfer
    {
        if ($transfer->status !== StockTransferStatus::InTransit) {
            throw ValidationException::withMessages([
                'status' => ['Le transfert doit être en transport avant la réception.'],
            ]);
        }

        $transfer->load(['items.product', 'sourceWarehouse', 'destinationWarehouse']);

        return DB::transaction(function () use ($transfer, $performedBy): StockTransfer {
            foreach ($transfer->items as $item) {
                $quantity = $item->quantity_shipped ?: $item->quantity_requested;

                $this->movementService->record([
                    'warehouse' => $transfer->destinationWarehouse,
                    'product' => $item->product,
                    'movement_type' => InventoryMovementType::TransferIn,
                    'quantity' => $quantity,
                    'product_variant_id' => $item->product_variant_id,
                    'batch_id' => $item->batch_id,
                    'reference' => $transfer,
                    'source_warehouse_id' => $transfer->source_warehouse_id,
                    'destination_warehouse_id' => $transfer->destination_warehouse_id,
                    'performed_by' => $performedBy?->id,
                    'notes' => 'Réception '.$transfer->transfer_number,
                ]);

                $item->update(['quantity_received' => $quantity]);
            }

            $transfer->update([
                'status' => StockTransferStatus::Completed,
                'received_at' => now(),
            ]);

            return $transfer->fresh(['items.product:id,sku,name', 'sourceWarehouse', 'destinationWarehouse']);
        });
    }

    private function nextTransferNumber(string $tenantId): string
    {
        $count = StockTransfer::query()
            ->where('tenant_id', $tenantId)
            ->count();

        return 'TRF-'.str_pad((string) ($count + 1), 6, '0', STR_PAD_LEFT);
    }
}
