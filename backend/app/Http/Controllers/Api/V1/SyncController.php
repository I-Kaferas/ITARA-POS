<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\Device;
use App\Models\Sale;
use App\Models\Store;
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
            $results[] = $this->applyOperation($store, $operation, $request);
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
            ],
        ]);
    }

    public function status(Request $request): JsonResponse
    {
        $store = $this->store();

        return response()->json([
            'data' => [
                'store_id' => $store->id,
                'server_sequence' => now()->timestamp,
                'sales' => Sale::query()->where('store_id', $store->id)->count(),
                'server_time' => now()->toIso8601String(),
            ],
        ]);
    }

    public function ack(Request $request): JsonResponse
    {
        $data = $request->validate([
            'checkpoint' => ['required', 'string', 'max:80'],
        ]);

        return response()->json([
            'data' => [
                'acknowledged' => true,
                'checkpoint' => $data['checkpoint'],
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

    private function store(): Store
    {
        $store = app()->bound('store') ? app('store') : null;
        if (! $store instanceof Store) {
            abort(400, 'X-Store-ID header is required.');
        }

        return $store;
    }
}
