<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\SaasInvoice;
use App\Models\SaasPayment;
use App\Models\Tenant;
use App\Models\User;
use App\Services\Authorization\AuthorizationService;
use App\Services\Platform\PlatformAuditLogger;
use App\Services\Platform\SaasCatalog;
use App\Services\Platform\SaasPlanCatalog;
use App\Services\Platform\SaasSubscriptionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PlatformSubscriptionController extends Controller
{
    public function __construct(
        private readonly SaasSubscriptionService $subscriptions,
        private readonly AuthorizationService $authorization,
        private readonly PlatformAuditLogger $audit,
    ) {}

    public function plans(Request $request): JsonResponse
    {
        $this->assertSuperAdmin($request);

        return response()->json([
            'modules' => SaasCatalog::MODULES,
            'data' => $this->subscriptions->catalog()->map(fn ($plan) => [
                'code' => $plan->code,
                'name' => $plan->name,
                'rank' => $plan->rank,
                'monthly_price' => $plan->monthly_price,
                'yearly_price' => $plan->yearly_price,
                'currency' => $plan->currency_code,
                'trial_days' => $plan->trial_days,
                'grace_days' => $plan->grace_days,
                'limits' => [
                    'users' => $plan->limit('users'),
                    'branches' => $plan->limit('branches'),
                    'pos' => $plan->limit('pos'),
                    'products' => $plan->limit('products'),
                    'storage_mb' => $plan->limit('storage_mb'),
                    'transactions' => $plan->limit('transactions'),
                    'modules' => $plan->modules(),
                ],
            ])->values(),
        ]);
    }

    public function updatePlan(Request $request, string $code): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:80'],
            'monthly_price' => ['sometimes', 'integer', 'min:0'],
            'yearly_price' => ['sometimes', 'integer', 'min:0'],
            'trial_days' => ['sometimes', 'integer', 'min:0', 'max:365'],
            'grace_days' => ['sometimes', 'integer', 'min:0', 'max:90'],
            'limits' => ['sometimes', 'array'],
            'limits.users' => ['nullable', 'integer', 'min:0'],
            'limits.branches' => ['nullable', 'integer', 'min:0'],
            'limits.pos' => ['nullable', 'integer', 'min:0'],
            'limits.products' => ['nullable', 'integer', 'min:0'],
            'limits.storage_mb' => ['nullable', 'integer', 'min:0'],
            'limits.transactions' => ['nullable', 'integer', 'min:0'],
            'limits.modules' => ['sometimes', 'array', 'min:1'],
            'limits.modules.*' => ['string', Rule::in(SaasCatalog::MODULES)],
        ]);

        $plan = $this->subscriptions->updatePlan($code, $data);
        $this->audit->record($request->user(), 'saas.plan.updated', null, [
            'plan' => $plan->code,
            'limits' => $plan->limits,
        ], $request->ip());

        return response()->json(['data' => [
            'code' => $plan->code,
            'limits' => $plan->limits,
            'monthly_price' => $plan->monthly_price,
            'yearly_price' => $plan->yearly_price,
            'trial_days' => $plan->trial_days,
            'grace_days' => $plan->grace_days,
        ]]);
    }

    public function subscribe(Request $request, Tenant $tenant): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $data = $request->validate([
            'plan' => ['required', Rule::in(array_keys(SaasPlanCatalog::definitions()))],
            'billing_cycle' => ['required', Rule::in(['monthly', 'yearly'])],
            'payment' => ['nullable', 'array'],
            'payment.method' => ['nullable', Rule::in(['manual', 'transfer', 'card', 'cash', 'mobile_money'])],
            'payment.reference' => ['nullable', 'string', 'max:120'],
            'payment.amount' => ['nullable', 'integer', 'min:0'],
            'payment.status' => ['nullable', Rule::in(['pending', 'succeeded', 'failed'])],
        ]);

        $view = $this->subscriptions->subscribe(
            $tenant,
            $data['plan'],
            $data['billing_cycle'],
            $data['payment'] ?? null,
            $request->user()?->id,
        );
        $this->audit->record($request->user(), 'saas.subscribed', $tenant->id, [
            'plan' => $data['plan'],
            'billing_cycle' => $data['billing_cycle'],
        ], $request->ip());

        return response()->json($view);
    }

    public function change(Request $request, Tenant $tenant): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $data = $request->validate([
            'plan' => ['sometimes', 'required', Rule::in(array_keys(SaasPlanCatalog::definitions()))],
            'billing_cycle' => ['sometimes', 'required', Rule::in(['monthly', 'yearly'])],
        ]);

        return response()->json($this->subscriptions->change($tenant, $data, $request->user()?->id));
    }

    public function grace(Request $request, Tenant $tenant): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $view = $this->subscriptions->openGrace($tenant, $request->user()?->id);
        $this->audit->record($request->user(), 'saas.grace_started', $tenant->id, [], $request->ip());

        return response()->json($view);
    }

    public function suspend(Request $request, Tenant $tenant): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $view = $this->subscriptions->suspend($tenant, $request->user()?->id);
        $this->audit->record($request->user(), 'saas.suspended', $tenant->id, [], $request->ip());

        return response()->json($view);
    }

    public function storePayment(Request $request, SaasInvoice $invoice): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $data = $request->validate([
            'method' => ['nullable', Rule::in(['manual', 'transfer', 'card', 'cash', 'mobile_money'])],
            'reference' => ['nullable', 'string', 'max:120'],
            'amount' => ['nullable', 'integer', 'min:0'],
            'status' => ['nullable', Rule::in(['pending', 'succeeded', 'failed'])],
        ]);

        $payment = $this->subscriptions->recordPayment($invoice, $data, $request->user()?->id);
        $this->audit->record($request->user(), 'saas.payment.recorded', $invoice->tenant_id, [
            'invoice' => $invoice->number,
            'status' => $payment->status,
            'amount' => $payment->amount,
        ], $request->ip());

        return response()->json(['data' => [
            'id' => $payment->id,
            'status' => $payment->status,
            'amount' => $payment->amount,
            'invoice_status' => $invoice->fresh()?->status,
        ]], 201);
    }

    public function settlePayment(Request $request, SaasPayment $payment): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $data = $request->validate([
            'status' => ['required', Rule::in(['succeeded', 'failed'])],
        ]);

        $payment = $this->subscriptions->settlePayment($payment, $data['status'], $request->user()?->id);

        return response()->json(['data' => [
            'id' => $payment->id,
            'status' => $payment->status,
        ]]);
    }

    private function assertSuperAdmin(Request $request): void
    {
        $user = $request->user();
        abort_unless($user instanceof User && $this->authorization->isSuperAdmin($user), 403);
    }
}
