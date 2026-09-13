<?php

namespace App\Services\Catalog;

use App\Models\Tax;
use App\Support\Money\MoneyMath;

class TaxQuote
{
    /**
     * @return array{ht: int, tva: int, ttc: int, rate: float, inclusive: bool}
     */
    public function quote(int $amount, ?Tax $tax): array
    {
        $rate = (float) ($tax?->rate ?? 0);
        $inclusive = (bool) ($tax?->is_inclusive ?? false);

        if ($inclusive) {
            $tva = MoneyMath::extractInclusiveTax($amount, $rate);

            return [
                'ht' => $amount - $tva,
                'tva' => $tva,
                'ttc' => $amount,
                'rate' => $rate,
                'inclusive' => true,
            ];
        }

        $tva = MoneyMath::taxOnExclusive($amount, $rate);

        return [
            'ht' => $amount,
            'tva' => $tva,
            'ttc' => $amount + $tva,
            'rate' => $rate,
            'inclusive' => false,
        ];
    }
}
