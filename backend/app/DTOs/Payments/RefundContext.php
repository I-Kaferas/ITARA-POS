<?php

namespace App\DTOs\Payments;

use App\Models\CashRegister;
use App\Models\Customer;
use App\Models\Sale;
use App\Models\SaleReturn;
use App\Models\Store;
use App\Models\User;

final readonly class RefundContext
{
    public function __construct(
        public Store $store,
        public Sale $sale,
        public SaleReturn $saleReturn,
        public User $processedBy,
        public string $refundNumber,
        public string $transactionNumber,
        public ?Customer $customer = null,
        public ?CashRegister $cashRegister = null,
        public array $metadata = [],
    ) {}
}
