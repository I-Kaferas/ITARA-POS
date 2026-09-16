<?php



namespace App\Services\Sales;



use App\DTOs\Cart\CalculatedCartLine;

use App\DTOs\Cart\CartCalculateInput;

use App\DTOs\Cart\CartCalculationResult;

use App\DTOs\Cart\CartDiscountInput;

use App\DTOs\Cart\CartFeeInput;

use App\DTOs\Cart\CartItemInput;

use App\DTOs\Promotions\PromotionEvaluationResult;

use App\Enums\CartDiscountType;

use App\Models\Customer;
use App\Models\ProductSaleUnit;

use App\Models\Store;

use App\Models\StoreProduct;

use App\Services\Catalog\PriceService;

use App\Services\Promotions\PromotionEngine;

use App\Support\Money\MoneyMath;



class CartEngine

{

    public function __construct(

        private readonly PriceService $priceService,

        private readonly PromotionEngine $promotionEngine,

    ) {}



    public function calculate(

        CartCalculateInput $input,

        ?PromotionEvaluationResult $promotions = null,

    ): CartCalculationResult {

        if ($input->items === []) {

            return new CartCalculationResult(

                subtotal: 0,

                lineDiscountsTotal: 0,

                promotionDiscountsTotal: 0,

                globalDiscountTotal: 0,

                discountTotal: 0,

                taxTotal: 0,

                feesTotal: 0,

                grandTotal: 0,

                lines: [],

                fees: [],

                currency: $input->currency,

                promotions: [],

            );

        }



        $lineNets = [];

        $lineRows = [];

        $promotionLineDiscounts = $promotions?->lineDiscounts ?? array_fill(0, count($input->items), 0);



        foreach ($input->items as $index => $item) {

            $lineSubtotal = MoneyMath::multiply($item->unitPrice, $item->quantity);

            $promotionDiscount = MoneyMath::clamp(

                $promotionLineDiscounts[$index] ?? 0,

                0,

                $lineSubtotal,

            );

            $manualLineDiscount = $this->resolveDiscount(

                max(0, $lineSubtotal - $promotionDiscount),

                $item->lineDiscount,

            );

            $lineDiscount = $promotionDiscount + $manualLineDiscount;

            $lineNet = max(0, $lineSubtotal - $lineDiscount);



            $lineNets[] = $lineNet;

            $lineRows[] = [

                'item' => $item,

                'line_subtotal' => $lineSubtotal,

                'promotion_discount' => $promotionDiscount,

                'line_discount' => $lineDiscount,

                'manual_line_discount' => $manualLineDiscount,

                'line_net' => $lineNet,

            ];

        }



        $subtotal = array_sum(array_column($lineRows, 'line_subtotal'));

        $promotionDiscountsTotal = array_sum(array_column($lineRows, 'promotion_discount'));

        $manualLineDiscountsTotal = array_sum(array_column($lineRows, 'manual_line_discount'));

        $lineDiscountsTotal = array_sum(array_column($lineRows, 'line_discount'));

        $netAfterLineDiscounts = array_sum($lineNets);



        $globalPromotionDiscount = MoneyMath::clamp(

            $promotions?->globalDiscount ?? 0,

            0,

            $netAfterLineDiscounts,

        );

        $globalManualDiscount = $this->resolveDiscount(

            max(0, $netAfterLineDiscounts - $globalPromotionDiscount),

            $input->globalDiscount,

        );

        $globalDiscountTotal = $globalPromotionDiscount + $globalManualDiscount;

        $globalShares = MoneyMath::allocateProportionally($globalDiscountTotal, $lineNets);



        $lines = [];

        $taxTotal = 0;

        $grandBeforeFees = 0;



        foreach ($lineRows as $index => $row) {

            /** @var CartItemInput $item */

            $item = $row['item'];

            $globalShare = $globalShares[$index] ?? 0;

            $taxableNet = max(0, $row['line_net'] - $globalShare);



            [$lineTax, $lineTotal] = $this->computeLineTaxAndTotal(

                $taxableNet,

                $item->taxRate,

                $item->taxInclusive,

            );



            $taxTotal += $lineTax;

            $grandBeforeFees += $lineTotal;



            $lines[] = new CalculatedCartLine(

                lineId: $item->lineId,

                unitPrice: $item->unitPrice,

                quantity: $item->quantity,

                lineSubtotal: $row['line_subtotal'],

                lineDiscount: $row['manual_line_discount'],

                promotionDiscount: $row['promotion_discount'],

                lineNet: $row['line_net'],

                globalDiscountShare: $globalShare,

                taxableNet: $taxableNet,

                lineTax: $lineTax,

                lineTotal: $lineTotal,

                taxRate: $item->taxRate,

                taxInclusive: $item->taxInclusive,

                productId: $item->productId,

                productVariantId: $item->productVariantId,

                sku: $item->sku,

                name: $item->name,

                priceType: $item->priceType,

                saleUnitId: $item->saleUnitId,

                volumeMl: $item->volumeMl,

                isAccompaniment: $item->isAccompaniment,

            );

        }



        $fees = [];

        $feesTotal = 0;

        foreach ($input->fees as $fee) {

            if ($fee->amount <= 0) {

                continue;

            }

            $feesTotal += $fee->amount;

            $fees[] = [

                'label' => $fee->label,

                'code' => $fee->code,

                'amount' => $fee->amount,

            ];

        }



        $discountTotal = $manualLineDiscountsTotal + $promotionDiscountsTotal + $globalDiscountTotal;

        $grandTotal = max(0, $grandBeforeFees + $feesTotal);



        return new CartCalculationResult(

            subtotal: $subtotal,

            lineDiscountsTotal: $manualLineDiscountsTotal,

            promotionDiscountsTotal: $promotionDiscountsTotal + $globalPromotionDiscount,

            globalDiscountTotal: $globalManualDiscount,

            discountTotal: $discountTotal,

            taxTotal: $taxTotal,

            feesTotal: $feesTotal,

            grandTotal: $grandTotal,

            lines: $lines,

            fees: $fees,

            currency: $input->currency,

            promotions: $promotions?->applied ?? [],

        );

    }



