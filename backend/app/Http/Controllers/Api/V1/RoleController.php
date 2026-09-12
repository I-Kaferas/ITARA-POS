<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Role;
use App\Services\Authorization\AuthorizationService;
use App\Services\Rbac\RoleProvisioningService;
use App\Tenancy\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RoleController extends Controller
{
    public function __construct(
        private TenantContext $tenantContext,
        private RoleProvisioningService $roleProvisioning,
        private AuthorizationService $authorization,
    ) {}

    public function index(): JsonResponse
    {
        $tenant = $this->tenantContext->tenant();
        abort_if($tenant === null, 500, 'Tenant context is not bound.');

        $roles = Role::query()
            ->where('tenant_id', $tenant->id)
            ->with('permissions:id,slug,name,group')
            ->orderBy('name')
            ->get()
            ->map(fn (Role $role) => $this->formatRole($role));

        return response()->json(['data' => $roles]);
    }

    public function show(Role $role): JsonResponse
    {
        $this->ensureTenantRole($role);
        $role->load('permissions:id,slug,name,group');

        return response()->json(['data' => $this->formatRole($role)]);
    }

    public function store(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext->tenant();
        abort_if($tenant === null, 500, 'Tenant context is not bound.');

        $data = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'slug' => ['required', 'string', 'max:100', 'regex:/^[a-z0-9_]+$/'],
            'permissions' => ['nullable', 'array'],
            'permissions.*' => ['string', 'exists:permissions,slug'],
        ]);

        $exists = Role::query()
            ->where('tenant_id', $tenant->id)
            ->where('slug', $data['slug'])
            ->exists();

        if ($exists) {
            return response()->json(['message' => 'Role slug already exists for this tenant.'], 422);
        }

        $role = Role::query()->create([
            'tenant_id' => $tenant->id,
            'name' => $data['name'],
            'slug' => $data['slug'],
            'is_system' => false,
        ]);

        if (! empty($data['permissions'])) {
            $this->roleProvisioning->syncRolePermissions($role, $data['permissions']);
        }

        $role->load('permissions:id,slug,name,group');

        return response()->json(['data' => $this->formatRole($role)], 201);
    }

    public function update(Request $request, Role $role): JsonResponse
    {
        $this->ensureTenantRole($role);

        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:100'],
            'permissions' => ['sometimes', 'array'],
            'permissions.*' => ['string', 'exists:permissions,slug'],
        ]);

        if ($role->is_system && isset($data['name']) && $data['name'] !== $role->name) {
            return response()->json(['message' => 'System role names cannot be modified.'], 403);
        }

        if (! $role->is_system && isset($data['name'])) {
            $role->update(['name' => $data['name']]);
        }

        if (array_key_exists('permissions', $data)) {
            $this->roleProvisioning->syncRolePermissions($role, $data['permissions']);
            $this->clearRoleUsersCache($role);
        }

        $role->load('permissions:id,slug,name,group');

        return response()->json(['data' => $this->formatRole($role)]);
    }

    public function destroy(Role $role): JsonResponse
    {
        $this->ensureTenantRole($role);

        if ($role->is_system) {
            return response()->json(['message' => 'System roles cannot be deleted.'], 403);
        }

        if ($role->users()->exists()) {
            return response()->json(['message' => 'Role is assigned to users and cannot be deleted.'], 422);
        }

        $role->permissions()->detach();
        $role->delete();

        return response()->json(null, 204);
    }

    private function ensureTenantRole(Role $role): void
    {
        $tenant = $this->tenantContext->tenant();
        abort_if($tenant === null, 500, 'Tenant context is not bound.');

        if ($role->tenant_id !== $tenant->id) {
            abort(404);
        }
    }

    /** @return array<string, mixed> */
    private function formatRole(Role $role): array
    {
        return [
            'id' => $role->id,
            'name' => $role->name,
            'slug' => $role->slug,
            'is_system' => $role->is_system,
            'permissions' => $role->permissions->map(fn ($p) => [
                'id' => $p->id,
                'slug' => $p->slug,
                'name' => $p->name,
                'group' => $p->group,
            ])->values(),
        ];
    }

    private function clearRoleUsersCache(Role $role): void
    {
        $role->users()->each(fn ($user) => $this->authorization->forgetCachedPermissions($user));
    }
}
