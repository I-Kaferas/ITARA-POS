<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Api\V1\Concerns\ResolvesStoreIds;
use App\Http\Controllers\Controller;
use App\Models\CatalogAttribute;
use App\Services\Catalog\CatalogAttributeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class CatalogAttributeController extends Controller
{
    use ResolvesStoreIds;

    public function __construct(private CatalogAttributeService $attributes) {}

    public function index(Request $request): JsonResponse
    {
        $storeId = $this->resolveStoreId($request);

        if ($request->boolean('ensure_defaults') && $storeId) {
            $this->attributes->ensureDefaults((string) app('tenant.id'), $storeId);
        }

        $query = CatalogAttribute::query()->orderBy('sort_order')->orderBy('name');

        if ($storeId) {
            $query->where('store_id', $storeId);
        } elseif (! $request->boolean('all_stores')) {
            $query->whereNotNull('store_id');
        }

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        return response()->json(['data' => $query->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $storeIds = $this->resolveStoreIds($request, required: true);
        $data = $this->validated($request);

        $created = DB::transaction(function () use ($storeIds, $data) {
            $code = $this->code($data['code'] ?? null, $data['name']);
            $rows = [];

            foreach ($storeIds as $storeId) {
                $rows[] = CatalogAttribute::query()->firstOrCreate(
                    [
                        'tenant_id' => app('tenant.id'),
                        'store_id' => $storeId,
                        'code' => $code,
                    ],
                    [
                        'name' => $data['name'],
                        'values' => $data['values'],
                        'sort_order' => $data['sort_order'] ?? 0,
                        'is_active' => $data['is_active'] ?? true,
                    ],
                );
            }

            return $rows;
        });

        return response()->json([
            'data' => $created[0],
            'created_count' => count($created),
        ], 201);
    }

    public function update(Request $request, CatalogAttribute $catalogAttribute): JsonResponse
    {
        $storeIds = $this->targetStoreIds($request, $catalogAttribute->store_id);
        $data = $this->withoutStoreFields($this->validated($request, $catalogAttribute, partial: true));
        if (array_key_exists('code', $data) || array_key_exists('name', $data)) {
            $data['code'] = $this->code(
                $data['code'] ?? $catalogAttribute->code,
                $data['name'] ?? $catalogAttribute->name,
            );
        }

        $updated = DB::transaction(function () use ($catalogAttribute, $storeIds, $data) {
            $originalCode = $catalogAttribute->code;
            $newCode = $data['code'] ?? $originalCode;
            $rows = [];

            foreach ($storeIds as $storeId) {
                $query = CatalogAttribute::query()
                    ->where('tenant_id', $catalogAttribute->tenant_id)
                    ->where('store_id', $storeId);

                $target = $storeId === $catalogAttribute->store_id
                    ? $catalogAttribute
                    : ($query->clone()->where('code', $originalCode)->first()
                        ?? $query->clone()->where('code', $newCode)->first());

                if ($target) {
                    $target->update($data);
                    $rows[] = $target->fresh();
                    continue;
                }

                $rows[] = CatalogAttribute::query()->create([
                    'tenant_id' => $catalogAttribute->tenant_id,
                    'store_id' => $storeId,
                    'name' => $data['name'] ?? $catalogAttribute->name,
                    'code' => $newCode,
                    'values' => $data['values'] ?? $catalogAttribute->values,
                    'sort_order' => $data['sort_order'] ?? $catalogAttribute->sort_order,
                    'is_active' => $data['is_active'] ?? $catalogAttribute->is_active,
                ]);
            }

            return $rows;
        });

        return response()->json([
            'data' => $catalogAttribute->fresh(),
            'updated_count' => count($updated),
        ]);
    }

    public function destroy(CatalogAttribute $catalogAttribute): JsonResponse
    {
        $catalogAttribute->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    /** @return array<string, mixed> */
    private function validated(
        Request $request,
        ?CatalogAttribute $existing = null,
        bool $partial = false,
    ): array {
        $required = $partial ? 'sometimes' : 'required';
        $tenantId = (string) app('tenant.id');

        $codeRules = ['nullable', 'string', 'max:50'];
        if ($existing) {
            $codeRules[] = Rule::unique('catalog_attributes', 'code')
                ->where('tenant_id', $tenantId)
                ->where('store_id', $existing->store_id)
                ->ignore($existing->id);
        }

        $data = $request->validate([
            'name' => [$required, 'string', 'max:100'],
            'code' => $codeRules,
            'values' => [$required, 'array', 'min:1'],
            'values.*' => ['required', 'string', 'max:80'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['boolean'],
            'store_id' => ['nullable', 'uuid'],
            'store_ids' => ['nullable', 'array'],
            'store_ids.*' => ['uuid'],
        ]);

        if (isset($data['values'])) {
            $data['values'] = array_values(array_unique(array_filter(array_map(
                fn ($value) => trim((string) $value),
                $data['values'],
            ))));
        }

        return $data;
    }

    private function code(?string $code, string $name): string
    {
        $slug = Str::slug($code ?: $name, '_');

        return $slug !== '' ? $slug : 'attribute';
    }
}