    /**

     * Build cart input by resolving store catalog prices and tax metadata.

     *

     * @param  array<string, mixed>  $payload

     */

    public function calculateForStore(Store $store, array $payload): CartCalculationResult

    {

        $store->loadMissing('branch.company');

        $currency = $store->branch?->company?->currency_code ?? 'FBU';



        $defaultPriceType = 'retail';

        $customer = null;

        if (isset($payload['customer_id'])) {

            $customer = Customer::query()->find($payload['customer_id']);

            $defaultPriceType = $customer?->effectivePriceTier() ?? 'retail';

        }



        $items = [];

        foreach ($payload['items'] ?? [] as $index => $itemPayload) {

            $items[] = $this->resolveStoreLine($store, $itemPayload, $index, $defaultPriceType);

        }



        $fees = [];

        foreach ($payload['fees'] ?? [] as $fee) {

            $fees[] = CartFeeInput::fromArray($fee);

        }



        $input = new CartCalculateInput(

            items: $items,

            globalDiscount: CartDiscountInput::fromArray($payload['global_discount'] ?? null),

            fees: $fees,

            currency: $currency,

        );



        $applyPromotions = $payload['apply_promotions'] ?? true;

        $promotions = $applyPromotions

            ? $this->promotionEngine->evaluate($items, $store, $customer)

            : null;



        return $this->calculate($input, $promotions);

    }



    private function resolveStoreLine(Store $store, array $payload, int $index, string $defaultPriceType = 'retail'): CartItemInput

