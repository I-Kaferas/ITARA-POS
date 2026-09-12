<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Permission;
use App\Services\Rbac\PermissionCatalog;
use Illuminate\Http\JsonResponse;

class PermissionController extends Controller
{
    public function index(): JsonResponse
    {
        foreach (PermissionCatalog::definitions() as $slug => [$name, $group]) {
            Permission::query()->firstOrCreate(
                ['slug' => $slug],
                ['name' => $name, 'group' => $group],
            );
        }

        $permissions = Permission::query()
            ->orderBy('group')
            ->orderBy('slug')
            ->get()
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
