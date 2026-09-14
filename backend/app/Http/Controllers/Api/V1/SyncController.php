<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\Device;
use App\Models\Sale;
use App\Models\Store;
use App\Models\SyncEvent;
use App\Models\SyncFailure;
use App\Services\Catalog\PosCatalogSyncService;
use App\Services\Sales\SaleEngine;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class SyncController extends Controller
{
    public function __construct(
        private readonly SaleEngine $sales,
        private readonly PosCatalogSyncService $catalog,
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
        $payload = $operation['payload'];
        $payload['idempotency_key'] = $payload['idempotency_key'] ?? $entityId;

        if (($operation['entity_type'] ?? '') === 'customer' && ($operation['operation'] ?? '') === 'create') {
            return $this->applyCustomerCreate($store, $operation);
        }

        if (($operation['entity_type'] ?? '') !== 'sale' || ($operation['operation'] ?? '') !== 'create') {
            return [
                'id' => $operation['id'],
                'entity_id' => $entityId,
                'status' => 'conflict',
                'error' => 'Unsupported sync operation.',
            ];
        }

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

        if (($operation['entity_type'] ?? '') === 'customer') {
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
