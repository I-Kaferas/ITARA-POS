<?php

namespace App\Services\Catalog;

use App\Models\Barcode;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Models\Store;
use App\Models\StoreProduct;
use Illuminate\Database\QueryException;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

class BarcodeService
{
    /** @param  list<array{barcode: string, type?: string, is_primary?: bool}>  $barcodes */
    public function syncForModel(Product|ProductVariant $model, array $barcodes): void
    {
        $tenantId = $model->tenant_id;
        $keptValues = [];

        foreach ($barcodes as $index => $item) {
            $type = $item['type'] ?? BarcodeValidator::detectType($item['barcode']);
            BarcodeValidator::validate($item['barcode'], $type);

            $isPrimary = $item['is_primary'] ?? ($index === 0);

            if ($isPrimary) {
                Barcode::query()
                    ->where('barcodeable_type', $model->getMorphClass())
                    ->where('barcodeable_id', $model->id)
                    ->update(['is_primary' => false]);
            }

            try {
                Barcode::query()->updateOrCreate(
                    [
                        'tenant_id' => $tenantId,
                        'barcode' => $item['barcode'],
                    ],
                    [
                        'barcodeable_type' => $model->getMorphClass(),
                        'barcodeable_id' => $model->id,
                        'type' => $type,
                        'is_primary' => $isPrimary,
                    ],
                );
            } catch (QueryException) {
                throw ValidationException::withMessages([
                    'barcode' => ["Barcode {$item['barcode']} is already assigned to another product."],
                ]);
            }

            $keptValues[] = $item['barcode'];
        }

        $query = Barcode::query()
            ->where('tenant_id', $tenantId)
            ->where('barcodeable_type', $model->getMorphClass())
            ->where('barcodeable_id', $model->id);

        if ($keptValues !== []) {
            $query->whereNotIn('barcode', $keptValues);
        }

        $query->get()->each(fn (Barcode $orphan) => $orphan->delete());

        $this->refreshDenormalizedBarcode($model);
    }

    public function create(Product|ProductVariant $model, string $barcode, string $type = 'internal', bool $isPrimary = false): Barcode
    {
        BarcodeValidator::validate($barcode, $type);

        if ($isPrimary) {
            Barcode::query()
                ->where('barcodeable_type', $model->getMorphClass())
                ->where('barcodeable_id', $model->id)
                ->update(['is_primary' => false]);
        }

        try {
            $record = Barcode::query()->create([
                'tenant_id' => $model->tenant_id,
                'barcodeable_type' => $model->getMorphClass(),
                'barcodeable_id' => $model->id,
                'barcode' => $barcode,
                'type' => $type,
                'is_primary' => $isPrimary,
            ]);
        } catch (QueryException) {
            throw ValidationException::withMessages([
                'barcode' => ['This barcode is already assigned to another product.'],
            ]);
        }

        $this->refreshDenormalizedBarcode($model, $isPrimary ? $barcode : null);

        return $record;
    }

    public function update(Barcode $barcode, array $data): Barcode
    {
        $type = $data['type'] ?? $barcode->type;
        $value = $data['barcode'] ?? $barcode->barcode;

        BarcodeValidator::validate($value, $type);

        $model = $barcode->barcodeable;

        if (($data['is_primary'] ?? false) && $model) {
            Barcode::query()
                ->where('barcodeable_type', $model->getMorphClass())
                ->where('barcodeable_id', $model->id)
                ->update(['is_primary' => false]);
        }

        try {
            $barcode->update([
                'barcode' => $value,
                'type' => $type,
                'is_primary' => $data['is_primary'] ?? $barcode->is_primary,
            ]);
        } catch (QueryException) {
            throw ValidationException::withMessages([
                'barcode' => ['This barcode is already assigned to another product.'],
            ]);
        }

        if ($model) {
            $this->refreshDenormalizedBarcode($model);
        }

        return $barcode->fresh();
    }

    public function delete(Barcode $barcode): void
    {
        $model = $barcode->barcodeable;
        $barcode->delete();

        if ($model) {
            $this->refreshDenormalizedBarcode($model);
        }
    }

    public function generate(string $tenantId, string $type = 'internal'): array
    {
        $attempts = 0;

        do {
            $value = $this->buildGeneratedValue($tenantId, $type);
            $exists = Barcode::query()
                ->where('tenant_id', $tenantId)
                ->where('barcode', $value)
                ->exists();
            $attempts++;
        } while ($exists && $attempts < 10);

        if ($exists) {
            throw ValidationException::withMessages([
                'barcode' => ['Unable to generate a unique barcode. Please retry.'],
            ]);
        }

        return [
            'barcode' => $value,
            'type' => $type,
        ];
    }

