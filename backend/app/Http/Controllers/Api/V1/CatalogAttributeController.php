<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CatalogAttribute;
use App\Services\Catalog\CatalogAttributeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class CatalogAttributeController extends Controller
{
    public function __construct(private CatalogAttributeService $attributes) {}

    public function index(Request $request): JsonResponse
    {
        if ($request->boolean('ensure_defaults')) {
            $this->attributes->ensureDefaults((string) app('tenant.id'));
        }

        $query = CatalogAttribute::query()->orderBy('sort_order')->orderBy('name');

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        return response()->json(['data' => $query->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);

        $attribute = CatalogAttribute::query()->create([
            ...$data,
            'tenant_id' => app('tenant.id'),
            'code' => $this->code($data['code'] ?? null, $data['name']),
            'values' => $data['values'],
            'sort_order' => $data['sort_order'] ?? 0,
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json(['data' => $attribute], 201);
    }

    public function update(Request $request, CatalogAttribute $catalogAttribute): JsonResponse
    {
        $data = $this->validated($request, $catalogAttribute, partial: true);
        if (array_key_exists('code', $data) || array_key_exists('name', $data)) {
            $data['code'] = $this->code(
                $data['code'] ?? $catalogAttribute->code,
                $data['name'] ?? $catalogAttribute->name,
            );
        }

        $catalogAttribute->update($data);

        return response()->json(['data' => $catalogAttribute->fresh()]);
    }

    public function destroy(CatalogAttribute $catalogAttribute): JsonResponse
    {
        $catalogAttribute->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    /** @return array<string, mixed> */
    private function validated(Request $request, ?CatalogAttribute $existing = null, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';
        $tenantId = (string) app('tenant.id');

        $data = $request->validate([
            'name' => [$required, 'string', 'max:100'],
            'code' => [
                'nullable',
                'string',
                'max:50',
                Rule::unique('catalog_attributes', 'code')
                    ->where('tenant_id', $tenantId)
                    ->ignore($existing?->id),
            ],
            'values' => [$required, 'array', 'min:1'],
            'values.*' => ['required', 'string', 'max:80'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['boolean'],
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
