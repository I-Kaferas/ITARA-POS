<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Tenant;
use App\Models\User;
use App\Services\Platform\SaasCatalog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class TenantSubscriptionController extends Controller
{
    public function __construct(private readonly SaasCatalog $saas) {}

    public function update(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_unless($user instanceof User, 401);

        $tenant = $user->tenant;
        abort_unless($tenant instanceof Tenant, 404);

        $data = $request->validate([
            'plan' => ['sometimes', 'required', Rule::in(array_keys(SaasCatalog::COMMERCIAL_RANK))],
            'billing_cycle' => ['sometimes', 'required', Rule::in(['monthly', 'yearly'])],
        ]);

        $current = $this->saas->commercialSubscription($tenant);

        if (isset($data['plan']) && SaasCatalog::COMMERCIAL_RANK[$data['plan']] < SaasCatalog::COMMERCIAL_RANK[$current['plan']]) {
            return response()->json([
                'message' => 'Downgrades are not allowed. Only upgrades are permitted.',
            ], 422);
        }

        if (($data['billing_cycle'] ?? null) === 'monthly' && $current['billing_cycle'] === 'yearly') {
            return response()->json([
                'message' => 'You cannot switch from yearly to monthly billing. Yearly subscriptions cannot be downgraded.',
            ], 422);
        }

        $settings = is_array($tenant->settings) ? $tenant->settings : [];
        $saas = is_array($settings['saas'] ?? null) ? $settings['saas'] : [];
        $subscription = is_array($saas['subscription'] ?? null) ? $saas['subscription'] : [];
        $subscription['plan'] = $data['plan'] ?? $current['plan'];
        $subscription['billing_cycle'] = $data['billing_cycle'] ?? $current['billing_cycle'];
        $subscription['status'] = $subscription['status'] ?? $current['status'];
        $saas['subscription'] = $subscription;
        $settings['saas'] = $saas;
        $tenant->settings = $settings;
        $tenant->save();

        return response()->json([
            'data' => $this->saas->commercialSubscription($tenant->fresh()),
        ]);
    }
}
