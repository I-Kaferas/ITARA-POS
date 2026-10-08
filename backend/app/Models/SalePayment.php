<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SalePayment extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'sale_id',
        'payment_transaction_id',
        'payment_method',
        'amount',
        'amount_in_sale_currency',
        'exchange_rate',
        'sale_currency',
        'currency',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'integer',
            'amount_in_sale_currency' => 'integer',
            'exchange_rate' => 'decimal:8',
            'sort_order' => 'integer',
        ];
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function paymentTransaction(): BelongsTo
    {
        return $this->belongsTo(PaymentTransaction::class);
    }
}
