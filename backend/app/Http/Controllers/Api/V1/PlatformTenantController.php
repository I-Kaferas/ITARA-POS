<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Authorization\AuthorizationService;
use App\Services\Organization\TenantProvisioningService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PlatformTenantController extends Controller
{
    public function __construct(
        private readonly TenantProvisioningService $provisioning,
        private readonly AuthorizationService $authorization,
    ) {}

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_unless($user instanceof User && $this->authorization->isSuperAdmin($user), 403);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:100'],
            'currency_code' => ['nullable', 'string', 'size:3'],
            'locale' => ['nullable', 'string', 'max:20'],
            'timezone' => ['nullable', 'string', 'max:64'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
        ]);

        $created = $this->provisioning->provision($data);

        return response()->json([
            'data' => [
                'tenant' => [
                    'id' => $created['tenant']->id,
                    'name' => $created['tenant']->name,
                    'slug' => $created['tenant']->slug,
                    'status' => $created['tenant']->status,
                ],
                'company' => [
                    'id' => $created['company']->id,
                    'name' => $created['company']->name,
                    'currency_code' => $created['company']->currency_code,
                    'locale' => $created['company']->locale,
                    'timezone' => $created['company']->timezone,
                ],
            ],
        ], 201);
    }
}
