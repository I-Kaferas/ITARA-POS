<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Modules\ModuleManager;
use App\Tenancy\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ModuleController extends Controller
{
    public function __construct(
        private readonly ModuleManager $modules,
        private readonly TenantContext $tenants,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = $request->user()?->tenant;

        return response()->json([
            'data' => $this->modules->manifest($tenant),
            'catalog' => $this->modules->catalog($tenant),
        ]);
    }

    public function update(Request $request, string $code): JsonResponse
    {
        $data = $request->validate([
            'enabled' => ['required', 'boolean'],
        ]);

        $tenant = $this->tenants->tenant() ?? $request->user()?->tenant;
        abort_if($tenant === null, 403, 'Module disabled.');

        $enabled = $this->modules->setEnabled($tenant, $code, (bool) $data['enabled']);

        return response()->json([
            'data' => [
                'modules' => $enabled,
                'catalog' => $this->modules->catalog($tenant->fresh()),
            ],
        ]);
    }

    public function updateSettings(Request $request, string $code): JsonResponse
    {
        $tenant = $this->tenants->tenant() ?? $request->user()?->tenant;
        abort_if($tenant === null, 403, 'Module disabled.');

        $values = $this->modules->updateSettings($tenant, $code, $request->all());

        return response()->json([
            'data' => [
                'code' => $code,
                'settings' => $values,
            ],
        ]);
    }
}
