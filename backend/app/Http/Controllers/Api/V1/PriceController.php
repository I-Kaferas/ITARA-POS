<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\PriceType;
use App\Http\Controllers\Controller;
use App\Models\Catalog;
use App\Models\Currency;
use App\Models\Price;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Models\Store;
use App\Models\StoreProduct;
use App\Services\Catalog\CurrencyConverter;
use App\Services\Catalog\PriceService;
use App\Services\Catalog\TaxQuote;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PriceController extends Controller
{
    public function __construct(
        private PriceService $prices,
        private TaxQuote $quotes,
        private CurrencyConverter $currencies,
    ) {}

    public function types(): JsonResponse
    {
        return response()->json([
            'data' => array_map(
                fn (string $code) => ['code' => $code, 'label' => config("product_types.price_types.{$code}", $code)],
                PriceType::sellableValues(),
            ),
        ]);
    }

    public function catalog(Catalog $catalog): JsonResponse
    {
        $default = $this->currencies->defaultCode();
        $products = $catalog->products()
            ->with(['tax', 'prices'])
            ->orderBy('name')
            ->get();

        return response()->json([
            'default_currency' => $default,
            'currencies' => Currency::query()->where('is_active', true)->orderByDesc('is_default')->orderBy('code')->get(),
            'data' => $products->map(fn (Product $product) => $this->presentRow($product, $default))->values(),
        ]);
    }

    public function resolveForStoreProduct(Request $request, Store $store, Product $product): JsonResponse
    {
        $data = $request->validate([
            'price_type' => ['nullable', 'string', Rule::in(PriceType::values())],
            'quantity' => ['nullable', 'integer', 'min:1'],
            'currency' => ['nullable', 'string', 'size:3'],
        ]);

        $storeProduct = StoreProduct::query()
            ->where('store_id', $store->id)
            ->where('product_id', $product->id)
            ->first();

        $type = $data['price_type'] ?? 'retail';
        $quantity = (int) ($data['quantity'] ?? 1);
        $currency = isset($data['currency']) ? strtoupper($data['currency']) : null;
        $resolved = $storeProduct
            ? $this->prices->resolveForStoreProduct($storeProduct, $type, $quantity, currency: $currency)
            : $this->prices->resolve($product, $store, $type, $quantity, currency: $currency);

        $product->loadMissing('tax');

        return response()->json([
            'data' => [
                'amount' => $resolved->amount,
                'price_type' => $resolved->priceType,
                'source' => $resolved->source,
                'currency_code' => $resolved->currencyCode,
                'quote' => $this->quotes->quote($resolved->amount, $product->tax),
            ],
        ]);
    }

    public function indexForProduct(Product $product): JsonResponse
    {
        return response()->json([
            'data' => $product->prices()->with('store')->orderBy('price_type')->get(),
        ]);
    }

    public function storeForProduct(Request $request, Product $product): JsonResponse
    {
        $data = $this->validatePrice($request);

        $price = $this->prices->createOrUpdate($product, $data);

        return response()->json(['data' => $price->load('store')], 201);
    }

    public function indexForVariant(ProductVariant $variant): JsonResponse
    {
        return response()->json([
            'data' => $variant->prices()->with('store')->orderBy('price_type')->get(),
        ]);
    }

    public function storeForVariant(Request $request, ProductVariant $variant): JsonResponse
    {
        $data = $this->validatePrice($request);

        $price = $this->prices->createOrUpdate($variant, $data);

        return response()->json(['data' => $price->load('store')], 201);
    }

    public function update(Request $request, Price $price): JsonResponse
    {
        $data = $this->validatePrice($request, partial: true);
        $model = $price->priceable;

        if (! $model instanceof Product && ! $model instanceof ProductVariant) {
            abort(404);
        }

        $updated = $this->prices->createOrUpdate($model, $data, $price);

        return response()->json(['data' => $updated->load('store')]);
    }

    public function destroy(Price $price): JsonResponse
    {
        $price->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    /** @return array<string, mixed> */
    private function presentRow(Product $product, string $defaultCurrency): array
    {
        $tiers = [];
        foreach (PriceType::sellableValues() as $type) {
            $resolved = $this->prices->resolve($product, priceType: $type);
            $quote = $this->quotes->quote($resolved->amount, $product->tax);
            $currency = $resolved->currencyCode ?: $defaultCurrency;
            $tiers[$type] = [
                'amount' => $resolved->amount,
                'currency_code' => $currency,
                'source' => $resolved->source,
                'price_id' => $resolved->priceId,
                'quote' => $quote,
                'in_default' => $this->currencies->convert($resolved->amount, $currency, $defaultCurrency),
            ];
        }

        return [
            'id' => $product->id,
            'sku' => $product->sku,
            'name' => $product->name,
            'tax' => $product->tax ? [
                'id' => $product->tax->id,
                'code' => $product->tax->code,
                'name' => $product->tax->name,
                'rate' => $product->tax->rate,
                'is_inclusive' => $product->tax->is_inclusive,
            ] : null,
            'prices' => $tiers,
        ];
    }

    /** @return array<string, mixed> */
    private function validatePrice(Request $request, bool $partial = false): array
    {
        $sometimes = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'price_type' => [$sometimes, 'string', Rule::in(array_keys(config('product_types.price_types')))],
            'amount' => [$sometimes, 'integer', 'min:0'],
            'currency_code' => ['nullable', 'string', 'size:3'],
            'store_id' => ['nullable', 'uuid', 'exists:stores,id'],
            'min_quantity' => ['nullable', 'integer', 'min:1'],
            'valid_from' => ['nullable', 'date'],
            'valid_until' => ['nullable', 'date', 'after_or_equal:valid_from'],
            'is_active' => ['boolean'],
        ]);
    }
}
