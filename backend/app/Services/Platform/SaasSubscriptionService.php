<?php

namespace App\Services\Platform;

use App\Modules\ModuleRegistry;
use App\Models\SaasInvoice;
use App\Models\SaasPayment;
use App\Models\SaasPlan;
use App\Models\SaasSubscription;
use App\Models\SaasSubscriptionEvent;
use App\Models\Tenant;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SaasSubscriptionService
{
    public function __construct(
        private readonly SaasUsageMeter $usage,
        private readonly SaasLimitGuard $guard,
    ) {}

    public function ensureCatalog(): void
    {
        foreach (SaasPlanCatalog::definitions() as $code => $definition) {
            SaasPlan::query()->firstOrCreate(
                ['code' => $code],
                [
                    'name' => $definition['name'],
                    'rank' => $definition['rank'],
                    'monthly_price' => $definition['monthly_price'],
                    'yearly_price' => $definition['yearly_price'],
                    'currency_code' => 'USD',
                    'trial_days' => $definition['trial_days'],
                    'grace_days' => $definition['grace_days'],
                    'limits' => $definition['limits'],
                    'is_public' => true,
                ],
            );
        }
    }

    /** @return Collection<int, SaasPlan> */
    public function catalog(bool $publicOnly = false): Collection
    {
        $this->ensureCatalog();
        $query = SaasPlan::query()->orderBy('rank');
        if ($publicOnly) {
            $query->where('is_public', true);
        }

        return $query->get();
    }

    public function plan(string $code): SaasPlan
    {
        $this->ensureCatalog();
        $plan = SaasPlan::query()->where('code', $code)->first();
        if ($plan === null) {
            throw ValidationException::withMessages([
                'plan' => ['saas.unknown_plan'],
            ]);
        }

        return $plan;
    }

    /** @param  array<string, mixed>  $data */
    public function updatePlan(string $code, array $data): SaasPlan
    {
        $plan = $this->plan($code);
        $modulesChanged = false;

        if (isset($data['name'])) {
            $plan->name = $data['name'];
        }
        foreach (['monthly_price', 'yearly_price', 'trial_days', 'grace_days'] as $field) {
            if (array_key_exists($field, $data)) {
                $plan->{$field} = (int) $data[$field];
            }
        }
        if (isset($data['limits']) && is_array($data['limits'])) {
            $limits = is_array($plan->limits) ? $plan->limits : [];
            foreach (['users', 'branches', 'pos', 'products', 'storage_mb', 'transactions'] as $key) {
                if (array_key_exists($key, $data['limits'])) {
                    $value = $data['limits'][$key];
                    $limits[$key] = $value === null || $value === '' ? null : (int) $value;
                }
            }
            if (isset($data['limits']['modules']) && is_array($data['limits']['modules'])) {
                $modules = ModuleRegistry::normalize($data['limits']['modules']);
                if ($modules === []) {
                    throw ValidationException::withMessages([
                        'limits.modules' => ['saas.modules_required'],
                    ]);
                }
                $modulesChanged = $modules !== ($limits['modules'] ?? []);
                $limits['modules'] = $modules;
            }
            $plan->limits = $limits;
        }
        $plan->save();

        if ($modulesChanged) {
            SaasSubscription::query()
                ->where('plan_code', $plan->code)
                ->each(function (SaasSubscription $subscription) {
                    $this->syncTenant($subscription, true, false);
                });
        }

        return $plan->fresh() ?? $plan;
    }

    public function subscriptionFor(Tenant $tenant): ?SaasSubscription
    {
        return SaasSubscription::query()->where('tenant_id', $tenant->id)->first();
    }

    public function startTrial(Tenant $tenant, string $planCode): SaasSubscription
    {
        $existing = $this->subscriptionFor($tenant);
        if ($existing) {
            return $existing;
        }

        $plan = $this->plan($planCode);

        return DB::transaction(function () use ($tenant, $plan) {
            $subscription = SaasSubscription::query()->create([
                'tenant_id' => $tenant->id,
                'plan_code' => $plan->code,
                'status' => 'trial',
                'billing_cycle' => 'yearly',
                'trial_ends_on' => today()->addDays($plan->trial_days),
            ]);
            $this->syncTenant($subscription, true);
            $this->event($subscription, 'trial_started', ['plan' => $plan->code], null);

            return $subscription;
        });
    }

    public function openForProvision(Tenant $tenant, string $planCode, string $tenantStatus): SaasSubscription
    {
        if ($this->subscriptionFor($tenant)) {
            return $this->subscriptionFor($tenant);
        }

        if ($tenantStatus === 'trial') {
            return $this->startTrial($tenant, $planCode);
        }

        $plan = $this->plan($planCode);
        $status = match ($tenantStatus) {
            'past_due' => 'past_due',
            'suspended' => 'suspended',
            'cancelled', 'archived' => 'cancelled',
            default => 'active',
        };

        return DB::transaction(function () use ($tenant, $plan, $status) {
            $subscription = SaasSubscription::query()->create([
                'tenant_id' => $tenant->id,
                'plan_code' => $plan->code,
                'status' => $status,
                'billing_cycle' => 'yearly',
                'period_starts_on' => $status === 'active' ? today() : null,
                'period_ends_on' => $status === 'active' ? $this->periodEnd(today(), 'yearly') : null,
                'grace_ends_on' => $status === 'past_due' ? today()->addDays($plan->grace_days) : null,
                'suspended_at' => $status === 'suspended' ? now() : null,
                'cancelled_at' => $status === 'cancelled' ? now() : null,
            ]);
            $this->syncTenant($subscription, true);
            $this->event($subscription, 'trial_started', ['plan' => $plan->code, 'status' => $status], null);

            return $subscription;
        });
    }

    /** @return array{data: array<string, mixed>, plans: list<array<string, mixed>>} */
    public function show(Tenant $tenant): array
    {
        $subscription = $this->subscriptionFor($tenant);
        if ($subscription) {
            $this->reconcileOne($subscription);
            $subscription = $subscription->fresh();
        }

        return [
            'data' => $this->present($tenant, $subscription),
            'plans' => $this->catalog(true)->map(fn (SaasPlan $plan) => $this->planPayload($plan))->values()->all(),
        ];
    }

    /** @param  array{plan?: string, billing_cycle?: string}  $data */
    public function change(Tenant $tenant, array $data, ?string $actorId = null): array
    {
        $result = DB::transaction(function () use ($tenant, $data, $actorId) {
            $subscription = $this->subscriptionFor($tenant) ?? $this->startTrial($tenant, 'starter');
            $cycle = ($data['billing_cycle'] ?? $subscription->billing_cycle) === 'monthly' ? 'monthly' : 'yearly';
            $target = $this->plan($data['plan'] ?? $subscription->plan_code);
            $current = $this->plan($subscription->plan_code);
            $planChanged = $target->code !== $current->code;
            $cycleChanged = $cycle !== $subscription->billing_cycle;

            if (! $planChanged && ! $cycleChanged) {
                return $subscription;
            }

            $downgrade = $target->rank < $current->rank
                || ($target->rank === $current->rank && $cycle === 'monthly' && $subscription->billing_cycle === 'yearly');

            if ($downgrade) {
                $this->guard->assertFits($tenant, $target, $subscription);
                $scheduled = in_array($subscription->status, ['active', 'past_due'], true)
                    && $subscription->period_ends_on
                    && $subscription->period_ends_on->gt(today());

                if ($scheduled) {
                    $subscription->pending_plan_code = $planChanged ? $target->code : $subscription->plan_code;
                    $subscription->pending_billing_cycle = $cycleChanged ? $cycle : $subscription->billing_cycle;
                    $subscription->save();
                    $this->event($subscription, 'downgrade_scheduled', [
                        'plan' => $subscription->pending_plan_code,
                        'billing_cycle' => $subscription->pending_billing_cycle,
                        'on' => $subscription->period_ends_on->toDateString(),
                    ], $actorId);

                    return $subscription;
                }

                $this->assignPlan($subscription, $target, $cycle, 'downgraded', $actorId);

                return $subscription;
            }

            $this->upgradeNow($subscription, $target, $cycle, $actorId);

            return $subscription;
        });

        return $this->show($tenant->fresh() ?? $tenant);
    }

    /**
     * @param  array{method?: string, reference?: string|null, amount?: int, status?: string}|null  $payment
     * @return array{data: array<string, mixed>, plans: list<array<string, mixed>>}
     */
    public function subscribe(Tenant $tenant, string $planCode, string $cycle, ?array $payment = null, ?string $actorId = null): array
    {
        DB::transaction(function () use ($tenant, $planCode, $cycle, $payment, $actorId) {
            $subscription = $this->subscriptionFor($tenant) ?? $this->startTrial($tenant, $planCode);
            $target = $this->plan($planCode);
            $current = $this->plan($subscription->plan_code);
            if ($target->rank < $current->rank) {
                $this->guard->assertFits($tenant, $target, $subscription);
            }

            $cycle = $cycle === 'monthly' ? 'monthly' : 'yearly';
            $subscription->plan_code = $target->code;
            $subscription->billing_cycle = $cycle;
            $subscription->pending_plan_code = null;
            $subscription->pending_billing_cycle = null;
            $subscription->save();
            $this->syncTenant($subscription, true);

            $start = today();
            $end = $this->periodEnd($start, $cycle);
            $due = $subscription->status === 'trial'
                && $subscription->trial_ends_on
                && $subscription->trial_ends_on->gte(today())
                ? $subscription->trial_ends_on->copy()
                : $start;
            $invoice = $this->createInvoice(
                $subscription,
                'subscription',
                $target->priceFor($cycle),
                $start,
                $end,
                $due,
                $actorId,
            );
            $this->event($subscription, 'subscribed', [
                'plan' => $target->code,
                'billing_cycle' => $cycle,
                'invoice' => $invoice->number,
            ], $actorId);

            if ($invoice->amount === 0) {
                $this->settleInvoice($invoice, $subscription, $actorId);
            } elseif ($payment) {
                $this->storePayment($invoice, $payment, $actorId);
            }
        });

        return $this->show($tenant->fresh() ?? $tenant);
    }

    /** @param  array{method?: string, reference?: string|null, amount?: int}  $data */
    public function declarePayment(Tenant $tenant, string $invoiceId, array $data, ?string $actorId = null): SaasPayment
    {
        $invoice = SaasInvoice::query()
            ->where('tenant_id', $tenant->id)
            ->whereKey($invoiceId)
            ->firstOrFail();

        return $this->storePayment($invoice, [
            'method' => $data['method'] ?? 'transfer',
            'reference' => $data['reference'] ?? null,
            'amount' => $data['amount'] ?? null,
            'status' => 'pending',
        ], $actorId);
    }

    /** @param  array{method?: string, reference?: string|null, amount?: int, status?: string}  $data */
    public function recordPayment(SaasInvoice $invoice, array $data, ?string $actorId = null): SaasPayment
    {
        return DB::transaction(function () use ($invoice, $data, $actorId) {
            return $this->storePayment($invoice, $data, $actorId);
        });
    }

    public function settlePayment(SaasPayment $payment, string $status, ?string $actorId = null): SaasPayment
    {
        return DB::transaction(function () use ($payment, $status, $actorId) {
            $invoice = $payment->invoice()->lockForUpdate()->firstOrFail();
            $payment->status = $status === 'succeeded' ? 'succeeded' : 'failed';
            $payment->paid_at = $payment->status === 'succeeded' ? now() : null;
            $payment->save();

            $subscription = $invoice->subscription;
            if ($payment->status === 'failed') {
                $this->event($subscription, 'payment_failed', [
                    'invoice' => $invoice->number,
                    'payment' => $payment->id,
                ], $actorId);
                if ($subscription->status !== 'suspended') {
                    $this->beginGrace($subscription, $actorId);
                }

                return $payment->fresh() ?? $payment;
            }

            $this->event($subscription, 'payment_received', [
                'invoice' => $invoice->number,
                'amount' => $payment->amount,
            ], $actorId);
            $this->collectInvoice($invoice, $subscription, $actorId);

            return $payment->fresh() ?? $payment;
        });
    }

    /** @return array{data: array<string, mixed>, plans: list<array<string, mixed>>} */
    public function openGrace(Tenant $tenant, ?string $actorId = null): array
    {
        DB::transaction(function () use ($tenant, $actorId) {
            $subscription = $this->subscriptionFor($tenant) ?? $this->startTrial($tenant, 'starter');
            $subscription->grace_ends_on = null;
            $subscription->status = 'active';
            $this->beginGrace($subscription, $actorId);
        });

        return $this->show($tenant->fresh() ?? $tenant);
    }

    /** @return array{data: array<string, mixed>, plans: list<array<string, mixed>>} */
    public function suspend(Tenant $tenant, ?string $actorId = null): array
    {
        DB::transaction(function () use ($tenant, $actorId) {
            $subscription = $this->subscriptionFor($tenant) ?? $this->startTrial($tenant, 'starter');
            $this->suspendNow($subscription, $actorId);
        });

        return $this->show($tenant->fresh() ?? $tenant);
    }

    /** @param  array<string, mixed>  $legacy */
    public function alignLegacy(Tenant $tenant, array $legacy): void
    {
        $subscription = $this->subscriptionFor($tenant);
        if ($subscription === null) {
            return;
        }

        $status = $legacy['status'] ?? null;
        if (is_string($status) && in_array($status, ['trial', 'active', 'past_due', 'suspended', 'cancelled'], true)) {
            $subscription->status = $status;
            if ($status === 'suspended') {
                $subscription->suspended_at = $subscription->suspended_at ?? now();
            }
            if ($status === 'active') {
                $subscription->suspended_at = null;
                $subscription->grace_ends_on = null;
            }
            if ($status === 'cancelled') {
                $subscription->cancelled_at = $subscription->cancelled_at ?? now();
            }
        }
        if (array_key_exists('renews_on', $legacy)) {
            $subscription->period_ends_on = $legacy['renews_on'] ?: null;
        }
        $subscription->save();
    }

    public function reconcileAll(): int
    {
        $changed = 0;
        SaasSubscription::query()->orderBy('id')->chunkById(100, function ($rows) use (&$changed) {
            foreach ($rows as $subscription) {
                $before = $subscription->status.'|'.$subscription->plan_code.'|'.($subscription->pending_plan_code ?? '');
                $this->reconcileOne($subscription);
                $subscription->refresh();
                $after = $subscription->status.'|'.$subscription->plan_code.'|'.($subscription->pending_plan_code ?? '');
                if ($before !== $after) {
                    $changed++;
                }
            }
        });

        return $changed;
    }

    public function reconcileOne(SaasSubscription $subscription): void
    {
        DB::transaction(function () use ($subscription) {
            $locked = SaasSubscription::query()->whereKey($subscription->id)->lockForUpdate()->first();
            if ($locked === null) {
                return;
            }

            $tenant = Tenant::query()->find($locked->tenant_id);
            if ($tenant === null) {
                return;
            }

            $this->applyPending($locked, $tenant);
            $locked->refresh();

            if ($locked->status === 'past_due' && $locked->grace_ends_on && $locked->grace_ends_on->lt(today())) {
                $this->suspendNow($locked, null);

                return;
            }

            if (in_array($locked->status, ['suspended', 'cancelled'], true)) {
                return;
            }

            if ($locked->status === 'trial' && $locked->trial_ends_on && $locked->trial_ends_on->lt(today())) {
                $this->beginGrace($locked, null);

                return;
            }

            if ($locked->status !== 'active') {
                return;
            }

            if ($locked->period_ends_on && $locked->period_ends_on->lte(today())) {
                $this->issueRenewal($locked);
                $this->beginGrace($locked, null);

                return;
            }

            $overdue = SaasInvoice::query()
                ->where('subscription_id', $locked->id)
                ->where('status', 'open')
                ->whereDate('due_on', '<', today())
                ->exists();
            if ($overdue) {
                $this->beginGrace($locked, null);
            }
        });
    }

    /**
     * @param  SaasSubscription|null  $subscription
     * @param  SaasInvoice|null  $openInvoice
     * @return array<string, mixed>|null
     */
    public function summarize(?SaasSubscription $subscription, ?SaasInvoice $openInvoice = null): ?array
    {
        if ($subscription === null) {
            return null;
        }

        return [
            'plan' => $subscription->plan_code,
            'status' => $subscription->status,
            'billing_cycle' => $subscription->billing_cycle,
            'renews_on' => $subscription->period_ends_on?->toDateString(),
            'trial_ends_on' => $subscription->trial_ends_on?->toDateString(),
            'grace_ends_on' => $subscription->grace_ends_on?->toDateString(),
            'pending_plan' => $subscription->pending_plan_code,
            'open_invoice' => $openInvoice ? [
                'id' => $openInvoice->id,
                'number' => $openInvoice->number,
                'amount' => $openInvoice->amount,
                'currency' => $openInvoice->currency_code,
                'due_on' => $openInvoice->due_on?->toDateString(),
            ] : null,
        ];
    }

    /** @return array<string, mixed> */
    private function present(Tenant $tenant, ?SaasSubscription $subscription): array
    {
        if ($subscription === null) {
            $catalog = app(SaasCatalog::class)->commercialSubscription($tenant);
            $plan = SaasPlan::query()->where('code', $catalog['plan'])->first() ?? $this->plan('starter');

            return [
                'plan' => $plan->code,
                'status' => $catalog['status'],
                'billing_cycle' => $catalog['billing_cycle'],
                'renews_on' => $catalog['renews_on'],
                'trial_ends_on' => null,
                'grace_ends_on' => null,
                'pending_plan' => null,
                'pending_billing_cycle' => null,
                'limits' => $this->normalizedLimits($plan),
                'usage' => $this->usage->snapshot($tenant, null),
                'amount' => $plan->priceFor($catalog['billing_cycle']),
                'currency' => $plan->currency_code,
                'invoices' => [],
                'events' => [],
            ];
        }

        $plan = $this->plan($subscription->plan_code);
        $invoices = SaasInvoice::query()
            ->with('payments')
            ->where('subscription_id', $subscription->id)
            ->orderByDesc('issued_on')
            ->limit(12)
            ->get();
        $events = SaasSubscriptionEvent::query()
            ->where('subscription_id', $subscription->id)
            ->orderByDesc('created_at')
            ->limit(12)
            ->get();

        return [
            'plan' => $subscription->plan_code,
            'status' => $subscription->status,
            'billing_cycle' => $subscription->billing_cycle,
            'renews_on' => $subscription->period_ends_on?->toDateString(),
            'trial_ends_on' => $subscription->trial_ends_on?->toDateString(),
            'grace_ends_on' => $subscription->grace_ends_on?->toDateString(),
            'pending_plan' => $subscription->pending_plan_code,
            'pending_billing_cycle' => $subscription->pending_billing_cycle,
            'limits' => $this->normalizedLimits($plan),
            'usage' => $this->usage->snapshot($tenant, $subscription),
            'amount' => $plan->priceFor($subscription->billing_cycle),
            'currency' => $plan->currency_code,
            'invoices' => $invoices->map(fn (SaasInvoice $invoice) => [
                'id' => $invoice->id,
                'number' => $invoice->number,
                'kind' => $invoice->kind,
                'status' => $invoice->status,
                'plan' => $invoice->plan_code,
                'billing_cycle' => $invoice->billing_cycle,
                'amount' => $invoice->amount,
                'currency' => $invoice->currency_code,
                'issued_on' => $invoice->issued_on?->toDateString(),
                'due_on' => $invoice->due_on?->toDateString(),
                'paid_at' => $invoice->paid_at?->toIso8601String(),
                'payments' => $invoice->payments->map(fn (SaasPayment $payment) => [
                    'id' => $payment->id,
                    'amount' => $payment->amount,
                    'method' => $payment->method,
                    'reference' => $payment->reference,
                    'status' => $payment->status,
                    'paid_at' => $payment->paid_at?->toIso8601String(),
                ])->values()->all(),
            ])->values()->all(),
            'events' => $events->map(fn (SaasSubscriptionEvent $event) => [
                'id' => $event->id,
                'type' => $event->type,
                'payload' => $event->payload,
                'created_at' => $event->created_at?->toIso8601String(),
            ])->values()->all(),
        ];
    }

    /** @return array<string, mixed> */
    private function planPayload(SaasPlan $plan): array
    {
        return [
            'code' => $plan->code,
            'name' => $plan->name,
            'rank' => $plan->rank,
            'monthly_price' => $plan->monthly_price,
            'yearly_price' => $plan->yearly_price,
            'currency' => $plan->currency_code,
            'trial_days' => $plan->trial_days,
            'grace_days' => $plan->grace_days,
            'limits' => $this->normalizedLimits($plan),
        ];
    }

    /** @return array<string, mixed> */
    private function normalizedLimits(SaasPlan $plan): array
    {
        return [
            'users' => $plan->limit('users'),
            'branches' => $plan->limit('branches'),
            'pos' => $plan->limit('pos'),
            'products' => $plan->limit('products'),
            'storage_mb' => $plan->limit('storage_mb'),
            'transactions' => $plan->limit('transactions'),
            'modules' => $plan->modules(),
        ];
    }

    private function upgradeNow(SaasSubscription $subscription, SaasPlan $target, string $cycle, ?string $actorId): void
    {
        $current = $this->plan($subscription->plan_code);
        $oldCycle = $subscription->billing_cycle;
        $trialLike = in_array($subscription->status, ['trial', 'cancelled'], true) || $subscription->period_ends_on === null;

        $subscription->plan_code = $target->code;
        $subscription->billing_cycle = $cycle;
        $subscription->pending_plan_code = null;
        $subscription->pending_billing_cycle = null;

        $amount = 0;
        if (! $trialLike) {
            $credit = (int) round($current->priceFor($oldCycle) * $this->remainingFraction($subscription));
            $amount = max(0, $target->priceFor($cycle) - $credit);
            if ($cycle === 'yearly' && $oldCycle === 'monthly') {
                $subscription->period_starts_on = today();
                $subscription->period_ends_on = $this->periodEnd(today(), 'yearly');
            }
        }
        $subscription->save();
        $this->syncTenant($subscription, true);

        if ($amount > 0) {
            $this->createInvoice(
                $subscription,
                'upgrade',
                $amount,
                $subscription->period_starts_on ?? today(),
                $subscription->period_ends_on ?? $this->periodEnd(today(), $cycle),
                today(),
                $actorId,
            );
        }

        $this->event($subscription, 'upgraded', [
            'from' => $current->code,
            'to' => $target->code,
            'billing_cycle' => $cycle,
            'amount' => $amount,
        ], $actorId);
    }

    private function assignPlan(SaasSubscription $subscription, SaasPlan $plan, string $cycle, string $event, ?string $actorId): void
    {
        $from = $subscription->plan_code;
        $subscription->plan_code = $plan->code;
        $subscription->billing_cycle = $cycle;
        $subscription->pending_plan_code = null;
        $subscription->pending_billing_cycle = null;
        $subscription->save();
        $this->syncTenant($subscription, true);
        $this->event($subscription, $event, ['from' => $from, 'to' => $plan->code, 'billing_cycle' => $cycle], $actorId);
    }

    private function applyPending(SaasSubscription $subscription, Tenant $tenant): void
    {
        if (! $subscription->pending_plan_code && ! $subscription->pending_billing_cycle) {
            return;
        }
        if ($subscription->period_ends_on && $subscription->period_ends_on->gt(today())) {
            return;
        }

        $target = $this->plan($subscription->pending_plan_code ?: $subscription->plan_code);
        $cycle = $subscription->pending_billing_cycle ?: $subscription->billing_cycle;
        if (! $this->guard->fits($tenant, $target, $subscription)) {
            return;
        }

        $this->assignPlan($subscription, $target, $cycle === 'monthly' ? 'monthly' : 'yearly', 'downgraded', null);
    }

    private function issueRenewal(SaasSubscription $subscription): void
    {
        if ($subscription->period_ends_on === null) {
            return;
        }

        $start = $subscription->period_ends_on->copy();
        $exists = SaasInvoice::query()
            ->where('subscription_id', $subscription->id)
            ->where('kind', 'renewal')
            ->whereDate('period_starts_on', $start->toDateString())
            ->whereIn('status', ['open', 'paid'])
            ->exists();
        if ($exists) {
            return;
        }

        $plan = $this->plan($subscription->plan_code);
        $this->createInvoice(
            $subscription,
            'renewal',
            $plan->priceFor($subscription->billing_cycle),
            $start,
            $this->periodEnd($start, $subscription->billing_cycle),
            $start,
            null,
        );
    }

    private function beginGrace(SaasSubscription $subscription, ?string $actorId): void
    {
        if (in_array($subscription->status, ['suspended', 'cancelled'], true)) {
            return;
        }
        if ($subscription->status === 'past_due' && $subscription->grace_ends_on && $subscription->grace_ends_on->gte(today())) {
            return;
        }

        $plan = $this->plan($subscription->plan_code);
        if ($plan->grace_days <= 0) {
            $this->suspendNow($subscription, $actorId);

            return;
        }

        $subscription->status = 'past_due';
        $subscription->grace_ends_on = today()->addDays($plan->grace_days);
        $subscription->save();
        $this->syncTenant($subscription, false);
        $this->event($subscription, 'grace_started', [
            'grace_ends_on' => $subscription->grace_ends_on->toDateString(),
        ], $actorId);
    }

    private function suspendNow(SaasSubscription $subscription, ?string $actorId): void
    {
        if ($subscription->status === 'suspended') {
            return;
        }

        $subscription->status = 'suspended';
        $subscription->suspended_at = now();
        $subscription->save();
        $this->syncTenant($subscription, false);
        $this->event($subscription, 'suspended', [], $actorId);
    }

    private function createInvoice(
        SaasSubscription $subscription,
        string $kind,
        int $amount,
        Carbon $start,
        Carbon $end,
        Carbon $due,
        ?string $actorId,
    ): SaasInvoice {
        $plan = $this->plan($subscription->plan_code);
        $invoice = SaasInvoice::query()->create([
            'tenant_id' => $subscription->tenant_id,
            'subscription_id' => $subscription->id,
            'number' => $this->nextNumber(),
            'kind' => $kind,
            'status' => 'open',
            'plan_code' => $subscription->plan_code,
            'billing_cycle' => $subscription->billing_cycle,
            'amount' => max(0, $amount),
            'currency_code' => $plan->currency_code,
            'period_starts_on' => $start->toDateString(),
            'period_ends_on' => $end->toDateString(),
            'issued_on' => today()->toDateString(),
            'due_on' => $due->toDateString(),
        ]);
        $this->event($subscription, 'invoiced', [
            'invoice' => $invoice->number,
            'kind' => $kind,
            'amount' => $invoice->amount,
        ], $actorId);

        return $invoice;
    }

    /** @param  array{method?: string, reference?: string|null, amount?: int|null, status?: string}  $data */
    private function storePayment(SaasInvoice $invoice, array $data, ?string $actorId): SaasPayment
    {
        $status = ($data['status'] ?? 'succeeded') === 'failed'
            ? 'failed'
            : (($data['status'] ?? 'succeeded') === 'pending' ? 'pending' : 'succeeded');
        $paid = (int) $invoice->payments()->where('status', 'succeeded')->sum('amount');
        $remaining = max(0, $invoice->amount - $paid);
        $amount = isset($data['amount']) && $data['amount'] !== null ? (int) $data['amount'] : $remaining;

        $payment = SaasPayment::query()->create([
            'tenant_id' => $invoice->tenant_id,
            'invoice_id' => $invoice->id,
            'amount' => max(0, $amount),
            'currency_code' => $invoice->currency_code,
            'method' => $data['method'] ?? 'manual',
            'reference' => $data['reference'] ?? null,
            'status' => $status,
            'paid_at' => $status === 'succeeded' ? now() : null,
        ]);

        $subscription = $invoice->subscription()->firstOrFail();
        if ($status === 'failed') {
            $this->event($subscription, 'payment_failed', ['invoice' => $invoice->number], $actorId);
            if ($subscription->status !== 'suspended') {
                $this->beginGrace($subscription, $actorId);
            }

            return $payment;
        }

        if ($status === 'succeeded') {
            $this->event($subscription, 'payment_received', [
                'invoice' => $invoice->number,
                'amount' => $payment->amount,
            ], $actorId);
            $this->collectInvoice($invoice, $subscription, $actorId);
        }

        return $payment;
    }

    private function collectInvoice(SaasInvoice $invoice, SaasSubscription $subscription, ?string $actorId): void
    {
        $paid = (int) $invoice->payments()->where('status', 'succeeded')->sum('amount');
        if ($paid < $invoice->amount) {
            return;
        }

        $this->settleInvoice($invoice, $subscription, $actorId);
    }

    private function settleInvoice(SaasInvoice $invoice, SaasSubscription $subscription, ?string $actorId): void
    {
        if ($invoice->status !== 'paid') {
            $invoice->status = 'paid';
            $invoice->paid_at = now();
            $invoice->save();
        }

        $previous = $subscription->status;
        $lapsed = in_array($previous, ['trial', 'past_due', 'suspended', 'cancelled'], true)
            || $subscription->period_ends_on === null
            || $subscription->period_ends_on->lt(today());

        $subscription->status = 'active';
        $subscription->grace_ends_on = null;
        $subscription->suspended_at = null;
        $subscription->cancelled_at = null;
        $subscription->plan_code = $invoice->plan_code ?: $subscription->plan_code;
        $subscription->billing_cycle = $invoice->billing_cycle ?: $subscription->billing_cycle;
        if ($lapsed && $invoice->kind !== 'upgrade') {
            $subscription->trial_ends_on = null;
            $subscription->period_starts_on = $invoice->period_starts_on ?? today();
            $subscription->period_ends_on = $invoice->period_ends_on
                ?? $this->periodEnd($subscription->period_starts_on, $subscription->billing_cycle);
        }
        $subscription->save();
        $this->syncTenant($subscription, true);

        if (in_array($previous, ['past_due', 'suspended', 'cancelled'], true)) {
            $this->event($subscription, 'reactivated', ['invoice' => $invoice->number], $actorId);
        }
    }

    private function syncTenant(SaasSubscription $subscription, bool $syncModules, bool $syncStatus = true): void
    {
        $tenant = Tenant::query()->find($subscription->tenant_id);
        if ($tenant === null) {
            return;
        }

        $settings = is_array($tenant->settings) ? $tenant->settings : [];
        $saas = is_array($settings['saas'] ?? null) ? $settings['saas'] : [];
        $current = is_array($saas['subscription'] ?? null) ? $saas['subscription'] : [];
        $planKey = $current['plan'] ?? null;
        $current['commercial_plan'] = $subscription->plan_code;
        $current['status'] = $subscription->status;
        $current['billing_cycle'] = $subscription->billing_cycle;
        $current['renews_on'] = $subscription->period_ends_on?->toDateString();
        if (! is_string($planKey) || ! array_key_exists($planKey, SaasCatalog::PLANS)) {
            $current['plan'] = $subscription->plan_code;
        }
        $saas['subscription'] = $current;
        if ($syncModules) {
            $saas['modules'] = $this->plan($subscription->plan_code)->modules();
        }
        $settings['saas'] = $saas;
        $tenant->settings = $settings;
        $tenant->subscription = $current;
        if ($syncStatus) {
            $tenant->status = match ($subscription->status) {
                'trial' => 'trial',
                'active' => 'active',
                'past_due' => 'past_due',
                'suspended' => 'suspended',
                'cancelled' => 'cancelled',
                default => $tenant->status,
            };
        }
        $tenant->save();
    }

    /** @param  array<string, mixed>  $payload */
    private function event(SaasSubscription $subscription, string $type, array $payload, ?string $actorId): void
    {
        SaasSubscriptionEvent::query()->create([
            'tenant_id' => $subscription->tenant_id,
            'subscription_id' => $subscription->id,
            'type' => $type,
            'payload' => $payload,
            'actor_id' => $actorId,
            'created_at' => now(),
        ]);
    }

    private function nextNumber(): string
    {
        $year = now()->format('Y');
        $last = SaasInvoice::query()->orderByDesc('number')->lockForUpdate()->value('number');
        $seq = 1;
        if (is_string($last) && preg_match('/SAAS-(\d{4})-(\d+)/', $last, $matches) && $matches[1] === $year) {
            $seq = ((int) $matches[2]) + 1;
        }

        return sprintf('SAAS-%s-%05d', $year, $seq);
    }

    private function periodEnd(Carbon $start, string $cycle): Carbon
    {
        $end = $cycle === 'yearly' ? $start->copy()->addYear() : $start->copy()->addMonth();

        return $end->startOfDay();
    }

    private function remainingFraction(SaasSubscription $subscription): float
    {
        if ($subscription->period_starts_on === null || $subscription->period_ends_on === null) {
            return 1.0;
        }

        $total = max(1, (int) $subscription->period_starts_on->diffInDays($subscription->period_ends_on));
        $remaining = max(0, (int) today()->diffInDays($subscription->period_ends_on, false));

        return min(1, $remaining / $total);
    }
}
