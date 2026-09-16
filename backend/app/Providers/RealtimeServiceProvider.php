<?php

namespace App\Providers;

use App\Events\PaymentProcessed;
use App\Events\PurchaseReceived;
use App\Events\SaleCompleted;
use App\Events\SaleReturnCompleted;
use App\Events\StockLow;
use App\Listeners\Realtime\BroadcastPaymentProcessed;
use App\Listeners\Realtime\BroadcastPurchaseReceived;
use App\Listeners\Realtime\BroadcastSaleCompleted;
use App\Listeners\Realtime\BroadcastSaleReturnCompleted;
use App\Listeners\Realtime\BroadcastStockLow;
use App\Models\InventoryMovement;
use App\Models\PosTable;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\SalePayment;
use App\Observers\Realtime\InventoryMovementObserver;
use App\Observers\Realtime\PosTableObserver;
use App\Observers\Realtime\SaleItemObserver;
use App\Observers\Realtime\SaleObserver;
use App\Observers\Realtime\SalePaymentObserver;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;

class RealtimeServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        $channels = base_path('routes/channels.php');
        if (is_file($channels)) {
            require $channels;
        }

        PosTable::observe(PosTableObserver::class);
        Sale::observe(SaleObserver::class);
        SaleItem::observe(SaleItemObserver::class);
        SalePayment::observe(SalePaymentObserver::class);
        InventoryMovement::observe(InventoryMovementObserver::class);

        Event::listen(SaleCompleted::class, BroadcastSaleCompleted::class);
        Event::listen(PaymentProcessed::class, BroadcastPaymentProcessed::class);
        Event::listen(StockLow::class, BroadcastStockLow::class);
        Event::listen(PurchaseReceived::class, BroadcastPurchaseReceived::class);
        Event::listen(SaleReturnCompleted::class, BroadcastSaleReturnCompleted::class);
    }
}
