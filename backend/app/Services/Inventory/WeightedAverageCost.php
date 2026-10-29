<?php

namespace App\Services\Inventory;

/**
 * Perpetual weighted average cost, in minor currency units.
 */
final class WeightedAverageCost
{
    public static function compute(int $onHand, int $currentCost, int $incomingQty, int $incomingCost): int
    {
        $onHand = max(0, $onHand);
        $incomingQty = max(0, $incomingQty);
        $currentCost = max(0, $currentCost);
        $incomingCost = max(0, $incomingCost);
        $totalQty = $onHand + $incomingQty;

        if ($totalQty <= 0 || $incomingCost === $currentCost) {
            return $currentCost;
        }

        if ($onHand === 0) {
            return $incomingCost;
        }

        $numerator = ($onHand * $currentCost) + ($incomingQty * $incomingCost);

        return intdiv($numerator + intdiv($totalQty, 2), $totalQty);
    }
}
