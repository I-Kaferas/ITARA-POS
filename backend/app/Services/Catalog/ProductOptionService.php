<?php

namespace App\Services\Catalog;

use App\Models\Product;
use App\Models\ProductVariant;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ProductOptionService
{
    private const MAX_GROUPS = 4;

    private const MAX_VALUES = 20;

    private const MAX_COMBINATIONS = 100;

    /**
     * @param  list<array{name: string, values: list<string>, value_prices?: array<string, int>}>  $groups
     * @param  list<array{options: array<string, string>, price: int}>  $prices
     */
    public function transform(Product $product, array $groups, array $prices = []): Product
    {
        if (in_array($product->product_type, ['service', 'digital', 'bundle'], true)) {
            throw ValidationException::withMessages([
                'product' => ['Ce type de produit ne peut pas être transformé en options.'],
            ]);
        }

        $normalized = $this->normalizeGroups($groups);
        $combinations = $this->combinations($normalized);
        $priceBySignature = $this->priceMap($prices);

        if ($combinations === []) {
            throw ValidationException::withMessages([
                'groups' => ['Ajoutez au moins une option.'],
            ]);
        }

        if (count($combinations) > self::MAX_COMBINATIONS) {
            throw ValidationException::withMessages([
                'groups' => ['Trop de combinaisons. Réduisez les options (maximum '.self::MAX_COMBINATIONS.').'],
            ]);
        }

        return DB::transaction(function () use ($product, $normalized, $combinations, $priceBySignature): Product {
            $product->load('variants');
            $existing = $product->variants->keyBy(fn (ProductVariant $variant) => $this->signature($this->optionsOf($variant)));
            $kept = [];

            foreach ($combinations as $index => $options) {
                $signature = $this->signature($options);
                $variant = $existing->get($signature) ?? new ProductVariant([
                    'tenant_id' => $product->tenant_id,
                    'product_id' => $product->id,
                    'sku' => $this->uniqueSku($product, $options),
                    'base_price' => $product->base_price,
                    'cost_price' => $product->cost_price,
                ]);

                $variant->fill([
                    'name' => $product->name.' · '.$this->label($options),
                    'size' => $this->axisValue($options, ['taille', 'size', 'pointure']),
                    'color' => $this->axisValue($options, ['couleur', 'color', 'colour']),
                    'sort_order' => $index,
                    'is_active' => true,
                    'attributes' => ['options' => $options],
                    'base_price' => $priceBySignature[$signature]
                        ?? $variant->base_price
                        ?? $product->base_price,
                ]);
                $variant->save();
                $kept[] = $variant->id;
            }

            ProductVariant::query()
                ->where('product_id', $product->id)
                ->whereNotIn('id', $kept)
                ->update(['is_active' => false]);

            $metadata = $product->metadata ?? [];
            $metadata['option_groups'] = $normalized;

            $product->update([
                'product_type' => 'variant',
                'metadata' => $metadata,
            ]);

            return $product->fresh(['variants']);
        });
    }

    /**
     * @param  list<array{name: string, values: list<string>}>  $groups
     * @return list<array{name: string, values: list<string>}>
     */
    private function normalizeGroups(array $groups): array
    {
        $normalized = [];
        $names = [];

        foreach ($groups as $group) {
            $name = trim((string) ($group['name'] ?? ''));
            $key = mb_strtolower($name);
            if ($name === '' || isset($names[$key])) {
                continue;
            }

            $values = [];
            foreach ($group['values'] ?? [] as $value) {
                $value = trim((string) $value);
                if ($value === '' || in_array($value, $values, true)) {
                    continue;
                }
                $values[] = $value;
                if (count($values) >= self::MAX_VALUES) {
                    break;
                }
            }

            if ($values === []) {
                continue;
            }

            $names[$key] = true;
            $valuePrices = [];
            foreach ($group['value_prices'] ?? [] as $value => $amount) {
                $label = trim((string) $value);
                if ($label === '' || ! in_array($label, $values, true)) {
                    continue;
                }
                $valuePrices[$label] = max(0, (int) $amount);
            }

            $normalized[] = [
                'name' => $name,
                'values' => $values,
                ...($valuePrices !== [] ? ['value_prices' => $valuePrices] : []),
            ];
            if (count($normalized) >= self::MAX_GROUPS) {
                break;
            }
        }

        return $normalized;
    }

    /**
     * @param  list<array{name: string, values: list<string>}>  $groups
     * @return list<array<string, string>>
     */
    private function combinations(array $groups): array
    {
        $result = [[]];

        foreach ($groups as $group) {
            $next = [];
            foreach ($result as $current) {
                foreach ($group['values'] as $value) {
                    $next[] = $current + [$group['name'] => $value];
                }
            }
            $result = $next;
        }

        return array_values(array_filter($result));
    }

    /**
     * @param  list<array{options?: array<string, string>, price?: int}>  $prices
     * @return array<string, int>
     */
    private function priceMap(array $prices): array
    {
        $map = [];
        foreach ($prices as $row) {
            $options = $row['options'] ?? [];
            if (! is_array($options) || $options === []) {
                continue;
            }
            $map[$this->signature($options)] = max(0, (int) ($row['price'] ?? 0));
        }

        return $map;
    }

    /** @param  array<string, string>  $options */
    private function label(array $options): string
    {
        return implode(' / ', array_values($options));
    }

    /** @param  array<string, string>  $options */
    private function signature(array $options): string
    {
        ksort($options);

        return json_encode($options, JSON_UNESCAPED_UNICODE) ?: '';
    }

    /** @return array<string, string> */
    private function optionsOf(ProductVariant $variant): array
    {
        $options = $variant->attributes['options'] ?? null;
        if (is_array($options) && $options !== []) {
            return $options;
        }

        $fallback = [];
        if ($variant->size) {
            $fallback['Taille'] = $variant->size;
        }
        if ($variant->color) {
            $fallback['Couleur'] = $variant->color;
        }

        return $fallback;
    }

    /**
     * @param  array<string, string>  $options
     * @param  list<string>  $names
     */
    private function axisValue(array $options, array $names): ?string
    {
        foreach ($options as $name => $value) {
            if (in_array(mb_strtolower($name), $names, true)) {
                return $value;
            }
        }

        return null;
    }

    /** @param  array<string, string>  $options */
    private function uniqueSku(Product $product, array $options): string
    {
        $parts = array_map(fn (string $value) => $this->slug($value), array_values($options));
        $base = substr($product->sku.'-'.implode('-', $parts), 0, 90);
        $sku = $base;
        $suffix = 2;

        while (ProductVariant::withTrashed()->where('tenant_id', $product->tenant_id)->where('sku', $sku)->exists()) {
            $sku = substr($base, 0, 90).'-'.$suffix;
            $suffix++;
        }

        return $sku;
    }

    private function slug(string $value): string
    {
        $slug = strtoupper((string) preg_replace('/[^A-Za-z0-9]+/', '', $value));

        return $slug !== '' ? substr($slug, 0, 12) : 'OPT';
    }
}
