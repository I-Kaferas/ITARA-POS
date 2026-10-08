<?php

namespace App\Events;

use App\Models\Sale;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class SaleCompleted
{
    use Dispatchable, SerializesModels;

    public string $tenantId;

    public function __construct(public Sale $sale)
    {
        $this->tenantId = (string) $sale->tenant_id;
    }
}
