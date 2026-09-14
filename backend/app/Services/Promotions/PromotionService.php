<?php

namespace App\Services\Promotions;

use App\Models\Customer;
use App\Models\Promotion;
use App\Models\Store;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class PromotionService
{
    public function __construct(
        private readonly PromotionEngine $promotionEngine,
    ) {}

    /** @param  array<string, mixed>  $data */
    public function create(array $data): Promotion
    {
        return DB::transaction(function () use ($data) {
            $promotion = Promotion::query()->create($this->attributes($data));
            $this->syncItems($promotion, $data['items'] ?? []);
            $this->syncCustomers($promotion, $data['customer_ids'] ?? []);

            return $promotion->load(['items.product', 'customers.customer', 'category', 'store']);
        });
    }

    /** @param  array<string, mixed>  $data */
    public function update(Promotion $promotion, array $data): Promotion
    {
        return DB::transaction(function () use ($promotion, $data) {
            $promotion->update($this->attributes($data, partial: true));

            if (array_key_exists('items', $data)) {
                $this->syncItems($promotion, $data['items'] ?? []);
            }

            if (array_key_exists('customer_ids', $data)) {
                $this->syncCustomers($promotion, $data['customer_ids'] ?? []);
            }

            return $promotion->load(['items.product', 'customers.customer', 'category', 'store']);
        });
    }

    /** @return Collection<int, Promotion> */
    public function activeForStore(Store $store, ?Customer $customer = null): Collection
    {
        return $this->promotionEngine->eligible($store, $customer)
            ->load(['items', 'customers', 'category', 'store']);
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private function attributes(array $data, bool $partial = false): array
    {
        $keys = [
            'name',
            'code',
            'type',
            'description',
            'store_id',
            'category_id',
            'starts_at',
            'ends_at',
            'min_quantity',
            'max_uses',
            'priority',
            'discount_percent',
            'discount_amount',
            'buy_quantity',
            'get_quantity',
            'bundle_price',
            'schedule',
            'is_active',
        ];

        $attributes = [];
        foreach ($keys as $key) {
            if (! $partial || array_key_exists($key, $data)) {
                $attributes[$key] = $data[$key] ?? null;
            }
        }

        if (! $partial) {
            $attributes['min_quantity'] = $data['min_quantity'] ?? 1;
            $attributes['priority'] = $data['priority'] ?? 0;
            $attributes['is_active'] = $data['is_active'] ?? true;
            $attributes['uses_count'] = 0;
        }

        if (array_key_exists('code', $attributes) && $attributes['code'] === '') {
            $attributes['code'] = null;
        }

        return $attributes;
    }

    /** @param  list<array<string, mixed>>  $items */
    private function syncItems(Promotion $promotion, array $items): void
    {
        $promotion->items()->delete();

        foreach ($items as $item) {
            if (empty($item['product_id']) && empty($item['product_variant_id'])) {
                continue;
            }

            $promotion->items()->create([
                'product_id' => $item['product_id'] ?? null,
                'product_variant_id' => $item['product_variant_id'] ?? null,
                'role' => $item['role'] ?? 'target',
                'quantity' => $item['quantity'] ?? 1,
            ]);
        }
    }

    /** @param  list<string>  $customerIds */
    private function syncCustomers(Promotion $promotion, array $customerIds): void
    {
        $promotion->customers()->delete();

        foreach (array_unique($customerIds) as $customerId) {
            $promotion->customers()->create([
                'customer_id' => $customerId,
            ]);
        }
    }
}
