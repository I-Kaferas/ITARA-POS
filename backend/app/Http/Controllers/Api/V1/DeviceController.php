<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Device;
use App\Models\Store;
use App\Models\Warehouse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class DeviceController extends Controller
{
    public function index(Request $request, Store $store): JsonResponse
    {
        $query = $store->devices()->with('warehouses:id,name,code')->orderByDesc('created_at');

        if ($type = $request->string('device_type')->toString()) {
            $query->where(function ($builder) use ($type) {
                $builder->where('device_type', $type)->orWhere('category', $type);
            });
        }

        return response()->json([
            'data' => $query->get()->map(fn (Device $device) => $this->present($device)),
        ]);
    }

    public function store(Request $request, Store $store): JsonResponse
    {
        $data = $this->validated($request, $store);
        $token = Device::issueSyncToken();

        $device = $store->devices()->create([
            ...$this->attributes($data),
            'tenant_id' => app('tenant.id'),
            'identifier' => $data['identifier'] ?? $token,
            'sync_token' => $token,
            'token_generated_at' => now(),
            'registration_status' => 'pending',
            'is_active' => $data['is_active'] ?? true,
        ]);

        $this->syncWarehouses($device, $store, $data['warehouse_ids'] ?? []);

        return response()->json(['data' => $this->present($device->fresh('warehouses'))], 201);
    }

    public function register(Request $request, Store $store): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'identifier' => ['required', 'string', 'max:100'],
            'device_type' => ['nullable', 'string', Rule::in($this->categories())],
            'category' => ['nullable', 'string', Rule::in($this->categories())],
            'pos_role' => ['required', 'string', 'in:master,slave,standalone'],
            'master_device_id' => ['nullable', 'uuid', 'exists:devices,id'],
            'master_host' => ['nullable', 'string', 'max:255'],
            'platform' => ['nullable', 'string', 'max:50'],
            'app_version' => ['nullable', 'string', 'max:30'],
        ]);

        if ($data['pos_role'] === 'slave' && empty($data['master_device_id']) && empty($data['master_host'])) {
            return response()->json([
                'message' => 'Un terminal esclave doit référencer un master (ID ou adresse).',
            ], 422);
        }

        if ($data['pos_role'] === 'master') {
            $existingMaster = $store->devices()
                ->where('category', 'pos')
                ->where('pos_role', 'master')
                ->where('identifier', '!=', $data['identifier'])
                ->where('is_active', true)
                ->exists();

            if ($existingMaster) {
                return response()->json([
                    'message' => 'Un terminal master actif existe déjà pour ce magasin.',
                ], 422);
            }
        }

        $category = $data['category'] ?? $data['device_type'] ?? 'pos';

        $device = $store->devices()->updateOrCreate(
            [
                'tenant_id' => app('tenant.id'),
                'identifier' => $data['identifier'],
            ],
            [
                'name' => $data['name'],
                'device_type' => $category,
                'category' => $category,
                'pos_role' => $data['pos_role'],
                'master_device_id' => $data['master_device_id'] ?? null,
                'master_host' => $data['master_host'] ?? null,
                'platform' => $data['platform'] ?? null,
                'app_version' => $data['app_version'] ?? null,
                'is_active' => true,
                'registration_status' => 'registered',
                'registered_at' => now(),
                'last_sync_at' => now(),
            ],
        );

        if (! $device->sync_token) {
            $device->forceFill([
                'sync_token' => Device::issueSyncToken(),
                'token_generated_at' => now(),
            ])->save();
        }

        return response()->json(['data' => $this->present($device->fresh(['masterDevice', 'warehouses']))], $device->wasRecentlyCreated ? 201 : 200);
    }

    public function pair(Request $request): JsonResponse
    {
        $data = $request->validate([
            'sync_token' => ['required', 'string', 'max:64'],
            'identifier' => ['nullable', 'string', 'max:100'],
            'platform' => ['nullable', 'string', 'in:android,windows,other'],
            'app_version' => ['nullable', 'string', 'max:30'],
        ]);

        $device = Device::query()
            ->where('sync_token', strtoupper($data['sync_token']))
            ->first();

        if (! $device) {
            $device = Device::query()->where('sync_token', $data['sync_token'])->first();
        }

        if (! $device || ! $device->is_active) {
            return response()->json(['message' => 'Jeton de synchronisation invalide.'], 422);
        }

        if (
            $device->registration_status === 'registered'
            && ! empty($data['identifier'])
            && $device->identifier !== $data['identifier']
            && $device->identifier !== $device->sync_token
        ) {
            return response()->json([
                'message' => 'Ce terminal est déjà lié à une autre application.',
            ], 409);
        }

        $device->forceFill([
            'identifier' => $data['identifier'] ?? $device->identifier,
            'platform' => $data['platform'] ?? $device->platform,
            'app_version' => $data['app_version'] ?? $device->app_version,
            'registration_status' => 'registered',
            'registered_at' => $device->registered_at ?? now(),
            'last_sync_at' => now(),
        ])->save();

        return response()->json(['data' => $this->present($device->fresh('warehouses'))]);
    }

    public function regenerateToken(Device $device): JsonResponse
    {
        $device->forceFill([
            'sync_token' => Device::issueSyncToken(),
            'token_generated_at' => now(),
            'registration_status' => 'pending',
            'registered_at' => null,
        ])->save();

        return response()->json(['data' => $this->present($device->fresh('warehouses'))]);
    }

    public function update(Request $request, Device $device): JsonResponse
    {
        $store = $device->store()->firstOrFail();
        $data = $this->validated($request, $store, updating: true);
        $attributes = $this->attributes($data, $device);

        $device->update(array_intersect_key($attributes, $data + ['device_type' => true, 'category' => true]));

        if (array_key_exists('category', $data)) {
            $device->forceFill(['device_type' => $data['category']])->save();
        }

        if (array_key_exists('warehouse_ids', $data)) {
            $this->syncWarehouses($device, $store, $data['warehouse_ids'] ?? []);
        }

        return response()->json(['data' => $this->present($device->fresh('warehouses'))]);
    }

    public function destroy(Device $device): JsonResponse
    {
        $device->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    /**
     * @return list<string>
     */
    private function categories(): array
    {
        return ['pos', 'printer', 'tablet', 'computer', 'other', 'scanner'];
    }

    /**
     * @return array<string, mixed>
     */
    private function validated(Request $request, Store $store, bool $updating = false): array
    {
        $required = $updating ? 'sometimes' : 'required';

        $ip = trim((string) $request->input('ip_address', ''));
        $request->merge([
            'ip_address' => $ip !== '' ? $ip : null,
            'port' => $request->filled('port') ? $request->input('port') : null,
            'description' => $request->filled('description') ? $request->input('description') : null,
            'warehouse_ids' => array_values(array_filter((array) $request->input('warehouse_ids', []))),
        ]);

        return $request->validate([
            'name' => [$required, 'string', 'max:255'],
            'category' => [$required, 'string', Rule::in(['pos', 'printer', 'tablet', 'computer', 'other'])],
            'device_type' => ['sometimes', 'string', Rule::in($this->categories())],
            'identifier' => ['nullable', 'string', 'max:100'],
            'pos_role' => ['nullable', 'string', 'in:master,slave,standalone'],
            'master_device_id' => ['nullable', 'uuid', 'exists:devices,id'],
            'master_host' => ['nullable', 'string', 'max:255'],
            'platform' => ['nullable', 'string', 'max:50'],
            'app_version' => ['nullable', 'string', 'max:30'],
            'connection_type' => ['nullable', 'string', 'in:network,usb,bluetooth'],
            'ip_address' => ['nullable', 'ip'],
            'port' => ['nullable', 'integer', 'between:1,65535'],
            'description' => ['nullable', 'string', 'max:1000'],
            'is_active' => ['boolean'],
            'warehouse_ids' => ['nullable', 'array'],
            'warehouse_ids.*' => ['uuid'],
        ]);
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private function attributes(array $data, ?Device $device = null): array
    {
        $category = $data['category'] ?? $device?->category ?? 'pos';
        $connection = $data['connection_type'] ?? $device?->connection_type;

        return [
            'name' => $data['name'] ?? $device?->name,
            'category' => $category,
            'device_type' => $category,
            'pos_role' => $data['pos_role'] ?? $device?->pos_role ?? ($category === 'pos' ? 'master' : 'standalone'),
            'master_device_id' => $data['master_device_id'] ?? null,
            'master_host' => $data['master_host'] ?? null,
            'platform' => $data['platform'] ?? $device?->platform,
            'app_version' => $data['app_version'] ?? $device?->app_version,
            'connection_type' => $connection,
            'ip_address' => $connection === 'network' ? ($data['ip_address'] ?? null) : null,
            'port' => $connection === 'network' ? ($data['port'] ?? 9100) : null,
            'description' => $data['description'] ?? null,
            'is_active' => $data['is_active'] ?? $device?->is_active ?? true,
        ];
    }

    /**
     * @param  list<string>  $warehouseIds
     */
    private function syncWarehouses(Device $device, Store $store, array $warehouseIds): void
    {
        $allowed = Warehouse::query()
            ->where('branch_id', $store->branch_id)
            ->whereIn('id', $warehouseIds)
            ->pluck('id')
            ->all();

        $device->warehouses()->sync($allowed);
    }

    /**
     * @return array<string, mixed>
     */
    private function present(Device $device): array
    {
        $device->loadMissing('warehouses:id,name,code');

        return [
            ...$device->toArray(),
            'warehouse_ids' => $device->warehouses->pluck('id')->values(),
        ];
    }
}
