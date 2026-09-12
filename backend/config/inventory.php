<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default low-stock threshold (units)
    |--------------------------------------------------------------------------
    | Used when product.low_stock_threshold is null.
    */
    'default_low_stock_threshold' => (int) env('INVENTORY_LOW_STOCK_THRESHOLD', 10),

    /*
    |--------------------------------------------------------------------------
    | Days before expiration to trigger "expiring soon" alert
    |--------------------------------------------------------------------------
    */
    'expiring_soon_days' => (int) env('INVENTORY_EXPIRING_SOON_DAYS', 30),

    /*
    |--------------------------------------------------------------------------
    | Default batch allocation for non-perishable batch-tracked products
    |--------------------------------------------------------------------------
    | fifo | fefo
    */
    'default_allocation_strategy' => env('INVENTORY_ALLOCATION_STRATEGY', 'fifo'),

    /*
    |--------------------------------------------------------------------------
    | Block outbound allocation from expired batches
    |--------------------------------------------------------------------------
    */
    'block_expired_batch_outbound' => (bool) env('INVENTORY_BLOCK_EXPIRED_BATCH_OUTBOUND', true),

];
