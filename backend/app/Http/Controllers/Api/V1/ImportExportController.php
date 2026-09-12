<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Catalog;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ImportExportController extends Controller
{
    public function exportProducts(Request $request): StreamedResponse
    {
        $catalogId = $request->string('catalog_id')->toString() ?: null;

        $query = Product::query()->orderBy('sku');
        if ($catalogId) {
            $query->where('catalog_id', $catalogId);
        }

        return response()->streamDownload(function () use ($query) {
            $out = fopen('php://output', 'w');
            fputcsv($out, [
                'sku', 'name', 'description', 'barcode', 'product_type',
                'base_price', 'cost_price', 'is_active', 'track_batch',
                'is_serialized', 'low_stock_threshold', 'category_id', 'brand_id', 'unit_id', 'tax_id',
            ]);

            foreach ($query->cursor() as $product) {
                fputcsv($out, [
                    $product->sku,
                    $product->name,
                    $product->description,
                    $product->barcode,
                    $product->product_type,
                    $product->base_price,
                    $product->cost_price,
                    $product->is_active ? 1 : 0,
                    $product->track_batch ? 1 : 0,
                    $product->is_serialized ? 1 : 0,
                    $product->low_stock_threshold,
                    $product->category_id,
                    $product->brand_id,
                    $product->unit_id,
                    $product->tax_id,
                ]);
            }

            fclose($out);
        }, 'products-export.csv', [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }

    public function importProducts(Request $request): JsonResponse
    {
        $data = $request->validate([
            'catalog_id' => ['required', 'uuid', 'exists:catalogs,id'],
            'file' => ['required', 'file', 'mimes:csv,txt', 'max:10240'],
            'update_existing' => ['boolean'],
        ]);

        $catalog = Catalog::query()->findOrFail($data['catalog_id']);
        $updateExisting = $request->boolean('update_existing', true);

        $handle = fopen($request->file('file')->getRealPath(), 'r');
        if ($handle === false) {
            return response()->json(['message' => 'Unable to read file.'], 422);
        }

        $header = fgetcsv($handle);
        if (! $header) {
            fclose($handle);

            return response()->json(['message' => 'Empty CSV file.'], 422);
        }

        $header = array_map(fn ($h) => strtolower(trim((string) $h)), $header);
        $created = 0;
        $updated = 0;
        $skipped = 0;
        $errors = [];
        $rowNumber = 1;

        while (($row = fgetcsv($handle)) !== false) {
            $rowNumber++;
            if (count(array_filter($row, fn ($v) => $v !== null && $v !== '')) === 0) {
                continue;
            }

            $mapped = [];
            foreach ($header as $i => $key) {
                $mapped[$key] = $row[$i] ?? null;
            }

            $sku = trim((string) ($mapped['sku'] ?? ''));
            $name = trim((string) ($mapped['name'] ?? ''));

            if ($sku === '' || $name === '') {
                $skipped++;
                $errors[] = "Row {$rowNumber}: sku and name are required.";
                continue;
            }

            $payload = [
                'name' => $name,
                'description' => $mapped['description'] ?? null,
                'barcode' => $mapped['barcode'] ?? null,
                'product_type' => $mapped['product_type'] ?? 'standard',
                'base_price' => (int) ($mapped['base_price'] ?? 0),
                'cost_price' => (int) ($mapped['cost_price'] ?? 0),
                'is_active' => filter_var($mapped['is_active'] ?? true, FILTER_VALIDATE_BOOLEAN),
                'track_batch' => filter_var($mapped['track_batch'] ?? false, FILTER_VALIDATE_BOOLEAN),
                'is_serialized' => filter_var($mapped['is_serialized'] ?? false, FILTER_VALIDATE_BOOLEAN),
                'low_stock_threshold' => isset($mapped['low_stock_threshold']) && $mapped['low_stock_threshold'] !== ''
                    ? (int) $mapped['low_stock_threshold']
                    : null,
                'category_id' => $this->nullableUuid($mapped['category_id'] ?? null),
                'brand_id' => $this->nullableUuid($mapped['brand_id'] ?? null),
                'unit_id' => $this->nullableUuid($mapped['unit_id'] ?? null),
                'tax_id' => $this->nullableUuid($mapped['tax_id'] ?? null),
            ];

            $existing = Product::query()
                ->where('catalog_id', $catalog->id)
                ->where('sku', $sku)
                ->first();

            try {
                if ($existing) {
                    if ($updateExisting) {
                        $existing->update($payload);
                        $updated++;
                    } else {
                        $skipped++;
                    }
                } else {
                    Product::query()->create([
                        ...$payload,
                        'tenant_id' => $catalog->tenant_id,
                        'catalog_id' => $catalog->id,
                        'sku' => $sku,
                    ]);
                    $created++;
                }
            } catch (\Throwable $e) {
                $skipped++;
                $errors[] = "Row {$rowNumber}: ".$e->getMessage();
            }
        }

        fclose($handle);

        return response()->json([
            'data' => [
                'created' => $created,
                'updated' => $updated,
                'skipped' => $skipped,
                'errors' => array_slice($errors, 0, 50),
            ],
        ]);
    }

    public function productTemplate(): StreamedResponse
    {
        return response()->streamDownload(function () {
            $out = fopen('php://output', 'w');
            fputcsv($out, [
                'sku', 'name', 'description', 'barcode', 'product_type',
                'base_price', 'cost_price', 'is_active', 'track_batch',
                'is_serialized', 'low_stock_threshold', 'category_id', 'brand_id', 'unit_id', 'tax_id',
            ]);
            fputcsv($out, [
                'DEMO-001', 'Produit exemple', 'Description', '', 'standard',
                1500, 1000, 1, 0, 0, 5, '', '', '', '',
            ]);
            fclose($out);
        }, 'products-import-template.csv', [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }

    private function nullableUuid(mixed $value): ?string
    {
        $value = is_string($value) ? trim($value) : $value;
        if (! $value) {
            return null;
        }

        return (string) $value;
    }
}
