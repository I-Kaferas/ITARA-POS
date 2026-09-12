<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Store;
use App\Services\Sales\CartEngine;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class CartController extends Controller
{
    public function __construct(
        private readonly CartEngine $cartEngine,
    ) {}

    public function calculate(Request $request, Store $store): JsonResponse
    {
        $data = $request->validate([
            'items' => ['required', 'array', 'min:1'],
            'customer_id' => ['nullable', 'uuid', 'exists:customers,id'],
            'items.*.line_id' => ['nullable', 'string', 'max:120'],
            'items.*.product_id' => ['nullable', 'uuid', 'exists:products,id'],
            'items.*.product_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
            'items.*.unit_price' => ['nullable', 'integer', 'min:0'],
            'items.*.price_type' => ['nullable', 'string', Rule::in(array_keys(config('product_types.price_types')))],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.tax_rate' => ['nullable', 'numeric', 'min:0'],
            'items.*.tax_inclusive' => ['nullable', 'boolean'],
            'items.*.sku' => ['nullable', 'string', 'max:120'],
            'items.*.name' => ['nullable', 'string', 'max:255'],
            'items.*.line_discount' => ['nullable', 'array'],
            'items.*.line_discount.type' => ['required_with:items.*.line_discount', 'in:fixed,percent'],
            'items.*.line_discount.value' => ['required_with:items.*.line_discount'],
            'global_discount' => ['nullable', 'array'],
            'global_discount.type' => ['required_with:global_discount', 'in:fixed,percent'],
            'global_discount.value' => ['required_with:global_discount'],
            'fees' => ['nullable', 'array'],
            'fees.*.label' => ['required_with:fees', 'string', 'max:120'],
            'fees.*.amount' => ['required_with:fees', 'integer', 'min:0'],
            'fees.*.code' => ['nullable', 'string', 'max:50'],
            'apply_promotions' => ['nullable', 'boolean'],
        ]);

        foreach ($data['items'] as $index => $item) {
            if (! isset($item['unit_price']) && ! isset($item['product_id'])) {
                return response()->json([
                    'message' => "items.{$index} requires unit_price or product_id.",
                ], 422);
            }
        }

        $result = $this->cartEngine->calculateForStore($store, $data);

        return response()->json(['data' => $result->toArray()]);
    }
}
