<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Barcode;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Models\Store;
use App\Services\Catalog\BarcodeService;
use App\Services\Catalog\BarcodeValidator;
use App\Tenancy\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class BarcodeController extends Controller
{
    public function __construct(
        private BarcodeService $barcodes,
        private TenantContext $tenantContext,
    ) {}

    public function types(): JsonResponse
    {
        return response()->json([
            'data' => collect(config('product_types.barcode_types'))
                ->map(fn ($label, $slug) => ['slug' => $slug, 'label' => $label])
                ->values(),
        ]);
    }

    public function lookup(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code' => ['required', 'string', 'max:100'],
            'store_id' => ['nullable', 'uuid', 'exists:stores,id'],
        ]);

        $tenantId = $this->tenantContext->requireId();
        $result = $this->barcodes->lookup($tenantId, $data['code'], $data['store_id'] ?? null);

        if (! $result['found']) {
            return response()->json(['found' => false, 'data' => null], 404);
        }

        return response()->json([
            'found' => true,
            'data' => [
                'barcode' => $result['barcode'],
                'product' => $result['product'],
                'variant' => $result['variant'],
            ],
        ]);
    }

    public function search(Request $request): JsonResponse
    {
        $data = $request->validate([
            'q' => ['required', 'string', 'min:1', 'max:100'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $tenantId = $this->tenantContext->requireId();
        $results = $this->barcodes->search($tenantId, $data['q'], $data['limit'] ?? 25);

        return response()->json(['data' => $results]);
    }

    public function generate(Request $request): JsonResponse
    {
        $data = $request->validate([
            'type' => ['nullable', 'string', Rule::in(BarcodeValidator::supportedTypes())],
        ]);

        $tenantId = $this->tenantContext->requireId();
        $generated = $this->barcodes->generate($tenantId, $data['type'] ?? 'internal');

        return response()->json(['data' => $generated]);
    }

    public function printLabel(Barcode $barcode): JsonResponse
    {
        $this->ensureTenantBarcode($barcode);

        return response()->json(['data' => $this->barcodes->printPayload($barcode)]);
    }

    public function indexForStore(Store $store): JsonResponse
    {
        return response()->json(['data' => $this->barcodes->indexForStore($store)]);
    }

    public function indexForProduct(Product $product): JsonResponse
    {
        return response()->json(['data' => $product->barcodes()->orderByDesc('is_primary')->get()]);
    }

    public function storeForProduct(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'barcode' => ['required', 'string', 'max:100'],
            'type' => ['nullable', 'string', Rule::in(BarcodeValidator::supportedTypes())],
            'is_primary' => ['boolean'],
        ]);

        $type = $data['type'] ?? BarcodeValidator::detectType($data['barcode']);

        $barcode = $this->barcodes->create(
            $product,
            $data['barcode'],
            $type,
            $data['is_primary'] ?? false,
        );

        return response()->json(['data' => $barcode], 201);
    }

    public function indexForVariant(ProductVariant $variant): JsonResponse
    {
        return response()->json(['data' => $variant->barcodes()->orderByDesc('is_primary')->get()]);
    }

    public function storeForVariant(Request $request, ProductVariant $variant): JsonResponse
    {
        $data = $request->validate([
            'barcode' => ['required', 'string', 'max:100'],
            'type' => ['nullable', 'string', Rule::in(BarcodeValidator::supportedTypes())],
            'is_primary' => ['boolean'],
        ]);

        $type = $data['type'] ?? BarcodeValidator::detectType($data['barcode']);

        $barcode = $this->barcodes->create(
            $variant,
            $data['barcode'],
            $type,
            $data['is_primary'] ?? false,
        );

        return response()->json(['data' => $barcode], 201);
    }

    public function update(Request $request, Barcode $barcode): JsonResponse
    {
        $this->ensureTenantBarcode($barcode);

        $data = $request->validate([
            'barcode' => ['sometimes', 'string', 'max:100'],
            'type' => ['sometimes', 'string', Rule::in(BarcodeValidator::supportedTypes())],
            'is_primary' => ['sometimes', 'boolean'],
        ]);

        $updated = $this->barcodes->update($barcode, $data);

        return response()->json(['data' => $updated]);
    }

    public function destroy(Barcode $barcode): JsonResponse
    {
        $this->ensureTenantBarcode($barcode);
        $this->barcodes->delete($barcode);

        return response()->json(['message' => 'Deleted.']);
    }

    private function ensureTenantBarcode(Barcode $barcode): void
    {
        if ($barcode->tenant_id !== $this->tenantContext->requireId()) {
            abort(404);
        }
    }
}
