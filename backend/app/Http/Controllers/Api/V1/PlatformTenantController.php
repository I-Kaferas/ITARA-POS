<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Authorization\AuthorizationService;
use App\Services\Organization\TenantProvisioningService;
use App\Services\Platform\PlatformAuditLogger;
use App\Services\Platform\SaasCatalog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PlatformTenantController extends Controller
{
    public function __construct(
        private readonly TenantProvisioningService $provisioning,
        private readonly AuthorizationService $authorization,
        private readonly PlatformAuditLogger $audit,
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
            'legal_name' => ['nullable', 'string', 'max:255'],
            'trade_name' => ['nullable', 'string', 'max:255'],
            'logo_url' => ['nullable', 'string', 'max:2048'],
            'address' => ['nullable', 'array'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'website' => ['nullable', 'string', 'max:255'],
            'country_code' => ['nullable', 'string', 'size:2'],
            'tax_regime' => ['nullable', 'string', 'max:80'],
            'tax_id' => ['nullable', 'string', 'max:100'],
            'registration_number' => ['nullable', 'string', 'max:100'],
            'status' => ['nullable', Rule::in(SaasCatalog::LIFECYCLE)],
            'plan' => ['nullable', Rule::in(array_values(array_unique(array_merge(array_keys(SaasCatalog::PLANS), array_keys(SaasCatalog::COMMERCIAL_RANK)))))],
            'admin_name' => ['nullable', 'string', 'max:255'],
            'admin_email' => ['nullable', 'email', 'max:255', 'unique:users,email', 'required_with:admin_password'],
            'admin_password' => ['nullable', 'string', 'min:8', 'required_with:admin_email'],
        ]);

        $created = $this->provisioning->provision($data);
        $company = $created['company'];
        $admin = $created['admin'];

        if (! ($created['idempotent'] ?? false)) {
            $this->audit->record($user, 'tenant.provisioned', $created['tenant']->id, [
                'name' => $created['tenant']->name,
                'slug' => $created['tenant']->slug,
                'status' => $created['tenant']->status,
                'plan' => $data['plan'] ?? 'pos_stock',
                'admin_email' => $admin?->email,
            ], $request->ip());
        }

        return response()->json([
            'data' => [
                'tenant' => [
                    'id' => $created['tenant']->id,
                    'name' => $created['tenant']->name,
                    'slug' => $created['tenant']->slug,
                    'status' => $created['tenant']->status,
                ],
                'company' => $company ? [
                    'id' => $company->id,
                    'name' => $company->name,
                    'currency_code' => $company->currency_code,
                    'locale' => $company->locale,
                    'timezone' => $company->timezone,
                ] : null,
                'admin' => $admin ? [
                    'id' => $admin->id,
                    'name' => $admin->name,
                    'email' => $admin->email,
                ] : null,
                'idempotent' => (bool) ($created['idempotent'] ?? false),
            ],
        ], ($created['idempotent'] ?? false) ? 200 : 201);
    }
}
