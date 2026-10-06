<?php

namespace App\Observers\Realtime;

use App\Models\Product;
use App\Services\Realtime\RealtimePublisher;

class ProductObserver
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function created(Product $product): void
    {
        $this->publisher->notify(
            type: 'product.created',
            tenantId: $product->tenant_id,
            entity: 'product',
            id: $product->id,
            data: $this->snapshot($product),
        );
    }

    public function updated(Product $product): void
    {
        $watched = ['name', 'sku', 'barcode', 'is_active', 'unit_id', 'tax_id', 'category_id', 'base_price', 'cost_price'];
        if (! $product->wasChanged($watched)) {
            return;
        }

        if ($product->wasChanged(['base_price', 'cost_price'])) {
            $this->publisher->notify(
                type: 'product.price.changed',
                tenantId: $product->tenant_id,
                entity: 'product',
                id: $product->id,
                data: [
                    'base_price' => $product->base_price,
                    'cost_price' => $product->cost_price,
                    'previous_base_price' => $product->getOriginal('base_price'),
                ],
            );
        }

        if ($product->wasChanged(['name', 'sku', 'barcode', 'is_active', 'unit_id', 'tax_id', 'category_id'])) {
            $this->publisher->notify(
                type: 'product.updated',
                tenantId: $product->tenant_id,
                entity: 'product',
                id: $product->id,
                status: $product->is_active ? 'active' : 'inactive',
                data: $this->snapshot($product),
            );
        }
    }

    /** @return array<string, mixed> */
    private function snapshot(Product $product): array
    {
        return [
            'name' => $product->name,
            'sku' => $product->sku,
            'base_price' => $product->base_price,
            'is_active' => $product->is_active,
        ];
    }
}
