<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Permission;
use App\Modules\ModuleManager;
use App\Modules\ModuleRegistry;
use App\Services\Rbac\PermissionCatalog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PermissionController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        foreach (PermissionCatalog::definitions() as $slug => [$name, $group]) {
            Permission::query()->firstOrCreate(
                ['slug' => $slug],
                ['name' => $name, 'group' => $group],
            );
        }

        $enabled = app(ModuleManager::class)->enabledCodes($request->user()?->tenant);

        $permissions = Permission::query()
            ->orderBy('group')
            ->orderBy('slug')
            ->get()
            ->filter(function (Permission $permission) use ($enabled) {
                $owners = ModuleRegistry::modulesForPermission($permission->slug);
                if ($owners === []) {
                    return true;
                }

                return array_intersect($owners, $enabled) !== [];
            })
            ->groupBy('group')
            ->map(fn ($items, $group) => [
                'group' => $group,
                'permissions' => $items->map(fn (Permission $p) => [
                    'id' => $p->id,
                    'slug' => $p->slug,
                    'name' => $p->name,
                ])->values(),
            ])
            ->values();

        return response()->json(['data' => $permissions]);
    }
}
