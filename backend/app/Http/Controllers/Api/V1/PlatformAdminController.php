<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Device;
use App\Models\PlatformAuditLog;
use App\Models\SaasInvoice;
use App\Models\SaasPlan;
use App\Models\SaasSubscription;
use App\Models\Sale;
use App\Models\Tenant;
use App\Models\User;
use App\Services\Auth\AuthService;
use App\Services\Authorization\AuthorizationService;
use App\Services\Platform\PlatformAuditLogger;
use App\Modules\ModuleRegistry;
use App\Services\Platform\SaasCatalog;
use App\Services\Platform\SaasPlanCatalog;
use App\Services\Platform\SaasSubscriptionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class PlatformAdminController extends Controller
{
    public function __construct(
        private readonly AuthorizationService $authorization,
        private readonly SaasCatalog $saas,
        private readonly PlatformAuditLogger $audit,
        private readonly SaasSubscriptionService $subscriptions,
    ) {}

    public function overview(Request $request): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $companies = Tenant::query()->get();
        $plans = [];
        foreach ($companies as $company) {
            $plan = $this->saas->saas($company)['subscription']['plan'] ?? 'unset';
            $plans[$plan] = ($plans[$plan] ?? 0) + 1;
        }

        $activeSubs = SaasSubscription::query()
            ->with('plan')
            ->whereIn('status', ['active', 'trial', 'past_due'])
            ->get();
        $subscriptionMrr = 0;
        foreach ($activeSubs as $subscription) {
            $plan = $subscription->plan;
            if ($plan === null) {
                continue;
            }
            $subscriptionMrr += $subscription->billing_cycle === 'monthly'
                ? (int) $plan->monthly_price
                : (int) round(((int) $plan->yearly_price) / 12);
        }

        $openInvoices = (int) SaasInvoice::query()->where('status', 'open')->sum('amount');

        return response()->json([
            'data' => [
                'companies' => $companies->count(),
                'users' => User::withoutGlobalScopes()->whereNotNull('tenant_id')->count(),
                'devices' => Device::withoutGlobalScopes()->count(),
                'sales' => $this->salesCount(),
                'revenue' => $this->revenue(),
                'subscription_mrr' => $subscriptionMrr,
                'open_invoices' => $openInvoices,
                'plans' => $plans,
                'modules' => SaasCatalog::MODULES,
                'available_plans' => array_keys(SaasPlanCatalog::definitions()),
            ],
        ]);
    }

    public function companies(Request $request): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $users = User::withoutGlobalScopes()->whereNotNull('tenant_id')->selectRaw('tenant_id, COUNT(*) as aggregate')->groupBy('tenant_id')->pluck('aggregate', 'tenant_id');
        $devices = Device::withoutGlobalScopes()->selectRaw('tenant_id, COUNT(*) as aggregate')->groupBy('tenant_id')->pluck('aggregate', 'tenant_id');

        $query = Tenant::query()->orderBy('name');
        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }
        if ($request->filled('q')) {
            $term = '%'.$request->string('q').'%';
            $query->where(function ($inner) use ($term) {
                $inner->where('name', 'like', $term)->orWhere('slug', 'like', $term);
            });
        }

        $billingRows = SaasSubscription::query()->get()->keyBy('tenant_id');
        $openInvoices = SaasInvoice::query()->where('status', 'open')->orderBy('due_on')->get()->groupBy('tenant_id');

        $rows = $query->get()->map(function (Tenant $tenant) use ($users, $devices, $billingRows, $openInvoices) {
            $saas = $this->saas->saas($tenant);
            $open = $openInvoices->get($tenant->id)?->first();

            return [
                'id' => $tenant->id,
                'name' => $tenant->name,
                'slug' => $tenant->slug,
                'status' => $tenant->status,
                'profile' => $tenant->profile(),
                'modules' => $saas['modules'],
                'modules_locked' => $saas['modules_locked'],
                'license' => $saas['license'],
                'subscription' => $saas['subscription'],
                'billing' => $this->subscriptions->summarize($billingRows->get($tenant->id), $open),
                'open_support' => collect($saas['support'])->where('status', 'open')->count(),
                'users' => (int) ($users[$tenant->id] ?? 0),
                'devices' => (int) ($devices[$tenant->id] ?? 0),
                'signup' => [
                    'awaiting_approval' => (bool) data_get($tenant->settings, 'signup.awaiting_approval', false),
                    'requested_plan' => data_get($tenant->settings, 'signup.requested_plan'),
                ],
            ];
        });

        return response()->json(['data' => $rows]);
    }

    public function approveSignup(Request $request, Tenant $tenant): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $settings = $tenant->settings ?? [];
        $signup = is_array($settings['signup'] ?? null) ? $settings['signup'] : [];
        $plan = is_string($signup['requested_plan'] ?? null) ? $signup['requested_plan'] : 'starter';
        $signup['awaiting_approval'] = false;
        $signup['approved_at'] = now()->toIso8601String();
        $settings['signup'] = $signup;
        $saas = is_array($settings['saas'] ?? null) ? $settings['saas'] : [];
        $saas['subscription'] = is_array($saas['subscription'] ?? null) ? $saas['subscription'] : [];
        $saas['subscription']['plan'] = SaasCatalog::toCommercial($plan);
        $saas['subscription']['status'] = 'active';
        $settings['saas'] = $saas;
        $tenant->settings = $settings;
        $tenant->subscription = $saas['subscription'];
        $tenant->status = 'active';
        $tenant->save();
        $this->subscriptions->alignLegacy($tenant, ['status' => 'active']);
        $this->audit->record($request->user(), 'tenant.signup_approved', $tenant->id, [
            'plan' => $plan,
        ], $request->ip());

        return response()->json([
            'data' => [
                'id' => $tenant->id,
                'status' => $tenant->status,
                'plan' => $saas['subscription']['plan'],
            ],
        ]);
    }

    public function updateCompany(Request $request, Tenant $tenant): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $planCodes = array_values(array_unique(array_merge(
            array_keys(SaasCatalog::PLANS),
            array_keys(SaasCatalog::COMMERCIAL_RANK),
        )));
        $data = $request->validate([
            'status' => ['sometimes', Rule::in(SaasCatalog::LIFECYCLE)],
            'plan' => ['sometimes', 'nullable', Rule::in($planCodes)],
            'modules' => ['sometimes', 'array'],
            'modules.*' => ['string', Rule::in(array_merge(ModuleRegistry::CODES, array_keys(ModuleRegistry::ALIASES)))],
            'license_status' => ['sometimes', Rule::in(['active', 'suspended', 'expired'])],
            'license_seats' => ['sometimes', 'integer', 'min:0'],
            'license_expires_on' => ['sometimes', 'nullable', 'date'],
            'subscription_status' => ['sometimes', Rule::in(['active', 'trial', 'past_due', 'suspended', 'cancelled'])],
            'renews_on' => ['sometimes', 'nullable', 'date'],
        ]);

        $settings = $tenant->settings ?? [];
        $saas = is_array($settings['saas'] ?? null) ? $settings['saas'] : [];
        $saas['license'] = is_array($saas['license'] ?? null) ? $saas['license'] : [];
        $saas['subscription'] = is_array($saas['subscription'] ?? null) ? $saas['subscription'] : [];
        $modules = $saas['modules'] ?? $this->saas->modules($tenant);
        if (array_key_exists('plan', $data) && $data['plan']) {
            $commercial = SaasCatalog::toCommercial($data['plan']);
            $definition = SaasPlanCatalog::definitions()[$commercial] ?? null;
            if (is_array($definition) && isset($definition['limits']['modules']) && is_array($definition['limits']['modules'])) {
                $modules = $definition['limits']['modules'];
            } elseif (isset(SaasCatalog::PLANS[$data['plan']])) {
                $modules = SaasCatalog::PLANS[$data['plan']];
            }
            $saas['subscription']['plan'] = $commercial;
        }
        if (array_key_exists('modules', $data)) {
            $modules = array_values(array_unique($data['modules']));
        }
        $saas['modules'] = ModuleRegistry::normalize($modules);
        if ($saas['modules'] === []) {
            return response()->json(['message' => 'Au moins un module doit rester activé.'], 422);
        }
        $saas['license']['key'] = $saas['license']['key'] ?? ('ITARA-'.strtoupper(Str::random(4)).'-'.strtoupper(Str::random(4)));
        $saas['license']['status'] = $data['license_status'] ?? ($saas['license']['status'] ?? 'active');
        $saas['license']['seats'] = $data['license_seats'] ?? ($saas['license']['seats'] ?? 0);
        $saas['license']['expires_on'] = array_key_exists('license_expires_on', $data)
            ? $data['license_expires_on']
            : ($saas['license']['expires_on'] ?? null);
        $saas['subscription']['plan'] = $saas['subscription']['plan'] ?? ($data['plan'] ?? null);
        $saas['subscription']['status'] = $data['subscription_status'] ?? ($saas['subscription']['status'] ?? 'active');
        $saas['subscription']['renews_on'] = array_key_exists('renews_on', $data)
            ? $data['renews_on']
            : ($saas['subscription']['renews_on'] ?? null);
        $settings['saas'] = $saas;
        $tenant->settings = $settings;
        $tenant->subscription = $saas['subscription'];
        if (isset($data['status'])) {
            $tenant->status = $data['status'];
        }
        $tenant->save();

        $legacy = [];
        if (isset($data['subscription_status'])) {
            $legacy['status'] = $data['subscription_status'];
        }
        if (array_key_exists('renews_on', $data)) {
            $legacy['renews_on'] = $saas['subscription']['renews_on'] ?? null;
        }
        if (isset($data['status']) && in_array($data['status'], ['trial', 'active', 'past_due', 'suspended', 'cancelled'], true)) {
            $legacy['status'] = $data['status'];
        }
        if ($legacy !== []) {
            $this->subscriptions->alignLegacy($tenant, $legacy);
        }

        $this->audit->record($request->user(), 'tenant.updated', $tenant->id, [
            'status' => $tenant->status,
            'plan' => $saas['subscription']['plan'] ?? null,
            'modules' => $saas['modules'],
        ], $request->ip());

        return response()->json(['data' => ['id' => $tenant->id, 'modules' => $saas['modules'], 'license' => $saas['license'], 'subscription' => $saas['subscription']]]);
    }

    public function devices(Request $request): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $names = Tenant::query()->pluck('name', 'id');

        $rows = Device::withoutGlobalScopes()
            ->orderByDesc('last_sync_at')
            ->limit(200)
            ->get(['id', 'tenant_id', 'name', 'code', 'platform', 'status', 'is_active', 'last_sync_at'])
            ->map(fn (Device $device) => [
                'id' => $device->id,
                'company' => $names[$device->tenant_id] ?? null,
                'name' => $device->name,
                'code' => $device->code,
                'platform' => $device->platform,
                'status' => $device->status,
                'is_active' => $device->is_active,
                'last_sync_at' => $device->last_sync_at,
            ]);

        return response()->json(['data' => $rows]);
    }

    public function users(Request $request): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $names = Tenant::query()->pluck('name', 'id');

        $rows = User::withoutGlobalScopes()
            ->whereNotNull('tenant_id')
            ->orderBy('name')
            ->limit(200)
            ->get(['id', 'tenant_id', 'name', 'email', 'is_active'])
            ->map(fn (User $user) => [
                'id' => $user->id,
                'company' => $names[$user->tenant_id] ?? null,
                'name' => $user->name,
                'email' => $user->email,
                'is_active' => $user->is_active,
            ]);

        return response()->json(['data' => $rows]);
    }

    public function support(Request $request): JsonResponse
    {
        $this->assertSuperAdmin($request);

        return response()->json(['data' => $this->tickets()]);
    }

    public function storeSupport(Request $request): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $data = $request->validate([
            'tenant_id' => ['required', 'uuid', 'exists:tenants,id'],
            'subject' => ['required', 'string', 'max:160'],
            'message' => ['required', 'string', 'max:2000'],
        ]);
        $tenant = Tenant::query()->findOrFail($data['tenant_id']);
        $settings = $tenant->settings ?? [];
        $saas = is_array($settings['saas'] ?? null) ? $settings['saas'] : [];
        $saas['support'] = is_array($saas['support'] ?? null) ? $saas['support'] : [];
        $saas['support'][] = [
            'id' => (string) Str::uuid(),
            'subject' => $data['subject'],
            'message' => $data['message'],
            'status' => 'open',
            'created_at' => now()->toIso8601String(),
        ];
        $settings['saas'] = $saas;
        $tenant->settings = $settings;
        $tenant->save();

        $this->audit->record($request->user(), 'tenant.support.opened', $tenant->id, [
            'subject' => $data['subject'],
        ], $request->ip());

        return response()->json(['data' => ['stored' => true]], 201);
    }

    public function closeSupport(Request $request, string $ticket): JsonResponse
    {
        $this->assertSuperAdmin($request);
        foreach (Tenant::query()->get() as $tenant) {
            $settings = $tenant->settings ?? [];
            $saas = is_array($settings['saas'] ?? null) ? $settings['saas'] : [];
            $items = $saas['support'] ?? [];
            $found = false;
            foreach ($items as &$item) {
                if (($item['id'] ?? '') === $ticket) {
                    $item['status'] = 'closed';
                    $found = true;
                }
            }
            unset($item);
            if (! $found) {
                continue;
            }
            $saas['support'] = $items;
            $settings['saas'] = $saas;
            $tenant->settings = $settings;
            $tenant->save();

            $this->audit->record($request->user(), 'tenant.support.closed', $tenant->id, [
                'ticket' => $ticket,
            ], $request->ip());

            return response()->json(['data' => ['closed' => true]]);
        }

        abort(404);
    }

    public function audit(Request $request): JsonResponse
    {
        $this->assertSuperAdmin($request);

        $rows = PlatformAuditLog::query()
            ->with(['actor' => fn ($query) => $query->withoutGlobalScopes()->select('id', 'name', 'email')])
            ->latest('created_at')
            ->limit(100)
            ->get()
            ->map(fn (PlatformAuditLog $log) => [
                'id' => $log->id,
                'action' => $log->action,
                'tenant_id' => $log->tenant_id,
                'payload' => $log->payload,
                'ip_address' => $log->ip_address,
                'created_at' => $log->created_at,
                'actor' => $log->actor ? [
                    'name' => $log->actor->name,
                    'email' => $log->actor->email,
                ] : null,
            ]);

        return response()->json(['data' => $rows]);
    }

    public function revokeDevice(Request $request, string $device): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $row = Device::withoutGlobalScopes()->find($device);
        if ($row === null) {
            return response()->json(['message' => 'Appareil introuvable.'], 404);
        }

        $row->forceFill([
            'status' => 'revoked',
            'registration_status' => 'revoked',
            'is_active' => false,
            'revoked_at' => now(),
        ])->save();

        $this->audit->record($request->user(), 'device.revoked', $row->tenant_id, [
            'device_id' => $row->id,
        ], $request->ip());

        return response()->json(['data' => ['id' => $row->id, 'status' => 'revoked']]);
    }

    public function restoreDevice(Request $request, string $device): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $row = Device::withoutGlobalScopes()->find($device);
        if ($row === null) {
            return response()->json(['message' => 'Appareil introuvable.'], 404);
        }

        $row->forceFill([
            'status' => 'active',
            'registration_status' => 'registered',
            'is_active' => true,
            'revoked_at' => null,
            'registered_at' => $row->registered_at ?? now(),
        ])->save();

        $this->audit->record($request->user(), 'device.restored', $row->tenant_id, [
            'device_id' => $row->id,
        ], $request->ip());

        return response()->json(['data' => ['id' => $row->id, 'status' => 'registered']]);
    }

    public function impersonate(Request $request, Tenant $tenant): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $target = User::query()->withoutGlobalScopes()
            ->where('tenant_id', $tenant->id)
            ->where('is_active', true)
            ->whereHas('roles', fn ($query) => $query->whereIn('slug', ['administrator', 'admin']))
            ->orderBy('created_at')
            ->first();

        if ($target === null) {
            $target = User::query()->withoutGlobalScopes()
                ->where('tenant_id', $tenant->id)
                ->where('is_active', true)
                ->orderBy('created_at')
                ->first();
        }

        if ($target === null) {
            return response()->json(['message' => 'Aucun administrateur actif pour ce commerce.'], 422);
        }

        $this->audit->record($request->user(), 'tenant.impersonated', $tenant->id, [
            'user_id' => $target->id,
        ], $request->ip());

        return response()->json(app(AuthService::class)->issueSession($target, $request, 'platform-support'));
    }

    /** @return list<array<string, mixed>> */
    private function tickets(): array
    {
        $rows = [];
        foreach (Tenant::query()->orderBy('name')->get() as $tenant) {
            foreach ($this->saas->saas($tenant)['support'] as $ticket) {
                $rows[] = [
                    'id' => $ticket['id'] ?? null,
                    'company' => $tenant->name,
                    'tenant_id' => $tenant->id,
                    'subject' => $ticket['subject'] ?? '',
                    'message' => $ticket['message'] ?? '',
                    'status' => $ticket['status'] ?? 'open',
                    'created_at' => $ticket['created_at'] ?? null,
                ];
            }
        }
        usort($rows, fn (array $a, array $b) => strcmp((string) ($b['created_at'] ?? ''), (string) ($a['created_at'] ?? '')));

        return array_slice($rows, 0, 80);
    }

    private function salesCount(): int
    {
        if (! Schema::hasTable('sales')) {
            return 0;
        }

        return (int) Sale::withoutGlobalScopes()->where('status', 'completed')->count();
    }

    private function revenue(): int
    {
        if (! Schema::hasTable('sales')) {
            return 0;
        }

        return (int) Sale::withoutGlobalScopes()->where('status', 'completed')->sum('total');
    }

    private function assertSuperAdmin(Request $request): void
    {
        $user = $request->user();
        abort_unless($user instanceof User && $this->authorization->isSuperAdmin($user), 403);
    }
}
