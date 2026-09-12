<?php

namespace App\DTOs\Payments;

use App\Models\CashRegister;
use App\Models\Customer;
use App\Models\Sale;
use App\Models\Store;
use App\Models\User;

final readonly class PaymentContext
{
    public function __construct(
        public Store $store,
        public int $expectedTotal,
        public string $currency,
        public ?Customer $customer,
        public ?User $processedBy,
        public ?CashRegister $cashRegister,
        public string $transactionNumber,
        public ?string $idempotencyKey = null,
        public ?Sale $sale = null,
        public ?string $dueDate = null,
    ) {}
}
