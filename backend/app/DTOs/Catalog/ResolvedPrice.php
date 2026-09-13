<?php

namespace App\DTOs\Catalog;

final readonly class ResolvedPrice
{
    public function __construct(
        public int $amount,
        public string $priceType,
        public string $source,
        public ?string $priceId = null,
        public ?string $currencyCode = null,
    ) {}
}
