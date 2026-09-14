<?php

namespace App\DTOs\Promotions;

final readonly class PromotionEvaluationResult
{
    /**
     * @param  list<int>  $lineDiscounts  Discount per cart line, same order as the cart.
     * @param  list<array{promotion_id: string, name: string, type: string, amount: int, line_id: ?string}>  $applied
     */
    public function __construct(
        public array $lineDiscounts,
        public int $globalDiscount,
        public array $applied,
    ) {}
}