    {

        $priceType = $payload['price_type'] ?? $defaultPriceType;

        $quantity = max(1, (int) ($payload['quantity'] ?? 1));

        $isAccompaniment = (bool) ($payload['is_accompaniment'] ?? false);

        if ($isAccompaniment && isset($payload['product_id'])) {
            $payload['unit_price'] = 0;
            if (empty($payload['name']) || empty($payload['sku'])) {
                $storeProduct = StoreProduct::query()
                    ->where('store_id', $store->id)
                    ->where('product_id', $payload['product_id'])
                    ->with(['product.tax'])
                    ->first()
                    ?? app(\App\Services\Catalog\PosCatalogSyncService::class)->ensureStoreProduct($store, $payload['product_id']);

                if ($storeProduct) {
                    $storeProduct->loadMissing(['product.tax']);
                    $product = $storeProduct->product;
                    $payload['tax_rate'] ??= $product->tax?->rate ?? '0.0000';
                    $payload['tax_inclusive'] ??= (bool) ($product->tax?->is_inclusive ?? false);
                    $payload['sku'] ??= $product->sku;
                    $payload['name'] ??= $product->name;
                }
            }
        }

        if (! isset($payload['unit_price']) && isset($payload['product_id'])) {

            $storeProduct = StoreProduct::query()

                ->where('store_id', $store->id)

                ->where('product_id', $payload['product_id'])

                ->with(['product.tax', 'product.variants', 'product.saleUnits'])

                ->first()

                ?? app(\App\Services\Catalog\PosCatalogSyncService::class)->ensureStoreProduct($store, $payload['product_id']);

            if (! $storeProduct) {
                throw new \InvalidArgumentException('Product is not available in this store.');
            }

            $storeProduct->loadMissing(['product.tax', 'product.variants', 'product.saleUnits']);



            $product = $storeProduct->product;

            if ((int) $product->bottle_volume_ml > 0 && $product->saleUnits->where('is_active', true)->isNotEmpty() && empty($payload['sale_unit_id'])) {
                throw new \InvalidArgumentException('Choisissez une unité de vente pour cette boisson.');
            }

            if (! empty($payload['sale_unit_id'])) {
                $saleUnit = $product->saleUnits->firstWhere('id', $payload['sale_unit_id'])
                    ?? ProductSaleUnit::query()
                        ->where('product_id', $product->id)
                        ->where('is_active', true)
                        ->find($payload['sale_unit_id']);

                if ($saleUnit === null) {
                    throw new \InvalidArgumentException('Sale unit is not available for this product.');
                }

                $payload['unit_price'] = $saleUnit->price;
                $payload['volume_ml'] = $saleUnit->volume_ml;
                $payload['sale_unit_id'] = $saleUnit->id;
                $payload['price_type'] = 'retail';
                $payload['tax_rate'] ??= $product->tax?->rate ?? '0.0000';
                $payload['tax_inclusive'] ??= (bool) ($product->tax?->is_inclusive ?? false);
                $payload['sku'] ??= $product->sku;
                $payload['name'] = trim($product->name.' · '.$saleUnit->name);
            } elseif (isset($payload['product_variant_id'])) {

                $variant = $product->variants->firstWhere('id', $payload['product_variant_id'])

                    ?? $product->variants()->findOrFail($payload['product_variant_id']);



                $resolved = $storeProduct->price_override !== null

                    ? $this->priceService->resolveForStoreProduct($storeProduct, $priceType, $quantity)

                    : $this->priceService->resolve($variant, $store, $priceType, $quantity);

            } else {

                $resolved = $this->priceService->resolveForStoreProduct($storeProduct, $priceType, $quantity);

            }

            if (empty($payload['sale_unit_id'])) {
                $payload['unit_price'] = $resolved->amount;
                $payload['price_type'] = $resolved->priceType;
                $payload['tax_rate'] ??= $product->tax?->rate ?? '0.0000';
                $payload['tax_inclusive'] ??= (bool) ($product->tax?->is_inclusive ?? false);
                $payload['sku'] ??= $product->sku;
                $payload['name'] ??= $product->name;
            }

        }



        if (! isset($payload['unit_price'])) {

            throw new \InvalidArgumentException('unit_price is required when product_id is not provided.');

        }



        return CartItemInput::fromArray($payload, $index);

    }



    private function resolveDiscount(int $baseAmount, ?CartDiscountInput $discount): int

    {

        if ($discount === null || $baseAmount <= 0) {

            return 0;

        }



        $amount = match ($discount->type) {

            CartDiscountType::Fixed => (int) $discount->value,

            CartDiscountType::Percent => MoneyMath::percentOf($baseAmount, $discount->value),

        };



        return MoneyMath::clamp($amount, 0, $baseAmount);

    }



    /** @return array{0: int, 1: int} */

    private function computeLineTaxAndTotal(int $taxableNet, string $taxRate, bool $taxInclusive): array

    {

        if ($taxInclusive) {

            $lineTax = MoneyMath::extractInclusiveTax($taxableNet, $taxRate);



            return [$lineTax, $taxableNet];

        }



        $lineTax = MoneyMath::taxOnExclusive($taxableNet, $taxRate);



        return [$lineTax, $taxableNet + $lineTax];

    }

}