    /**
     * @return array{found: bool, barcode?: Barcode, product?: Product, variant?: ProductVariant}
     */
    public function lookup(string $tenantId, string $code, ?string $storeId = null): array
    {
        $code = trim($code);

        $barcode = Barcode::query()
            ->where('tenant_id', $tenantId)
            ->where('barcode', $code)
            ->with(['barcodeable'])
            ->first();

        if (! $barcode) {
            return ['found' => false];
        }

        $product = null;
        $variant = null;

        if ($barcode->barcodeable instanceof Product) {
            $product = $barcode->barcodeable;
        } elseif ($barcode->barcodeable instanceof ProductVariant) {
            $variant = $barcode->barcodeable;
            $product = $variant->product;
        }

        if ($storeId && $product) {
            $imported = StoreProduct::query()
                ->where('store_id', $storeId)
                ->where('product_id', $product->id)
                ->where('is_available', true)
                ->exists();

            if (! $imported) {
                return ['found' => false];
            }
        }

        return [
            'found' => true,
            'barcode' => $barcode,
            'product' => $product?->load(['barcodes', 'variants.barcodes', 'images']),
            'variant' => $variant?->load('barcodes'),
        ];
    }

    /** @return Collection<int, Barcode> */
    public function search(string $tenantId, string $query, int $limit = 25): Collection
    {
        $query = trim($query);

        if ($query === '') {
            return collect();
        }

        return Barcode::query()
            ->where('tenant_id', $tenantId)
            ->where('barcode', 'like', "%{$query}%")
            ->with(['barcodeable'])
            ->orderByDesc('is_primary')
            ->limit($limit)
            ->get();
    }

    /** @return array<string, mixed> */
    public function printPayload(Barcode $barcode): array
    {
        $model = $barcode->barcodeable;
        $label = 'Product';

        if ($model instanceof Product) {
            $label = $model->name;
        } elseif ($model instanceof ProductVariant) {
            $label = trim(($model->product?->name ?? '').' '.($model->name ?? $model->sku));
        }

        return [
            'barcode' => $barcode->barcode,
            'type' => $barcode->type,
            'type_label' => config("product_types.barcode_types.{$barcode->type}", $barcode->type),
            'label' => $label,
            'is_primary' => $barcode->is_primary,
            'barcodeable_type' => $barcode->barcodeable_type,
            'barcodeable_id' => $barcode->barcodeable_id,
        ];
    }

    /**
     * Barcode index for POS offline lookup.
     *
     * @return list<array<string, mixed>>
     */
    public function indexForStore(Store $store): array
    {
        return StoreProduct::query()
            ->where('store_id', $store->id)
            ->where('is_available', true)
            ->with([
                'product.barcodes',
                'product.variants' => fn ($q) => $q->where('is_active', true)->with('barcodes'),
            ])
            ->get()
            ->flatMap(function (StoreProduct $storeProduct) {
                $entries = [];

                foreach ($storeProduct->product->barcodes as $barcode) {
                    $entries[] = $this->indexEntry($barcode, $storeProduct->product_id);
                }

                foreach ($storeProduct->product->variants as $variant) {
                    foreach ($variant->barcodes as $barcode) {
                        $entries[] = $this->indexEntry($barcode, $storeProduct->product_id, $variant->id);
                    }
                }

                return $entries;
            })
            ->values()
            ->all();
    }

    private function refreshDenormalizedBarcode(Product|ProductVariant $model, ?string $forcedBarcode = null): void
    {
        if (! $model instanceof Product) {
            return;
        }

        $model->update([
            'barcode' => $forcedBarcode ?? $model->primaryBarcode()?->barcode,
        ]);
    }

    /** @return array<string, mixed> */
    private function indexEntry(Barcode $barcode, string $productId, ?string $variantId = null): array
    {
        return [
            'barcode' => $barcode->barcode,
            'type' => $barcode->type,
            'is_primary' => $barcode->is_primary,
            'product_id' => $productId,
            'variant_id' => $variantId,
        ];
    }

    private function buildGeneratedValue(string $tenantId, string $type): string
    {
        $sequence = Barcode::query()->where('tenant_id', $tenantId)->count() + 1;

        return match ($type) {
            'ean13' => $this->generateEan13($sequence),
            'ean8' => $this->generateEan8($sequence),
            'upc' => $this->generateUpc($sequence),
            'code128' => 'C128-'.str_pad((string) $sequence, 10, '0', STR_PAD_LEFT),
            'qr' => 'QR-'.strtoupper(substr(md5((string) microtime(true)), 0, 8)).'-'.$sequence,
            default => 'INT-'.str_pad((string) $sequence, 10, '0', STR_PAD_LEFT),
        };
    }

    private function generateEan13(int $sequence): string
    {
        $body = '200'.str_pad((string) $sequence, 9, '0', STR_PAD_LEFT);

        return $body.BarcodeValidator::computeEanCheckDigit($body);
    }

    private function generateEan8(int $sequence): string
    {
        $body = '20'.str_pad((string) $sequence, 5, '0', STR_PAD_LEFT);

        return $body.BarcodeValidator::computeEanCheckDigit($body);
    }

    private function generateUpc(int $sequence): string
    {
        $body = '02'.str_pad((string) $sequence, 8, '0', STR_PAD_LEFT);
        $eanBody = '0'.$body;

        return $body.BarcodeValidator::computeEanCheckDigit($eanBody);
    }
}
