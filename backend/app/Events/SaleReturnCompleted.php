<?php

namespace App\Events;

use App\Models\SaleReturn;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class SaleReturnCompleted
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public readonly SaleReturn $saleReturn,
    ) {}
}
