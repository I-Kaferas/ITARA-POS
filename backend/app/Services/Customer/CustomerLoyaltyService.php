<?php

namespace App\Services\Customer;

use App\Models\Customer;
use Illuminate\Validation\ValidationException;

class CustomerLoyaltyService
{
    public function pointsForAmount(int $amountMinorUnits): int
    {
        $perAmount = max(1, (int) config('customers.loyalty_points_per_amount', 100));
        $earnedPerUnit = max(1, (int) config('customers.loyalty_points_earned', 1));

        return (int) floor($amountMinorUnits / $perAmount) * $earnedPerUnit;
    }

    public function applyEarnedPoints(Customer $customer, int $points): void
    {
        if ($points <= 0) {
            return;
        }

        $customer->loyalty_points += $points;
        $customer->loyalty_tier = $this->resolveTier($customer->loyalty_points);
        $customer->save();
    }

    public function redeemPoints(Customer $customer, int $points, ?string $recordedBy = null): Customer
    {
        if ($points <= 0) {
            throw ValidationException::withMessages([
                'points' => ['Points must be greater than zero.'],
            ]);
        }

        if ($customer->loyalty_points < $points) {
            throw ValidationException::withMessages([
                'points' => ['Insufficient loyalty points.'],
            ]);
        }

        $customer->loyalty_points -= $points;
        $customer->loyalty_tier = $this->resolveTier($customer->loyalty_points);
        $customer->save();

        return $customer->fresh();
    }

    /**
     * @return array{points: int, tier: string, tier_label: string, next_tier: string|null, points_to_next: int|null}
     */
    public function summary(Customer $customer): array
    {
        $tier = $customer->loyalty_tier;
        $tiers = config('customers.loyalty_tiers', []);
        $nextTier = $this->nextTier($customer->loyalty_points);

        return [
            'points' => $customer->loyalty_points,
            'tier' => $tier,
            'tier_label' => $tiers[$tier]['label'] ?? ucfirst($tier),
            'next_tier' => $nextTier['key'] ?? null,
            'points_to_next' => $nextTier['points_needed'] ?? null,
        ];
    }

    private function resolveTier(int $points): string
    {
        $tiers = config('customers.loyalty_tiers', []);
        $resolved = 'standard';

        foreach ($tiers as $key => $config) {
            if ($points >= ($config['min_points'] ?? 0)) {
                $resolved = $key;
            }
        }

        return $resolved;
    }

    /** @return array{key: string, points_needed: int}|null */
    private function nextTier(int $points): ?array
    {
        $tiers = config('customers.loyalty_tiers', []);
        $sorted = collect($tiers)->sortBy('min_points');

        foreach ($sorted as $key => $config) {
            $min = $config['min_points'] ?? 0;

            if ($points < $min) {
                return [
                    'key' => $key,
                    'points_needed' => $min - $points,
                ];
            }
        }

        return null;
    }
}
