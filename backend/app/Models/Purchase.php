<?php

namespace App\Models;

/** @deprecated Use PurchaseOrder — alias kept for backward compatibility. */
class Purchase extends PurchaseOrder
{
    protected $table = 'purchase_orders';
}
