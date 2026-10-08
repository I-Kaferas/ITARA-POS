<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Tenant;
use App\Models\User;
use App\Services\Platform\SaasPlanCatalog;
use App\Services\Platform\SaasSubscriptionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class TenantSubscriptionController extends Controller
{
    public function __construct(private readonly SaasSubscriptionService $subscriptions) {}

    public function show(Request $request): JsonResponse
    {
        return response()->json($this->subscriptions->show($this->tenant($request)));
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'plan' => ['sometimes', 'required', Rule::in(array_keys(SaasPlanCatalog::definitions()))],
            'billing_cycle' => ['sometimes', 'required', Rule::in(['monthly', 'yearly'])],
        ]);

        return response()->json($this->subscriptions->change(
            $this->tenant($request),
            $data,
            $request->user()?->id,
        ));
    }

    public function subscribe(Request $request): JsonResponse
    {
        $data = $request->validate([
            'plan' => ['required', Rule::in(array_keys(SaasPlanCatalog::definitions()))],
            'billing_cycle' => ['required', Rule::in(['monthly', 'yearly'])],
        ]);

        return response()->json($this->subscriptions->subscribe(
            $this->tenant($request),
            $data['plan'],
            $data['billing_cycle'],
            null,
            $request->user()?->id,
        ));
    }

    public function declarePayment(Request $request): JsonResponse
    {
        $data = $request->validate([
            'invoice_id' => ['required', 'uuid'],
            'method' => ['nullable', Rule::in(['manual', 'transfer', 'card', 'cash', 'mobile_money'])],
            'reference' => ['nullable', 'string', 'max:120'],
            'amount' => ['nullable', 'integer', 'min:1'],
        ]);

        $payment = $this->subscriptions->declarePayment(
            $this->tenant($request),
            $data['invoice_id'],
            $data,
            $request->user()?->id,
        );

        return response()->json(['data' => [
            'id' => $payment->id,
            'status' => $payment->status,
            'amount' => $payment->amount,
            'reference' => $payment->reference,
        ]], 201);
    }

    private function tenant(Request $request): Tenant
    {
        $user = $request->user();
        abort_unless($user instanceof User, 401);
        $tenant = $user->tenant;
        abort_unless($tenant instanceof Tenant, 404);

        return $tenant;
    }
}
