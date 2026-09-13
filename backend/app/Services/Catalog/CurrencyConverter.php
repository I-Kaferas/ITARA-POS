<?php

namespace App\Services\Catalog;

use App\Models\Company;
use App\Models\Currency;

class CurrencyConverter
{
    /**
     * exchange_rate is the value of 1 unit of that currency in the default currency.
     */
    public function convert(int $amount, string $from, string $to): int
    {
        $from = strtoupper($from);
        $to = strtoupper($to);
        if ($from === $to || $amount === 0) {
            return $amount;
        }

        $rates = Currency::query()
            ->whereIn('code', [$from, $to])
            ->pluck('exchange_rate', 'code');

        $fromRate = (float) ($rates[$from] ?? 1);
        $toRate = (float) ($rates[$to] ?? 1);
        if ($fromRate <= 0 || $toRate <= 0) {
            return $amount;
        }

        return (int) round($amount * $fromRate / $toRate);
    }

    public function defaultCode(): string
    {
        $code = Currency::query()->where('is_default', true)->value('code')
            ?: Company::query()->where('is_active', true)->value('currency_code');

        return strtoupper($code ?: 'FBU');
    }
}
