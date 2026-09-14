<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Device;
use App\Models\Sale;
use App\Models\Tenant;
use App\Models\User;
use App\Services\Authorization\AuthorizationService;
use App\Services\Platform\SaasCatalog;
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

        return response()->json([
            'data' => [
                'companies' => $companies->count(),
                'users' => User::withoutGlobalScopes()->whereNotNull('tenant_id')->count(),
                'devices' => Device::withoutGlobalScopes()->count(),
                'sales' => $this->salesCount(),
                'revenue' => $this->revenue(),
                'plans' => $plans,
                'modules' => SaasCatalog::MODULES,
                'available_plans' => SaasCatalog::PLANS,
            ],
        ]);
    }

    public function companies(Request $request): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $users = User::withoutGlobalScopes()->whereNotNull('tenant_id')->selectRaw('tenant_id, COUNT(*) as aggregate')->groupBy('tenant_id')->pluck('aggregate', 'tenant_id');
        $devices = Device::withoutGlobalScopes()->selectRaw('tenant_id, COUNT(*) as aggregate')->groupBy('tenant_id')->pluck('aggregate', 'tenant_id');

        $rows = Tenant::query()->orderBy('name')->get()->map(function (Tenant $tenant) use ($users, $devices) {
            $saas = $this->saas->saas($tenant);

            return [
                'id' => $tenant->id,
                'name' => $tenant->name,
                'slug' => $tenant->slug,
                'status' => $tenant->status,
                'modules' => $saas['modules'],
                'modules_locked' => $saas['modules_locked'],
                'license' => $saas['license'],
                'subscription' => $saas['subscription'],
                'open_support' => collect($saas['support'])->where('status', 'open')->count(),
                'users' => (int) ($users[$tenant->id] ?? 0),
                'devices' => (int) ($devices[$tenant->id] ?? 0),
            ];
        });

        return response()->json(['data' => $rows]);
    }

    public function updateCompany(Request $request, Tenant $tenant): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $data = $request->validate([
            'status' => ['sometimes', 'string', 'max:40'],
            'plan' => ['sometimes', 'nullable', Rule::in(array_keys(SaasCatalog::PLANS))],
            'modules' => ['sometimes', 'array'],
            'modules.*' => ['string', Rule::in(SaasCatalog::MODULES)],
            'license_status' => ['sometimes', Rule::in(['active', 'suspended', 'expired'])],
            'license_seats' => ['sometimes', 'integer', 'min:0'],
            'license_expires_on' => ['sometimes', 'nullable', 'date'],
            'subscription_status' => ['sometimes', Rule::in(['active', 'trial', 'past_due', 'cancelled'])],
            'renews_on' => ['sometimes', 'nullable', 'date'],
        ]);

        $settings = $tenant->settings ?? [];
        $saas = is_array($settings['saas'] ?? null) ? $settings['saas'] : [];
        $modules = $saas['modules'] ?? $this->saas->modules($tenant);
        if (array_key_exists('plan', $data) && $data['plan']) {
            $modules = SaasCatalog::PLANS[$data['plan']];
            $saas['subscription']['plan'] = $data['plan'];
        }
        if (array_key_exists('modules', $data)) {
            $modules = array_values(array_unique($data['modules']));
        }
        $saas['modules'] = array_values(array_intersect(SaasCatalog::MODULES, $modules));
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
        if (isset($data['status'])) {
            $tenant->status = $data['status'];
        }
        $tenant->save();

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

            return response()->json(['data' => ['closed' => true]]);
        }

        abort(404);
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
