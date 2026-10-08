<?php

namespace App\Services\Catalog;

use App\Models\Currency;
use App\Models\CurrencyExchangeRate;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ExchangeRateService
{
    public function __construct(
        private readonly CurrencyConverter $converter,
    ) {}

    /**
     * Set the live rate on the currency and append a history row.
     *
     * @return array{currency: Currency, history: CurrencyExchangeRate}
     */
    public function setRate(
        Currency $currency,
        float|string $rate,
        ?User $user = null,
        ?string $note = null,
        string $source = 'manual',
        ?CarbonInterface $effectiveAt = null,
    ): array {
        $normalized = round((float) $rate, 8);

        if ($normalized <= 0) {
            throw ValidationException::withMessages([
                'exchange_rate' => ['Exchange rate must be greater than zero.'],
            ]);
        }

        if ($currency->is_default && abs($normalized - 1.0) > 0.00000001) {
            throw ValidationException::withMessages([
                'exchange_rate' => ['The primary currency exchange rate must remain 1.'],
            ]);
        }

        return DB::transaction(function () use ($currency, $normalized, $user, $note, $source, $effectiveAt) {
            $previous = (float) $currency->exchange_rate;
            $currency->update(['exchange_rate' => $normalized]);

            $history = $this->record(
                currency: $currency->fresh(),
                rate: $normalized,
                previousRate: $previous,
                user: $user,
                note: $note,
                source: $source,
                effectiveAt: $effectiveAt,
            );

            return [
                'currency' => $currency->fresh(),
                'history' => $history,
            ];
        });
    }

    public function record(
        Currency $currency,
        float $rate,
        ?float $previousRate = null,
        ?User $user = null,
        ?string $note = null,
        string $source = 'manual',
        ?CarbonInterface $effectiveAt = null,
    ): CurrencyExchangeRate {
        return CurrencyExchangeRate::query()->create([
            'tenant_id' => $currency->tenant_id,
            'currency_id' => $currency->id,
            'currency_code' => strtoupper($currency->code),
            'rate' => $rate,
            'previous_rate' => $previousRate,
            'base_currency_code' => $this->converter->defaultCode(),
            'effective_at' => $effectiveAt ?? now(),
            'changed_by' => $user?->id,
            'source' => $source,
            'note' => $note,
        ]);
    }

    /** @return Collection<int, CurrencyExchangeRate> */
    public function historyFor(Currency $currency, int $limit = 50): Collection
    {
        return CurrencyExchangeRate::query()
            ->where('currency_id', $currency->id)
            ->with('changedBy:id,name,email')
            ->orderByDesc('effective_at')
            ->orderByDesc('created_at')
            ->limit($limit)
            ->get();
    }

    /**
     * Rate of 1 unit of $code in the primary currency as of $at (current if null).
     */
    public function rateFor(string $code, ?CarbonInterface $at = null): float
    {
        $code = strtoupper($code);

        if ($at === null) {
            $live = Currency::query()->where('code', $code)->value('exchange_rate');

            return $live !== null ? (float) $live : 1.0;
        }

        $historical = CurrencyExchangeRate::query()
            ->where('currency_code', $code)
            ->where('effective_at', '<=', $at)
            ->orderByDesc('effective_at')
            ->orderByDesc('created_at')
            ->value('rate');

        if ($historical !== null) {
            return (float) $historical;
        }

        $live = Currency::query()->where('code', $code)->value('exchange_rate');

        return $live !== null ? (float) $live : 1.0;
    }

    /**
     * Effective cross rate: 1 unit of $from equals this many units of $to (major units).
     */
    public function crossRate(string $from, string $to, ?CarbonInterface $at = null): float
    {
        $from = strtoupper($from);
        $to = strtoupper($to);

        if ($from === $to) {
            return 1.0;
        }

        $fromRate = $this->rateFor($from, $at);
        $toRate = $this->rateFor($to, $at);

        if ($fromRate <= 0 || $toRate <= 0) {
            return 1.0;
        }

        return $fromRate / $toRate;
    }
}
