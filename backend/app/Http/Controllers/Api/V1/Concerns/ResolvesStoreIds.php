<?php

namespace App\Http\Controllers\Api\V1\Concerns;

use App\Models\Store;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

trait ResolvesStoreIds
{
    /**
     * @return list<string>
     */
    protected function resolveStoreIds(Request $request, bool $required = false): array
    {
        $ids = $request->input('store_ids');
        if (! is_array($ids) || $ids === []) {
            $single = $request->query('store_id') ?: $request->input('store_id');
            $ids = $single ? [(string) $single] : [];
        } else {
            $ids = array_values(array_unique(array_filter(array_map('strval', $ids))));
        }

        if ($ids === []) {
            if ($required) {
                throw ValidationException::withMessages([
                    'store_ids' => ['Sélectionnez au moins un magasin.'],
                ]);
            }

            return [];
        }

        $found = Store::query()
            ->whereIn('id', $ids)
            ->pluck('id')
            ->map(fn ($id) => (string) $id)
            ->all();

        if (count($found) !== count($ids)) {
            throw ValidationException::withMessages([
                'store_ids' => ['Un ou plusieurs magasins sont invalides.'],
            ]);
        }

        return $found;
    }

    protected function resolveStoreId(Request $request, bool $required = false): ?string
    {
        $ids = $this->resolveStoreIds($request, $required);

        return $ids[0] ?? null;
    }

    /**
     * @return list<string>
     */
    protected function targetStoreIds(Request $request, ?string $fallbackStoreId): array
    {
        $ids = $this->resolveStoreIds($request, required: false);
        if ($ids !== []) {
            return $ids;
        }

        return $fallbackStoreId ? [(string) $fallbackStoreId] : [];
    }

    /** @param  array<string, mixed>  $data */
    protected function withoutStoreFields(array $data): array
    {
        unset($data['store_id'], $data['store_ids']);

        return $data;
    }
}
