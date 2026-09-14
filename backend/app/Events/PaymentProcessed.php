<?php

namespace App\Events;

use App\DTOs\Payments\PaymentResult;
use App\Models\Store;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class PaymentProcessed
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public PaymentResult $result,
        public Store $store,
    ) {}
}
