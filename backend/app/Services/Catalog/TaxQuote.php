<?php

namespace App\Services\Catalog;

use App\Models\Tax;
use App\Services\Tax\TaxEngine;

class TaxQuote
{
    public function __construct(private readonly TaxEngine $engine) {}

    /**
     * @return array{ht: int, tva: int, ttc: int, rate: float, inclusive: bool, withholding: int, lines: list<array<string, mixed>>}
     */
    public function quote(int $amount, ?Tax $tax): array
    {
        $inclusive = (bool) ($tax?->is_inclusive ?? false);
        $result = $this->engine->quote(
            $amount,
            $inclusive,
            $tax ? collect([$tax]) : collect(),
        );

        return [
            'ht' => $result['net'],
            'tva' => $result['tax_total'],
            'ttc' => $result['total'],
            'rate' => (float) ($tax?->rate ?? 0),
            'inclusive' => $inclusive,
            'withholding' => $result['withholding_total'],
            'lines' => $result['lines'],
        ];
    }
}
