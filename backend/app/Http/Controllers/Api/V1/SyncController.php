<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Currency;
use App\Models\Customer;
use App\Models\Device;
use App\Models\Permission;
use App\Models\Role;
use App\Models\Sale;
use App\Models\Store;
use App\Models\SyncEvent;
use App\Models\SyncFailure;
use App\Models\Tax;
use App\Models\Unit;
use App\Models\User;
use App\Services\Authorization\AuthorizationService;
use App\Services\Catalog\PosCatalogSyncService;
use App\Services\Payments\CompanyPaymentMethodService;
use App\Services\Rbac\PermissionCatalog;
use App\Services\Sales\SaleEngine;
use App\Services\Sync\ConflictResolutionEngine;
use App\Services\Sync\OfflineSyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class SyncController extends Controller
{
    public function __construct(
        private readonly SaleEngine $sales,
        private readonly PosCatalogSyncService $catalog,
        private readonly CompanyPaymentMethodService $paymentMethods,
        private readonly AuthorizationService $authorization,
        private readonly OfflineSyncService $offlineSync,
        private readonly ConflictResolutionEngine $conflicts,
    ) {}

    public function push(Request $request): JsonResponse
    {
        $store = $this->store();
        $data = $request->validate([
            'operations' => ['required', 'array', 'max:50'],
            'operations.*.id' => ['required', 'string', 'max:80'],
            'operations.*.entity_type' => ['required', 'string', 'max:40'],
            'operations.*.entity_id' => ['required', 'string', 'max:80'],
            'operations.*.operation' => ['required', 'string', 'max:40'],
            'operations.*.payload' => ['required', 'array'],
        ]);

        $results = [];
        foreach ($data['operations'] as $operation) {
            $result = $this->applyOperation($store, $operation, $request);
            $this->rememberSyncResult($store, $operation, $result);
            $results[] = $result;
        }

        return response()->json([
            'data' => [
                'results' => $results,
                'server_sequence' => now()->timestamp,
            ],
        ]);
    }

    public function offline(Request $request): JsonResponse
    {
        $store = $this->store();
        $user = $request->user();
        if (! $user instanceof User) {
            abort(401);
        }

        $data = $request->validate([
            'operations' => ['required', 'array', 'max:50'],
            'operations.*.id' => ['required', 'uuid'],
            'operations.*.client_uuid' => ['required', 'uuid'],
            'operations.*.domain' => ['required', 'in:pos,restaurant,hotel,cash_register'],
            'operations.*.entity_type' => ['required', 'string', 'max:40'],
            'operations.*.entity_id' => ['required', 'string', 'max:80'],
            'operations.*.operation' => ['required', 'string', 'max:40'],
            'operations.*.payload' => ['required', 'array'],
            'operations.*.base_version' => ['nullable', 'string', 'max:64'],
        ]);

        $results = [];
        foreach ($data['operations'] as $operation) {
            $result = $this->offlineSync->accept($store, $user, $operation);
            $this->rememberSyncResult($store, $operation, $result);
            $results[] = $result;
        }

        return response()->json([
            'data' => [
                'results' => $results,
                'server_sequence' => now()->timestamp,
            ],
        ]);
    }

    public function resolveOffline(Request $request): JsonResponse
    {
        $store = $this->store();
        $user = $request->user();
        if (! $user instanceof User) {
            abort(401);
        }

        $data = $request->validate([
            'client_uuid' => ['required', 'uuid'],
            'resolution' => ['required', 'in:discard,accept_server,keep_local'],
        ]);

        return response()->json([
            'data' => $this->offlineSync->resolve($store, $user, $data['client_uuid'], $data['resolution']),
        ]);
    }

    public function pull(Request $request): JsonResponse
    {
        $store = $this->store();
        $since = $request->integer('since');

        return response()->json([
            'data' => [
                'store_id' => $store->id,
                'server_sequence' => now()->timestamp,
                'since' => $since,
                'products' => $this->catalog->productsForStore($store),
                'categories' => $this->catalog->categoriesForStore($store),
                'sync_events' => SyncEvent::query()
                    ->where('store_id', $store->id)
                    ->when($since > 0, fn ($query) => $query->where('sequence', '>', $since))
                    ->orderBy('sequence')
                    ->limit(200)
                    ->get()
                    ->map(fn (SyncEvent $event) => $event->toSummaryArray())
                    ->values(),
            ],
        ]);
    }

    /**
     * Reference data for POS offline terminals (payment methods, RBAC, UoM, etc.).
     * Accessible with sales.view so cashiers can refresh without admin permissions.
     */
    public function references(Request $request): JsonResponse
    {
        $store = $this->store()->loadMissing('branch.company');

        foreach (PermissionCatalog::definitions() as $slug => [$name, $group]) {
            Permission::query()->firstOrCreate(
                ['slug' => $slug],
                ['name' => $name, 'group' => $group],
            );
        }

        $company = $store->branch?->company;
        $paymentMethods = $company
            ? $this->paymentMethods
                ->forCompany($company, enabledOnly: true, posOnly: true)
                ->map(fn ($method) => $method->toPosArray())
                ->values()
            : collect();

        $units = Unit::query()
            ->where('store_id', $store->id)
            ->where('is_active', true)
            ->orderBy('name')
            ->get(['id', 'code', 'name', 'symbol', 'is_fractional', 'is_active']);

        if ($units->isEmpty()) {
            app(\App\Services\Catalog\StoreCatalogService::class)->ensureUnits($store);
            $units = Unit::query()
                ->where('store_id', $store->id)
                ->where('is_active', true)
                ->orderBy('name')
                ->get(['id', 'code', 'name', 'symbol', 'is_fractional', 'is_active']);
        }

        $currencies = Currency::query()
            ->where('is_active', true)
            ->orderByDesc('is_default')
            ->orderBy('code')
            ->get(['id', 'code', 'name', 'symbol', 'decimal_places', 'exchange_rate', 'is_default', 'is_active']);

        $taxes = Tax::query()
            ->where('is_active', true)
            ->orderBy('name')
            ->get(['id', 'name', 'code', 'rate', 'is_inclusive', 'is_active']);

        $permissions = Permission::query()
            ->orderBy('group')
            ->orderBy('slug')
            ->get(['id', 'slug', 'name', 'group']);

        $roles = Role::query()
            ->where('tenant_id', $store->tenant_id)
            ->with('permissions:id,slug,name,group')
            ->orderBy('name')
            ->get()
            ->map(fn (Role $role) => [
                'id' => $role->id,
                'name' => $role->name,
                'slug' => $role->slug,
                'is_system' => (bool) $role->is_system,
                'permissions' => $role->permissions->pluck('slug')->values(),
            ])
            ->values();

        $users = User::query()
            ->where('tenant_id', $store->tenant_id)
            ->where('is_active', true)
            ->whereNotNull('pin')
            ->where('pin', '!=', '')
            ->with(['roles.permissions:id,slug', 'stores:id'])
            ->where(function ($query) use ($store): void {
                $query->whereDoesntHave('stores')
                    ->orWhereHas('stores', fn ($stores) => $stores->where('stores.id', $store->id));
            })
            ->orderBy('name')
            ->get()
            ->map(function (User $user) {
                $pin = (string) $user->pin;

                return [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'is_active' => true,
                    'pin_verifier' => hash('sha256', "itara-pos|{$user->id}|{$pin}"),
                    'roles' => $user->roles->pluck('slug')->values(),
                    'permissions' => collect($this->authorization->getPermissions($user))->pluck('slug')->values(),
                    'store_ids' => $user->stores->pluck('id')->values(),
                ];
            })
            ->values();

        return response()->json([
            'data' => [
                'store_id' => $store->id,
                'server_time' => now()->toIso8601String(),
                'payment_methods' => $paymentMethods,
                'units' => $units,
                'currencies' => $currencies,
                'taxes' => $taxes,
                'permissions' => $permissions,
                'roles' => $roles,
                'users' => $users,
                'conflict_resolution' => $this->conflicts->catalog(),
            ],
        ]);
    }

    public function status(Request $request): JsonResponse
    {
        $store = $this->store();

        return response()->json([
            'data' => [
                'store_id' => $store->id,
                'server_sequence' => (int) SyncEvent::query()->where('store_id', $store->id)->max('sequence'),
                'sales' => Sale::query()->where('store_id', $store->id)->count(),
                'server_time' => now()->toIso8601String(),
                'devices' => Device::query()
                    ->where('store_id', $store->id)
                    ->orderBy('name')
                    ->get(['id', 'name', 'code', 'platform', 'device_type', 'status', 'last_sync_at', 'is_active'])
                    ->map(fn (Device $device) => [
                        'id' => $device->id,
                        'name' => $device->name,
                        'code' => $device->code,
                        'platform' => $device->platform,
                        'device_type' => $device->device_type,
                        'status' => $device->status,
                        'is_active' => $device->is_active,
                        'last_sync_at' => $device->last_sync_at?->toIso8601String(),
                    ])
                    ->values(),
                'events' => SyncEvent::query()
                    ->where('store_id', $store->id)
                    ->latest('occurred_at')
                    ->limit(20)
                    ->get()
                    ->map(fn (SyncEvent $event) => [
                        'id' => $event->id,
                        'event_type' => $event->event_type,
                        'entity_type' => $event->entity_type,
                        'entity_id' => $event->entity_id,
                        'occurred_at' => $event->occurred_at?->toIso8601String(),
                    ])
                    ->values(),
            ],
        ]);
    }

    public function ack(Request $request): JsonResponse
    {
        $store = $this->store();
        $data = $request->validate([
            'checkpoint' => ['nullable', 'string', 'max:80'],
            'operations' => ['required_without:checkpoint', 'array', 'max:50'],
            'operations.*.id' => ['required', 'string', 'max:80'],
            'operations.*.entity_type' => ['required', 'string', 'max:40'],
            'operations.*.entity_id' => ['required', 'string', 'max:80'],
            'operations.*.server_id' => ['nullable', 'string', 'max:80'],
        ]);

        $acknowledged = [];
        $missing = [];
        foreach ($data['operations'] ?? [] as $operation) {
            if ($this->operationIsStored($store, $operation)) {
                $acknowledged[] = $operation['id'];
            } else {
                $missing[] = $operation['id'];
            }
        }

        return response()->json([
            'data' => [
                'acknowledged' => $missing === [],
                'acknowledged_ids' => $acknowledged,
                'missing_ids' => $missing,
                'checkpoint' => $data['checkpoint'] ?? null,
            ],
        ]);
    }

    public function heartbeat(Request $request): JsonResponse
    {
        $store = $this->store();
        $data = $request->validate([
            'device_id' => ['nullable', 'string', 'max:80'],
            'identifier' => ['nullable', 'string', 'max:120'],
            'name' => ['nullable', 'string', 'max:120'],
            'app_version' => ['nullable', 'string', 'max:40'],
            'pending' => ['nullable', 'integer', 'min:0'],
        ]);

        $device = null;
        if (! empty($data['device_id'])) {
            $device = Device::query()->whereKey($data['device_id'])->first();
        }
        if ($device === null && ! empty($data['identifier'])) {
            $device = Device::query()->where('identifier', $data['identifier'])->first();
        }

        if ($device !== null) {
            if ((string) $device->store_id !== (string) $store->id) {
                return response()->json(['message' => 'Forbidden device access.'], 403);
            }

            $device->forceFill([
                'last_sync_at' => now(),
                'app_version' => $data['app_version'] ?? $device->app_version,
                'ip_address' => $request->ip(),
            ])->save();
        }

        return response()->json([
            'data' => [
                'status' => 'online',
                'server_time' => now()->toIso8601String(),
                'pending' => $data['pending'] ?? 0,
            ],
        ]);
    }

    /** @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $result
     */
    private function rememberSyncResult(Store $store, array $operation, array $result): void
    {
        $entityType = (string) ($operation['entity_type'] ?? 'sale');
        $entityId = (string) ($operation['entity_id'] ?? '');
        if ($entityId === '') {
            return;
        }

        if (($result['status'] ?? '') === 'synced') {
            SyncFailure::resolve($store->tenant_id, $entityType, $entityId);

            return;
        }

        if (in_array($result['status'] ?? '', ['failed', 'conflict'], true)) {
            SyncFailure::record(
                $store->tenant_id,
                $store->id,
                $entityType,
                $entityId,
                (string) ($result['error'] ?? 'Sync échouée'),
            );
        }
    }

    /** @param  array<string, mixed>  $operation */
    private function applyOperation(Store $store, array $operation, Request $request): array
    {
        $entityId = (string) $operation['entity_id'];
        $entityType = (string) ($operation['entity_type'] ?? 'sale');
        $op = (string) ($operation['operation'] ?? 'create');
        $payload = $operation['payload'];
        $payload['idempotency_key'] = $payload['idempotency_key'] ?? $entityId;

        // Master → Cloud entity matrix (mobile.md §35).
        return match ($entityType) {
            'customer' => $op === 'create'
                ? $this->applyCustomerCreate($store, $operation)
                : $this->unsupported($operation, $entityId),
            'sale' => $op === 'create'
                ? $this->applySaleCreate($store, $operation, $request, $payload, $entityId)
                : $this->unsupported($operation, $entityId),
            'payment' => $this->applyPayment($store, $operation, $payload, $entityId),
            'stock' => $this->applyStock($store, $operation, $payload, $entityId),
            'order' => $this->applyOrder($store, $operation, $payload, $entityId),
            'expense' => $this->applyExpense($store, $operation, $request, $payload, $entityId),
            'audit_log' => $this->applyAuditLog($store, $operation, $request, $payload, $entityId),
            'configuration' => $this->applyConfiguration($store, $operation, $payload, $entityId),
            'product', 'user' => [
                // Products / users are pulled from Cloud, not pushed by Master.
                'id' => $operation['id'],
                'entity_id' => $entityId,
                'status' => 'synced',
                'server_id' => $entityId,
            ],
            default => $this->unsupported($operation, $entityId),
        };
    }

    /**
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function applySaleCreate(Store $store, array $operation, Request $request, array $payload, string $entityId): array
    {
        try {
            $result = ! empty($payload['sale_id'])
                ? $this->sales->completePending($store, $payload, $request->user())
                : $this->sales->create($store, $payload, $request->user());
            $sale = $result->sale;

            return [
                'id' => $operation['id'],
                'entity_id' => $entityId,
                'status' => 'synced',
                'server_id' => $sale->id,
                'reference' => $sale->reference,
            ];
        } catch (ValidationException $exception) {
            $existing = Sale::query()
                ->where('tenant_id', $store->tenant_id)
                ->where('idempotency_key', $payload['idempotency_key'])
                ->first();

            if ($existing !== null) {
                return [
                    'id' => $operation['id'],
                    'entity_id' => $entityId,
                    'status' => 'synced',
                    'server_id' => $existing->id,
                    'reference' => $existing->reference,
                ];
            }

            return [
                'id' => $operation['id'],
                'entity_id' => $entityId,
                'status' => 'failed',
                'error' => collect($exception->errors())->flatten()->first() ?? $exception->getMessage(),
            ];
        } catch (\Throwable $exception) {
            return [
                'id' => $operation['id'],
                'entity_id' => $entityId,
                'status' => 'failed',
                'error' => $exception->getMessage(),
            ];
        }
    }

    /**
     * Payments usually ride inside the sale payload; accept orphan payment ops as synced
     * once the parent sale exists (or keep pending via failed if not).
     *
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function applyPayment(Store $store, array $operation, array $payload, string $entityId): array
    {
        $saleId = (string) ($payload['sale_id'] ?? '');
        if ($saleId !== '') {
            $sale = Sale::query()
                ->where('store_id', $store->id)
                ->where(function ($query) use ($saleId): void {
                    $query->whereKey($saleId)->orWhere('idempotency_key', $saleId);
                })
                ->first();
            if ($sale === null) {
                return [
                    'id' => $operation['id'],
                    'entity_id' => $entityId,
                    'status' => 'failed',
                    'error' => 'Parent sale not synced yet.',
                ];
            }
        }

        SyncEvent::query()->create([
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'event_type' => 'payment.received',
            'entity_type' => 'payment',
            'entity_id' => $entityId,
            'payload' => $payload,
            'occurred_at' => now(),
            'sequence' => now()->timestamp,
        ]);

        return [
            'id' => $operation['id'],
            'entity_id' => $entityId,
            'status' => 'synced',
            'server_id' => $entityId,
        ];
    }

    /**
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function applyStock(Store $store, array $operation, array $payload, string $entityId): array
    {
        SyncEvent::query()->create([
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'event_type' => 'stock.updated',
            'entity_type' => 'stock',
            'entity_id' => $entityId,
            'payload' => $payload,
            'occurred_at' => now(),
            'sequence' => now()->timestamp,
        ]);

        return [
            'id' => $operation['id'],
            'entity_id' => $entityId,
            'status' => 'synced',
            'server_id' => $entityId,
        ];
    }

    /**
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function applyOrder(Store $store, array $operation, array $payload, string $entityId): array
    {
        SyncEvent::query()->create([
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'event_type' => 'order.upserted',
            'entity_type' => 'order',
            'entity_id' => $entityId,
            'payload' => $payload,
            'occurred_at' => now(),
            'sequence' => now()->timestamp,
        ]);

        return [
            'id' => $operation['id'],
            'entity_id' => $entityId,
            'status' => 'synced',
            'server_id' => $entityId,
        ];
    }

    /**
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function applyExpense(Store $store, array $operation, Request $request, array $payload, string $entityId): array
    {
        try {
            $branch = $store->branch;
            if ($branch === null) {
                return [
                    'id' => $operation['id'],
                    'entity_id' => $entityId,
                    'status' => 'failed',
                    'error' => 'Store has no branch for expense sync.',
                ];
            }

            $existing = \App\Models\BranchExpense::query()
                ->where('tenant_id', $store->tenant_id)
                ->where('notes', 'idempotency:'.$entityId)
                ->first();
            if ($existing !== null) {
                return [
                    'id' => $operation['id'],
                    'entity_id' => $entityId,
                    'status' => 'synced',
                    'server_id' => $existing->id,
                    'reference' => $existing->reference,
                ];
            }

            $expense = \App\Models\BranchExpense::query()->create([
                'tenant_id' => $store->tenant_id,
                'branch_id' => $branch->id,
                'store_id' => $store->id,
                'category' => (string) ($payload['category'] ?? 'other'),
                'description' => (string) ($payload['description'] ?? 'Expense'),
                'amount' => (int) ($payload['amount'] ?? 0),
                'currency_code' => strtoupper((string) ($payload['currency_code'] ?? 'FBU')),
                'occurred_on' => $payload['occurred_on'] ?? now()->toDateString(),
                'notes' => 'idempotency:'.$entityId,
                'reference' => app(\App\Services\Numbering\ReferenceNumberGenerator::class)->next(
                    \App\Enums\NumberingDocumentType::Expense,
                    (string) $store->tenant_id,
                    $branch->id,
                ),
            ]);

            return [
                'id' => $operation['id'],
                'entity_id' => $entityId,
                'status' => 'synced',
                'server_id' => $expense->id,
                'reference' => $expense->reference,
            ];
        } catch (\Throwable $exception) {
            return [
                'id' => $operation['id'],
                'entity_id' => $entityId,
                'status' => 'failed',
                'error' => $exception->getMessage(),
            ];
        }
    }

    /**
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function applyAuditLog(Store $store, array $operation, Request $request, array $payload, string $entityId): array
    {
        try {
            \App\Models\AuditLog::query()->create([
                'tenant_id' => $store->tenant_id,
                'user_id' => $payload['actor_id'] ?? $request->user()?->id,
                'action' => (string) ($payload['action'] ?? 'sync.audit'),
                'entity_type' => (string) ($payload['entity_type'] ?? 'sync'),
                'entity_id' => (string) ($payload['entity_id'] ?? $entityId),
                'payload' => $payload['payload'] ?? $payload,
                'ip_address' => $request->ip(),
            ]);

            SyncEvent::query()->create([
                'tenant_id' => $store->tenant_id,
                'store_id' => $store->id,
                'event_type' => 'audit_log.created',
                'entity_type' => 'audit_log',
                'entity_id' => $entityId,
                'payload' => $payload,
                'occurred_at' => now(),
                'sequence' => now()->timestamp,
            ]);

            return [
                'id' => $operation['id'],
                'entity_id' => $entityId,
                'status' => 'synced',
                'server_id' => $entityId,
            ];
        } catch (\Throwable $exception) {
            return [
                'id' => $operation['id'],
                'entity_id' => $entityId,
                'status' => 'failed',
                'error' => $exception->getMessage(),
            ];
        }
    }

    /**
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function applyConfiguration(Store $store, array $operation, array $payload, string $entityId): array
    {
        SyncEvent::query()->create([
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'event_type' => 'configuration.upserted',
            'entity_type' => 'configuration',
            'entity_id' => $entityId,
            'payload' => $payload,
            'occurred_at' => now(),
            'sequence' => now()->timestamp,
        ]);

        return [
            'id' => $operation['id'],
            'entity_id' => $entityId,
            'status' => 'synced',
            'server_id' => $entityId,
        ];
    }

    /**
     * @param  array<string, mixed>  $operation
     * @return array<string, mixed>
     */
    private function unsupported(array $operation, string $entityId): array
    {
        return [
            'id' => $operation['id'],
            'entity_id' => $entityId,
            'status' => 'conflict',
            'error' => 'Unsupported sync operation.',
        ];
    }

    /** @param  array<string, mixed>  $operation */
    private function applyCustomerCreate(Store $store, array $operation): array
    {
        $entityId = (string) $operation['entity_id'];
        $payload = $operation['payload'];
        $name = trim((string) ($payload['name'] ?? ''));

        if ($name === '') {
            return [
                'id' => $operation['id'],
                'entity_id' => $entityId,
                'status' => 'failed',
                'error' => 'Customer name is required.',
            ];
        }

        $existing = Customer::query()
            ->where('tenant_id', $store->tenant_id)
            ->where('metadata->client_id', $entityId)
            ->first();

        if ($existing !== null) {
            return [
                'id' => $operation['id'],
                'entity_id' => $entityId,
                'status' => 'synced',
                'server_id' => $existing->id,
            ];
        }

        $email = trim((string) ($payload['email'] ?? ''));
        $phone = trim((string) ($payload['phone'] ?? ''));

        $customer = Customer::query()->create([
            'tenant_id' => $store->tenant_id,
            'name' => $name,
            'email' => $email !== '' ? $email : null,
            'phone' => $phone !== '' ? $phone : null,
            'payment_terms_days' => 0,
            'is_active' => true,
            'metadata' => ['client_id' => $entityId],
        ]);

        return [
            'id' => $operation['id'],
            'entity_id' => $entityId,
            'status' => 'synced',
            'server_id' => $customer->id,
        ];
    }

    /** @param  array<string, mixed>  $operation */
    private function operationIsStored(Store $store, array $operation): bool
    {
        $entityId = (string) $operation['entity_id'];
        $serverId = isset($operation['server_id']) ? (string) $operation['server_id'] : '';
        $entityType = (string) ($operation['entity_type'] ?? 'sale');

        if ($entityType === 'customer') {
            return Customer::query()
                ->where('tenant_id', $store->tenant_id)
                ->where(function ($query) use ($entityId, $serverId): void {
                    $query->where('metadata->client_id', $entityId);
                    if ($serverId !== '') {
                        $query->orWhere('id', $serverId);
                    }
                })
                ->exists();
        }

        if ($entityType === 'expense') {
            return \App\Models\BranchExpense::query()
                ->where('tenant_id', $store->tenant_id)
                ->where(function ($query) use ($entityId, $serverId): void {
                    $query->where('notes', 'idempotency:'.$entityId);
                    if ($serverId !== '') {
                        $query->orWhere('id', $serverId);
                    }
                })
                ->exists();
        }

        if (in_array($entityType, ['payment', 'stock', 'order', 'audit_log', 'configuration', 'product', 'user'], true)) {
            return SyncEvent::query()
                ->where('store_id', $store->id)
                ->where('entity_type', $entityType)
                ->where('entity_id', $entityId)
                ->exists()
                || $serverId !== '';
        }

        return Sale::query()
            ->where('tenant_id', $store->tenant_id)
            ->where('store_id', $store->id)
            ->where(function ($query) use ($entityId, $serverId): void {
                $query->where('idempotency_key', $entityId);
                if ($serverId !== '') {
                    $query->orWhere('id', $serverId);
                }
            })
            ->exists();
    }

    private function store(): Store
    {
        $store = app()->bound('store') ? app('store') : null;
        if (! $store instanceof Store) {
            abort(400, 'X-Store-ID header is required.');
        }

        return $store;
    }
}
