<?php

namespace App\Services\Customer;

use App\Enums\CustomerTransactionType;
use App\Models\Customer;
use App\Models\CustomerTransaction;
use App\Models\Sale;
use Illuminate\Validation\ValidationException;

class CustomerLoyaltyService
{

    public function pointsForAmount(int $amountMinorUnits): int
    {
        if ($amountMinorUnits <= 0) {
            return 0;
        }

        $perAmount = max(1, (int) config('customers.loyalty_points_per_amount', 100000));
        $earnedPerUnit = max(1, (int) config('customers.loyalty_points_earned_per_unit', config('customers.loyalty_points_earned', 1)));

        return (int) floor($amountMinorUnits / $perAmount) * $earnedPerUnit;
    }

    public function rewardAmount(int $points): int
    {
        if ($points <= 0) {
            return 0;
        }

        return $points * max(1, (int) config('customers.loyalty_reward_per_point', 100));
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

    /**
     * Award points for a completed purchase. Idempotent per sale.
     */
    public function earnOnSale(Customer $customer, Sale $sale, ?string $recordedBy = null): int
    {
        $already = CustomerTransaction::query()
            ->where('sale_id', $sale->id)
            ->where('transaction_type', CustomerTransactionType::LoyaltyEarn)
            ->exists();

        if ($already) {
            return 0;
        }

        $points = $this->pointsForAmount((int) $sale->total);
        if ($points <= 0) {
            return 0;
        }

        $this->applyEarnedPoints($customer, $points);
        $this->writePointMovement(
            $customer,
            CustomerTransactionType::LoyaltyEarn,
            $points,
            $sale,
            $sale->reference,
            "Fidélité {$sale->reference} · {$points} pt",
            $recordedBy,
        );

        return $points;
    }

    /**
     * Admin reward: points become store credit the customer can spend later.
     */
    public function redeemPoints(Customer $customer, int $points, ?string $recordedBy = null): Customer
    {
        $this->assertRedeemable($customer, $points);

        $customer->loyalty_points -= $points;
        $customer->loyalty_tier = $this->resolveTier($customer->loyalty_points);
        $customer->save();

        $reward = $this->rewardAmount($points);
        app(CustomerLedgerService::class)->recordCreditNote(
            $customer,
            $reward,
            null,
            "Récompense fidélité · {$points} pt",
            $recordedBy,
        );
        $this->writePointMovement(
            $customer,
            CustomerTransactionType::LoyaltyRedeem,
            $points,
            null,
            null,
            "Récompense fidélité · {$points} pt",
            $recordedBy,
        );

        return $customer->fresh();
    }

    /**
     * POS reward: points become a discount already applied on this ticket.
     *
     * @param  array<string, mixed>|null  $globalDiscount
     */
    public function redeemOnSale(Customer $customer, Sale $sale, int $points, ?array $globalDiscount, ?string $recordedBy = null): int
    {
        if ($points <= 0) {
            return 0;
        }

        $already = CustomerTransaction::query()
            ->where('sale_id', $sale->id)
            ->where('transaction_type', CustomerTransactionType::LoyaltyRedeem)
            ->exists();

        if ($already) {
            return 0;
        }

        $this->assertRedeemable($customer, $points);

        $expected = $this->rewardAmount($points);
        $type = (string) ($globalDiscount['type'] ?? '');
        $value = (int) ($globalDiscount['value'] ?? 0);
        if ($type !== 'fixed' || $value !== $expected) {
            throw ValidationException::withMessages([
                'loyalty_points' => ['La remise fidélité ne correspond pas aux points utilisés.'],
            ]);
        }

        $customer->loyalty_points -= $points;
        $customer->loyalty_tier = $this->resolveTier($customer->loyalty_points);
        $customer->save();

        $this->writePointMovement(
            $customer,
            CustomerTransactionType::LoyaltyRedeem,
            $points,
            $sale,
            $sale->reference,
            "Récompense {$sale->reference} · {$points} pt",
            $recordedBy,
        );

        return $points;
    }

    public function reverseForReturn(Customer $customer, Sale $sale, int $amount, ?string $recordedBy = null): int
    {
        $points = $this->pointsForAmount($amount);
        if ($points <= 0) {
            return 0;
        }

        $earned = (int) CustomerTransaction::query()
            ->where('sale_id', $sale->id)
            ->where('transaction_type', CustomerTransactionType::LoyaltyEarn)
            ->sum('loyalty_points_delta');
        $reversed = (int) CustomerTransaction::query()
            ->where('sale_id', $sale->id)
            ->where('transaction_type', CustomerTransactionType::LoyaltyReversal)
            ->sum('loyalty_points_delta');
        $points = min($points, max(0, $earned - $reversed), (int) $customer->loyalty_points);
        if ($points <= 0) {
            return 0;
        }

        $customer->loyalty_points -= $points;
        $customer->loyalty_tier = $this->resolveTier($customer->loyalty_points);
        $customer->save();

        $this->writePointMovement(
            $customer,
            CustomerTransactionType::LoyaltyReversal,
            $points,
            $sale,
            $sale->reference,
            "Retour {$sale->reference} · -{$points} pt",
            $recordedBy,
        );

        return $points;
    }

    /**
     * @return array{points: int, tier: string|null, tier_label: string, next_tier: string|null, points_to_next: int|null, spend_per_point: int, points_earned: int, reward_per_point: int}
     */
    public function summary(Customer $customer): array
    {
        $tier = $customer->loyalty_tier;
        $tiers = config('customers.loyalty_tiers', []);
        $nextTier = $this->nextTier((int) $customer->loyalty_points);

        return [
            'points' => (int) $customer->loyalty_points,
            'tier' => $tier,
            'tier_label' => $tiers[$tier]['label'] ?? ucfirst((string) $tier),
            'next_tier' => $nextTier['key'] ?? null,
            'points_to_next' => $nextTier['points_needed'] ?? null,
            'spend_per_point' => max(1, (int) config('customers.loyalty_points_per_amount', 100000)),
            'points_earned' => max(1, (int) config('customers.loyalty_points_earned_per_unit', 1)),
            'reward_per_point' => max(1, (int) config('customers.loyalty_reward_per_point', 100)),
        ];
    }

    private function assertRedeemable(Customer $customer, int $points): void
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
    }

    private function writePointMovement(
        Customer $customer,
        CustomerTransactionType $type,
        int $points,
        ?Sale $sale,
        ?string $reference,
        string $description,
        ?string $recordedBy,
    ): void {
        CustomerTransaction::query()->create([
            'tenant_id' => $customer->tenant_id,
            'customer_id' => $customer->id,
            'sale_id' => $sale?->id,
            'transaction_type' => $type,
            'reference' => $reference,
            'amount' => 0,
            'loyalty_points_delta' => $points,
            'description' => $description,
            'recorded_by' => $recordedBy,
            'occurred_at' => now(),
        ]);
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
