<?php

namespace App\Support\Money;

final class MoneyMath
{
    public static function multiply(int $unitPrice, int|float $quantity): int
    {
        return (int) round($unitPrice * $quantity);
    }

    public static function clamp(int $amount, int $min, int $max): int
    {
        return max($min, min($max, $amount));
    }

    public static function percentOf(int $base, int|float|string $percent): int
    {
        return (int) round($base * ((float) $percent) / 100);
    }

    public static function taxOnExclusive(int $net, int|float|string $rate): int
    {
        return self::percentOf(max(0, $net), $rate);
    }

    public static function extractInclusiveTax(int $gross, int|float|string $rate): int
    {
        $percent = (float) $rate;
        if ($gross <= 0 || $percent <= 0) {
            return 0;
        }

        return (int) round($gross * $percent / (100 + $percent));
    }

    /**
     * @param  list<int>  $weights
     * @return list<int>
     */
    public static function allocateProportionally(int $total, array $weights): array
    {
        $count = count($weights);
        if ($count === 0 || $total === 0) {
            return array_fill(0, $count, 0);
        }

        $sum = array_sum($weights);
        if ($sum <= 0) {
            return array_fill(0, $count, 0);
        }

        $allocated = [];
        $used = 0;
        foreach ($weights as $index => $weight) {
            if ($index === $count - 1) {
                $allocated[] = $total - $used;
                break;
            }
            $share = (int) floor($total * $weight / $sum);
            $allocated[] = $share;
            $used += $share;
        }

        return $allocated;
    }
}
