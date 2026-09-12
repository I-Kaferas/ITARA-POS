<?php

namespace App\DTOs\Sales;

use App\Models\SaleReturn;

final readonly class SaleReturnResult
{
    public function __construct(
        public SaleReturn $saleReturn,
    ) {}

    /** @return array<string, mixed> */
    public function toArray(): array
    {
        $return = $this->saleReturn->load([
            'items',
            'sale:id,reference,total',
            'customer:id,name',
            'processedBy:id,name',
            'approvedBy:id,name',
            'refunds',
        ]);

        return [
            'sale_return' => [
                ...$return->toSummaryArray(),
                'sale_reference' => $return->sale?->reference,
                'items' => $return->items->map(fn ($item) => [
                    'id' => $item->id,
                    'sale_item_id' => $item->sale_item_id,
                    'product_id' => $item->product_id,
                    'product_name' => $item->product_name,
                    'product_sku' => $item->product_sku,
                    'quantity_returned' => $item->quantity_returned,
                    'unit_price' => $item->unit_price,
                    'line_subtotal' => $item->line_subtotal,
                    'line_tax' => $item->line_tax,
                    'line_total' => $item->line_total,
                ])->values()->all(),
                'customer' => $return->customer?->only(['id', 'name']),
                'refunds' => $return->refunds->map(fn ($refund) => $refund->toSummaryArray())->values()->all(),
            ],
        ];
    }
}
