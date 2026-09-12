<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AuthToken;
use App\Models\Role;
use App\Models\User;
use App\Services\Auth\AuthTokenService;
use App\Tenancy\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class UserController extends Controller
{
    public function __construct(
        private TenantContext $tenantContext,
        private AuthTokenService $tokens,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $search = trim((string) $request->query('search', ''));
        $status = (string) $request->query('status', 'all');
        $roleId = $request->query('role_id');

        $users = User::query()
            ->with(['roles:id,name,slug', 'stores:id,name,code'])
            ->withMax('authTokens as last_seen_at', 'last_used_at')
            ->withCount(['authTokens as active_sessions_count' => function ($query) {
                $query->whereNull('revoked_at')->where('refresh_expires_at', '>', now());
            }])
            ->when($search !== '', function ($query) use ($search) {
                $query->where(function ($query) use ($search) {
                    $query->where('name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%")
                        ->orWhere('phone', 'like', "%{$search}%")
                        ->orWhere('pin', 'like', "%{$search}%");
                });
            })
            ->when($status === 'active', fn ($query) => $query->where('is_active', true))
            ->when($status === 'inactive', fn ($query) => $query->where('is_active', false))
            ->when($roleId, fn ($query) => $query->whereHas('roles', fn ($query) => $query->where('roles.id', $roleId)))
            ->orderBy('name')
            ->get()
            ->map(fn (User $user) => $this->formatUser($user));

        return response()->json([
            'data' => $users,
            'meta' => [
                'total' => $users->count(),
                'active' => $users->where('is_active', true)->count(),
                'inactive' => $users->where('is_active', false)->count(),
            ],
        ]);
    }

    public function show(User $user): JsonResponse
    {
        $this->ensureTenantUser($user);
        $user = $this->reloadUser($user);

        return response()->json(['data' => $this->formatUser($user)]);
    }

    public function store(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext->tenant();
        abort_if($tenant === null, 500, 'Tenant context is not bound.');

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['nullable', 'string', 'max:50'],
            'pin' => ['nullable', 'regex:/^\d{4,6}$/', Rule::unique('users', 'pin')->where(fn ($query) => $query->where('tenant_id', $tenant->id))],
            'password' => ['required', 'string', Password::min(8)],
            'is_active' => ['boolean'],
            'role_id' => ['nullable', 'uuid', 'exists:roles,id'],
            'store_id' => ['nullable', 'uuid', 'exists:stores,id'],
        ]);

        $user = User::query()->create([
            'tenant_id' => $tenant->id,
            'name' => $data['name'],
            'email' => $data['email'],
            'phone' => $data['phone'] ?? null,
            'pin' => $this->normalizePin($data['pin'] ?? null) ?? $this->generateUniquePin($tenant->id),
            'password' => $data['password'],
            'is_active' => $data['is_active'] ?? true,
            'email_verified_at' => now(),
        ]);

        if (! empty($data['role_id'])) {
            $this->assignRole($user, $data['role_id'], $data['store_id'] ?? null);
        }

        return response()->json(['data' => $this->formatUser($this->reloadUser($user))], 201);
    }

    public function update(Request $request, User $user): JsonResponse
    {
        $this->ensureTenantUser($user);

        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'email' => ['sometimes', 'email', 'max:255', Rule::unique('users', 'email')->ignore($user->id)],
            'phone' => ['nullable', 'string', 'max:50'],
            'pin' => ['sometimes', 'nullable', 'regex:/^\d{4,6}$/', Rule::unique('users', 'pin')->ignore($user->id)->where(fn ($query) => $query->where('tenant_id', $user->tenant_id))],
            'password' => ['sometimes', 'nullable', 'string', Password::min(8)],
            'is_active' => ['boolean'],
        ]);

        if (array_key_exists('password', $data) && ($data['password'] === null || $data['password'] === '')) {
            unset($data['password']);
        }

        if (array_key_exists('pin', $data)) {
            $data['pin'] = $this->normalizePin($data['pin']) ?? $user->pin ?? $this->generateUniquePin($user->tenant_id, $user->id);
        }

        $user->update($data);

        return response()->json(['data' => $this->formatUser($this->reloadUser($user))]);
    }

    public function destroy(Request $request, User $user): JsonResponse
    {
        $this->ensureTenantUser($user);

        if ($request->user()?->id === $user->id) {
            return response()->json(['message' => 'You cannot delete your own account.'], 422);
        }

        $user->authTokens()->delete();
        $user->update(['pin' => null]);
        $user->delete();

        return response()->json(null, 204);
    }

    public function resetPassword(Request $request, User $user): JsonResponse
    {
        $this->ensureTenantUser($user);

        $data = $request->validate([
            'password' => ['required', 'string', Password::min(8)],
        ]);

        $user->update(['password' => $data['password']]);
        $this->tokens->revokeAllForUser($user);

        return response()->json(['message' => 'Password reset. Active sessions were revoked.']);
    }

    public function activate(Request $request, User $user): JsonResponse
    {
        $this->ensureTenantUser($user);
        $user->update(['is_active' => true]);

        return response()->json(['data' => $this->formatUser($this->reloadUser($user))]);
    }

    public function deactivate(Request $request, User $user): JsonResponse
    {
        $this->ensureTenantUser($user);

        if ($request->user()?->id === $user->id) {
            return response()->json(['message' => 'You cannot deactivate your own account.'], 422);
        }

        $user->update(['is_active' => false]);
        $this->tokens->revokeAllForUser($user);

        return response()->json(['data' => $this->formatUser($this->reloadUser($user))]);
    }

    public function assignStore(Request $request, User $user): JsonResponse
    {
        $this->ensureTenantUser($user);

        $data = $request->validate([
            'store_ids' => ['nullable', 'array'],
            'store_ids.*' => ['uuid', 'exists:stores,id'],
            'store_id' => ['nullable', 'uuid', 'exists:stores,id'],
            'role_id' => ['nullable', 'uuid', 'exists:roles,id'],
        ]);

        $storeIds = array_values(array_unique($data['store_ids'] ?? (
            ! empty($data['store_id']) ? [$data['store_id']] : []
        )));

        $user->load('roles');

        if ($user->roles->isEmpty()) {
            if (empty($data['role_id'])) {
                return response()->json(['message' => 'Assignez d’abord un rôle à cet utilisateur.'], 422);
            }
            $this->assignRole($user, $data['role_id'], $storeIds[0] ?? null);
        }

        $user->stores()->sync($storeIds);
        $user->clearPermissionCache();

        return response()->json(['data' => $this->formatUser($this->reloadUser($user))]);
    }

    public function sessions(User $user): JsonResponse
    {
        $this->ensureTenantUser($user);

        $sessions = AuthToken::query()
            ->where('user_id', $user->id)
            ->whereNull('revoked_at')
            ->where('refresh_expires_at', '>', now())
            ->orderByDesc('last_used_at')
            ->get()
            ->map(fn (AuthToken $token) => [
                'id' => $token->id,
                'device_name' => $token->device_name,
                'ip_address' => $token->ip_address,
                'last_used_at' => $token->last_used_at?->toIso8601String(),
                'created_at' => $token->created_at?->toIso8601String(),
            ]);

        return response()->json(['data' => $sessions]);
    }

    public function revokeSessions(User $user): JsonResponse
    {
        $this->ensureTenantUser($user);
        $this->tokens->revokeAllForUser($user);

        return response()->json(['message' => 'Sessions revoked.']);
    }

    private function reloadUser(User $user): User
    {
        return User::query()
            ->with(['roles:id,name,slug', 'stores:id,name,code'])
            ->withMax('authTokens as last_seen_at', 'last_used_at')
            ->withCount(['authTokens as active_sessions_count' => function ($query) {
                $query->whereNull('revoked_at')->where('refresh_expires_at', '>', now());
            }])
            ->findOrFail($user->id);
    }

    private function assignRole(User $user, string $roleId, ?string $storeId): void
    {
        $tenant = $this->tenantContext->tenant();
        $role = Role::query()->findOrFail($roleId);

        if ($role->tenant_id !== $tenant?->id) {
            abort(422, 'Role does not belong to this tenant.');
        }

        $user->roles()->syncWithoutDetaching([
            $role->id => [
                'branch_id' => null,
                'store_id' => $storeId,
            ],
        ]);
        $user->clearPermissionCache();
    }

    private function ensureTenantUser(User $user): void
    {
        $tenant = $this->tenantContext->tenant();
        abort_if($tenant === null, 500, 'Tenant context is not bound.');

        if ($user->tenant_id !== $tenant->id) {
            abort(404);
        }
    }

    private function normalizePin(mixed $pin): ?string
    {
        $pin = is_string($pin) ? trim($pin) : '';

        return $pin === '' ? null : $pin;
    }

    private function generateUniquePin(?string $tenantId, ?string $ignoreUserId = null): string
    {
        for ($attempt = 0; $attempt < 40; $attempt++) {
            $pin = str_pad((string) random_int(0, 9999), 4, '0', STR_PAD_LEFT);
            $exists = User::withTrashed()
                ->when($tenantId, fn ($query) => $query->where('tenant_id', $tenantId))
                ->when($ignoreUserId, fn ($query) => $query->where('id', '!=', $ignoreUserId))
                ->where('pin', $pin)
                ->exists();

            if (! $exists) {
                return $pin;
            }
        }

        return str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    }

    /** @return array<string, mixed> */
    private function formatUser(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'phone' => $user->phone,
            'pin' => $user->pin,
            'tenant_id' => $user->tenant_id,
            'is_active' => $user->is_active,
            'email_verified' => $user->email_verified_at !== null,
            'two_factor_enabled' => $user->hasTwoFactorEnabled(),
            'created_at' => $user->created_at?->toIso8601String(),
            'last_seen_at' => $user->last_seen_at ? \Illuminate\Support\Carbon::parse($user->last_seen_at)->toIso8601String() : null,
            'active_sessions_count' => (int) ($user->active_sessions_count ?? 0),
            'roles' => $user->roles->map(fn ($role) => [
                'id' => $role->id,
                'slug' => $role->slug,
                'name' => $role->name,
                'branch_id' => $role->pivot->branch_id ?? null,
                'store_id' => $role->pivot->store_id ?? null,
            ])->values(),
            'store_ids' => $user->stores->pluck('id')->values(),
            'stores' => $user->stores->map(fn ($store) => $store->only(['id', 'name', 'code']))->values(),
        ];
    }
}
