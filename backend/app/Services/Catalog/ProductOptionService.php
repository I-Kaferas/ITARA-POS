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
     * @param  list<array{name: string, values: list<string>}>  $groups
     */
    public function transform(Product $product, array $groups): Product
    {
        if (in_array($product->product_type, ['service', 'digital', 'bundle'], true)) {
            throw ValidationException::withMessages([
                'product' => ['Ce type de produit ne peut pas être transformé en options.'],
            ]);
        }

        $normalized = $this->normalizeGroups($groups);
        $combinations = $this->combinations($normalized);

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

        return DB::transaction(function () use ($product, $normalized, $combinations): Product {
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
            $normalized[] = ['name' => $name, 'values' => $values];
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
