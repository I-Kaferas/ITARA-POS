<?php

namespace App\Services\Catalog;

use App\Models\Company;
use App\Models\Currency;
use Carbon\CarbonInterface;
use Illuminate\Validation\ValidationException;

class CurrencyConverter
{
    /**
     * exchange_rate is the value of 1 major unit of that currency in the primary currency.
     * Amounts are always integer minor units; decimal_places are applied during conversion.
     */
    public function convert(int $amount, string $from, string $to, ?CarbonInterface $at = null): int
    {
        $from = strtoupper($from);
        $to = strtoupper($to);
        if ($from === $to || $amount === 0) {
            return $amount;
        }

        $meta = $this->currencyMeta([$from, $to], $at);
        $fromRate = $meta[$from]['rate'];
        $toRate = $meta[$to]['rate'];
        $fromDecimals = $meta[$from]['decimals'];
        $toDecimals = $meta[$to]['decimals'];

        if ($fromRate <= 0 || $toRate <= 0) {
            return $amount;
        }

        // major = minor / 10^decimals
        // convert majors via rates, then back to target minor units
        $scale = $toDecimals - $fromDecimals;

        return (int) round($amount * $fromRate / $toRate * (10 ** $scale));
    }

    /**
     * Cross rate: 1 major unit of $from equals this many major units of $to.
     */
    public function crossRate(string $from, string $to, ?CarbonInterface $at = null): float
    {
        return app(ExchangeRateService::class)->crossRate($from, $to, $at);
    }

    public function defaultCode(): string
    {
        $code = Currency::query()->where('is_default', true)->value('code')
            ?: Company::query()->where('is_active', true)->value('currency_code');

        return strtoupper($code ?: 'FBU');
    }

    public function assertActive(string $code): string
    {
        $normalized = strtoupper($code);
        $exists = Currency::query()
            ->where('code', $normalized)
            ->where('is_active', true)
            ->exists();

        if (! $exists) {
            throw ValidationException::withMessages([
                'currency' => ["Currency {$normalized} is not active for this tenant."],
            ]);
        }

        return $normalized;
    }

    public function decimalPlaces(string $code): int
    {
        $code = strtoupper($code);
        $places = Currency::query()->where('code', $code)->value('decimal_places');

        if ($places !== null) {
            return (int) $places;
        }

        return $code === 'FBU' ? 0 : 2;
    }

    /**
     * @param  list<string>  $codes
     * @return array<string, array{rate: float, decimals: int}>
     */
    private function currencyMeta(array $codes, ?CarbonInterface $at = null): array
    {
        $codes = array_values(array_unique(array_map('strtoupper', $codes)));
        $rows = Currency::query()
            ->whereIn('code', $codes)
            ->get(['code', 'exchange_rate', 'decimal_places'])
            ->keyBy(fn (Currency $c) => strtoupper($c->code));

        $rates = $at !== null ? app(ExchangeRateService::class) : null;
        $meta = [];

        foreach ($codes as $code) {
            $row = $rows->get($code);
            $meta[$code] = [
                'rate' => $rates
                    ? $rates->rateFor($code, $at)
                    : (float) ($row?->exchange_rate ?? 1),
                'decimals' => $row !== null
                    ? (int) $row->decimal_places
                    : ($code === 'FBU' ? 0 : 2),
            ];
        }

        return $meta;
    }
}
