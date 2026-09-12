<?php

namespace App\Events;

use App\Models\GoodsReceipt;
use App\Models\PurchaseOrder;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class PurchaseReceived
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public readonly PurchaseOrder $purchaseOrder,
        public readonly GoodsReceipt $goodsReceipt,
    ) {}
}
