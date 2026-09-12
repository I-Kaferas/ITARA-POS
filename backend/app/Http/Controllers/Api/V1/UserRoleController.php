<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Role;
use App\Models\User;
use App\Services\Authorization\AuthorizationService;
use App\Tenancy\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class UserRoleController extends Controller
{
    public function __construct(
        private TenantContext $tenantContext,
        private AuthorizationService $authorization,
    ) {}

    public function index(User $user): JsonResponse
    {
        $this->ensureTenantUser($user);
        $user->load('roles.permissions');

        return response()->json([
            'data' => [
                'user_id' => $user->id,
                'roles' => $this->authorization->getRoleAssignments($user),
                'permissions' => collect($this->authorization->getPermissions($user))
                    ->pluck('slug')
                    ->values(),
            ],
        ]);
    }

    public function store(Request $request, User $user): JsonResponse
    {
        $this->ensureTenantUser($user);

        $data = $request->validate([
            'role_id' => ['required', 'uuid', 'exists:roles,id'],
            'branch_id' => ['nullable', 'uuid', 'exists:branches,id'],
            'store_id' => ['nullable', 'uuid', 'exists:stores,id'],
        ]);

        $role = Role::query()->findOrFail($data['role_id']);
        $tenant = $this->tenantContext->tenant();
        abort_if($tenant === null, 500, 'Tenant context is not bound.');

        if ($role->tenant_id !== $tenant->id) {
            return response()->json(['message' => 'Role does not belong to this tenant.'], 422);
        }

        $user->roles()->syncWithoutDetaching([
            $role->id => [
                'branch_id' => $data['branch_id'] ?? null,
                'store_id' => $data['store_id'] ?? null,
            ],
        ]);

        $user->clearPermissionCache();

        return response()->json([
            'data' => $this->authorization->getRoleAssignments($user->fresh('roles')),
        ], 201);
    }

    public function destroy(User $user, Role $role): JsonResponse
    {
        $this->ensureTenantUser($user);
        $tenant = $this->tenantContext->tenant();
        abort_if($tenant === null, 500, 'Tenant context is not bound.');

        if ($role->tenant_id !== $tenant->id) {
            abort(404);
        }

        $user->roles()->detach($role->id);
        $user->clearPermissionCache();

        return response()->json(null, 204);
    }

    private function ensureTenantUser(User $user): void
    {
        $tenant = $this->tenantContext->tenant();
        abort_if($tenant === null, 500, 'Tenant context is not bound.');

        if ($user->tenant_id !== $tenant->id) {
            abort(404);
        }
    }
}
