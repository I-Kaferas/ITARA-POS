<?php

namespace App\Services\Catalog;

use App\DTOs\Catalog\ResolvedPrice;
use App\Enums\PriceType;
use App\Models\Company;
use App\Models\Price;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Models\Store;
use App\Models\StoreProduct;
use Carbon\Carbon;

class PriceService
{
    /** @param  list<array<string, mixed>>  $prices */
    public function syncForModel(Product|ProductVariant $model, array $prices): void
    {
        if ($prices === []) {
            return;
        }

        foreach ($prices as $item) {
            $existing = null;
            if (! empty($item['id'])) {
                $existing = $model->prices()->whereKey($item['id'])->first();
            }
            if (! $existing && ! empty($item['price_type'])) {
                $existing = $model->prices()
                    ->where('price_type', $item['price_type'])
                    ->where('store_id', $item['store_id'] ?? null)
                    ->where('currency_code', strtoupper($item['currency_code'] ?? $this->resolveCurrencyCode($model)))
                    ->where('min_quantity', $item['min_quantity'] ?? 1)
                    ->first();
            }
            $this->createOrUpdate($model, $item, $existing);
        }

        $base = collect($prices)->firstWhere('price_type', 'base')
            ?? collect($prices)->firstWhere('price_type', 'retail')
            ?? collect($prices)->first();

        if ($base && isset($base['amount'])) {
            $model->update(['base_price' => (int) $base['amount']]);
        }
    }

    /** @param  array<string, mixed>  $data */
    public function createOrUpdate(Product|ProductVariant $model, array $data, ?Price $existing = null): Price
    {
        $payload = [
            'tenant_id' => $model->tenant_id,
            'priceable_type' => $model->getMorphClass(),
            'priceable_id' => $model->id,
            'price_type' => $data['price_type'] ?? 'base',
            'amount' => (int) $data['amount'],
            'currency_code' => $data['currency_code'] ?? $this->resolveCurrencyCode($model),
            'store_id' => $data['store_id'] ?? null,
            'min_quantity' => $data['min_quantity'] ?? 1,
            'valid_from' => $data['valid_from'] ?? null,
            'valid_until' => $data['valid_until'] ?? null,
            'is_active' => $data['is_active'] ?? true,
        ];

        if ($existing) {
            $existing->update($payload);

            return $existing->fresh();
        }

        return Price::query()->create($payload);
    }

    public function resolve(
        Product|ProductVariant $model,
        ?Store $store = null,
        string $priceType = 'retail',
        int $quantity = 1,
        ?Carbon $at = null,
        ?string $currency = null,
    ): ResolvedPrice {
        $at ??= now();

        foreach ($this->resolutionChain($priceType) as $type) {
            $tier = $this->findActiveTier($model, $type, $store, $quantity, $at);

            if ($tier !== null) {
                return $this->inCurrency(new ResolvedPrice(
                    amount: $tier->amount,
                    priceType: $type,
                    source: 'tier',
                    priceId: $tier->id,
                    currencyCode: strtoupper($tier->currency_code ?: $this->resolveCurrencyCode($model)),
                ), $currency);
            }
        }

        return $this->inCurrency(new ResolvedPrice(
            amount: $model->base_price,
            priceType: $priceType,
            source: 'base_fallback',
            currencyCode: $this->resolveCurrencyCode($model),
        ), $currency);
    }

    public function resolveForStoreProduct(
        StoreProduct $storeProduct,
        string $priceType = 'retail',
        int $quantity = 1,
        ?Carbon $at = null,
    ): ResolvedPrice {
        if ($storeProduct->price_override !== null) {
            return new ResolvedPrice(
                amount: $storeProduct->price_override,
                priceType: $priceType,
                source: 'store_override',
                currencyCode: $this->resolveCurrencyCode($storeProduct->product),
            );
        }

        $store = $storeProduct->relationLoaded('store')
            ? $storeProduct->store
            : $storeProduct->store()->first();

        $product = $storeProduct->relationLoaded('product')
            ? $storeProduct->product
            : $storeProduct->product()->first();

        return $this->resolve($product, $store, $priceType, $quantity, $at);
    }

    /**
     * Active sellable tier amounts for POS sync.
     *
     * @return array<string, int>
     */
    public function activeTiersForModel(
        Product|ProductVariant $model,
        ?Store $store = null,
        int $quantity = 1,
        ?Carbon $at = null,
    ): array {
        $tiers = [];

        foreach (PriceType::sellableValues() as $priceType) {
            $resolved = $this->resolve($model, $store, $priceType, $quantity, $at);
            $tiers[$priceType] = $resolved->amount;
        }

        return $tiers;
    }

    /** @return list<string> */
    private function resolutionChain(string $priceType): array
    {
        $chain = [$priceType];

        if ($priceType !== PriceType::Retail->value) {
            $chain[] = PriceType::Retail->value;
        }

        if ($priceType !== PriceType::Base->value) {
            $chain[] = PriceType::Base->value;
        }

        return array_values(array_unique($chain));
    }

    private function findActiveTier(
        Product|ProductVariant $model,
        string $priceType,
        ?Store $store,
        int $quantity,
        Carbon $at,
    ): ?Price {
        $query = $model->prices()
            ->where('is_active', true)
            ->where('price_type', $priceType)
            ->where('min_quantity', '<=', max(1, $quantity))
            ->where(fn ($q) => $q->whereNull('valid_from')->orWhere('valid_from', '<=', $at))
            ->where(fn ($q) => $q->whereNull('valid_until')->orWhere('valid_until', '>=', $at));

        if ($store) {
            $storePrice = (clone $query)
                ->where('store_id', $store->id)
                ->orderByDesc('min_quantity')
                ->first();

            if ($storePrice) {
                return $storePrice;
            }
        }

        return $query
            ->whereNull('store_id')
            ->orderByDesc('min_quantity')
            ->first();
    }

    private function resolveCurrencyCode(Product|ProductVariant $model): string
    {
        $product = $model instanceof ProductVariant
            ? ($model->relationLoaded('product') ? $model->product : $model->product()->first())
            : $model;

        if ($product) {
            $product->loadMissing('catalog.company');
            $code = $product->catalog?->company?->currency_code;
            if ($code) {
                return strtoupper($code);
            }
        }

        $companyCode = Company::query()->where('is_active', true)->value('currency_code');

        return strtoupper($companyCode ?: 'FBU');
    }

    private function inCurrency(ResolvedPrice $price, ?string $currency): ResolvedPrice
    {
        $target = strtoupper(trim((string) $currency));
        if ($target === '' || $target === strtoupper((string) $price->currencyCode)) {
            return $price;
        }

        return new ResolvedPrice(
            amount: app(CurrencyConverter::class)->convert($price->amount, (string) $price->currencyCode, $target),
            priceType: $price->priceType,
            source: $price->source,
            priceId: $price->priceId,
            currencyCode: $target,
        );
    }
}
