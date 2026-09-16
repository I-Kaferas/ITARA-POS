<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\Currency;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class CurrencyController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Currency::query()->orderByDesc('is_default')->orderBy('code');

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        return response()->json(['data' => $query->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $tenantId = app('tenant.id');

        $data = $request->validate([
            'code' => [
                'required',
                'string',
                'size:3',
                Rule::unique('currencies', 'code')->where(fn ($q) => $q->where('tenant_id', $tenantId)->whereNull('deleted_at')),
            ],
            'name' => ['required', 'string', 'max:100'],
            'symbol' => ['nullable', 'string', 'max:20'],
            'decimal_places' => ['nullable', 'integer', 'min:0', 'max:6'],
            'exchange_rate' => ['nullable', 'numeric', 'min:0'],
            'is_default' => ['boolean'],
            'is_active' => ['boolean'],
        ]);

        $data['code'] = strtoupper($data['code']);

        $currency = DB::transaction(function () use ($data, $tenantId) {
            $isDefault = $data['is_default'] ?? ! Currency::query()->where('is_default', true)->exists();

            if ($isDefault) {
                Currency::query()->where('is_default', true)->update(['is_default' => false]);
            }

            $created = Currency::query()->create([
                ...$data,
                'tenant_id' => $tenantId,
                'symbol' => $data['symbol'] ?? $data['code'],
                'decimal_places' => $data['decimal_places'] ?? ($data['code'] === 'FBU' ? 0 : 2),
                'exchange_rate' => $data['exchange_rate'] ?? 1,
                'is_default' => $isDefault,
                'is_active' => $data['is_active'] ?? true,
            ]);

            if ($isDefault) {
                $this->syncCompanyCurrency($created->code);
            }

            return $created;
        });

        return response()->json(['data' => $currency], 201);
    }

    public function show(Currency $currency): JsonResponse
    {
        return response()->json(['data' => $currency]);
    }

    public function update(Request $request, Currency $currency): JsonResponse
    {
        $tenantId = app('tenant.id');

        $data = $request->validate([
            'code' => [
                'sometimes',
                'string',
                'size:3',
                Rule::unique('currencies', 'code')
                    ->where(fn ($q) => $q->where('tenant_id', $tenantId)->whereNull('deleted_at'))
                    ->ignore($currency->id),
            ],
            'name' => ['sometimes', 'string', 'max:100'],
            'symbol' => ['nullable', 'string', 'max:20'],
            'decimal_places' => ['sometimes', 'integer', 'min:0', 'max:6'],
            'exchange_rate' => ['sometimes', 'numeric', 'min:0'],
            'is_default' => ['boolean'],
            'is_active' => ['boolean'],
        ]);

        if (isset($data['code'])) {
            $data['code'] = strtoupper($data['code']);
        }

        DB::transaction(function () use ($currency, $data) {
            if (($data['is_default'] ?? false) === true) {
                Currency::query()
                    ->where('is_default', true)
                    ->whereKeyNot($currency->id)
                    ->update(['is_default' => false]);
            }

            if (
                array_key_exists('is_default', $data)
                && $data['is_default'] === false
                && $currency->is_default
                && ! Currency::query()->where('is_default', true)->whereKeyNot($currency->id)->exists()
            ) {
                $data['is_default'] = true;
            }

            $currency->update($data);

            $fresh = $currency->fresh();
            if ($fresh?->is_default) {
                $this->syncCompanyCurrency($fresh->code);
            }
        });

        return response()->json(['data' => $currency->fresh()]);
    }

    public function destroy(Currency $currency): JsonResponse
    {
        if ($currency->is_default) {
            return response()->json([
                'message' => 'Cannot delete the default currency.',
            ], 422);
        }

        $currency->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    private function syncCompanyCurrency(string $code): void
    {
        $normalized = strtoupper($code);
        Company::query()->update(['currency_code' => $normalized]);
    }
}
