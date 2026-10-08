<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\Currency;
use App\Models\Tenant;
use App\Services\Catalog\CurrencyConverter;
use App\Services\Catalog\ExchangeRateService;
use App\Tenancy\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class CurrencyController extends Controller
{
    public function __construct(
        private readonly ExchangeRateService $rates,
        private readonly CurrencyConverter $converter,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $query = Currency::query()->orderByDesc('is_default')->orderBy('code');

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        $currencies = $query->get()->map(function (Currency $currency) {
            return [
                ...$currency->toArray(),
                'role' => $currency->is_default ? 'primary' : 'secondary',
            ];
        });

        return response()->json([
            'data' => $currencies,
            'meta' => [
                'primary' => $this->converter->defaultCode(),
            ],
        ]);
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
            'exchange_rate' => ['nullable', 'numeric', 'min:0.00000001'],
            'is_default' => ['boolean'],
            'is_active' => ['boolean'],
            'note' => ['nullable', 'string', 'max:255'],
        ]);

        $data['code'] = strtoupper($data['code']);

        $currency = DB::transaction(function () use ($data, $tenantId, $request) {
            $isDefault = $data['is_default'] ?? ! Currency::query()->where('is_default', true)->exists();
            $rate = $isDefault ? 1.0 : (float) ($data['exchange_rate'] ?? 1);

            if ($isDefault) {
                Currency::query()->where('is_default', true)->update(['is_default' => false]);
            }

            $created = Currency::query()->create([
                'tenant_id' => $tenantId,
                'code' => $data['code'],
                'name' => $data['name'],
                'symbol' => $data['symbol'] ?? $data['code'],
                'decimal_places' => $data['decimal_places'] ?? ($data['code'] === 'FBU' ? 0 : 2),
                'exchange_rate' => $rate,
                'is_default' => $isDefault,
                'is_active' => $data['is_active'] ?? true,
            ]);

            $this->rates->record(
                currency: $created,
                rate: $rate,
                previousRate: null,
                user: $request->user(),
                note: $data['note'] ?? 'Initial rate',
                source: 'manual',
            );

            if ($isDefault) {
                $this->syncCompanyCurrency($created->code);
            }

            return $created;
        });

        return response()->json(['data' => $this->present($currency)], 201);
    }

    public function show(Currency $currency): JsonResponse
    {
        return response()->json(['data' => $this->present($currency)]);
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
            'exchange_rate' => ['sometimes', 'numeric', 'min:0.00000001'],
            'is_default' => ['boolean'],
            'is_active' => ['boolean'],
            'note' => ['nullable', 'string', 'max:255'],
        ]);

        if (isset($data['code'])) {
            $data['code'] = strtoupper($data['code']);
        }

        DB::transaction(function () use ($currency, $data, $request) {
            if (($data['is_default'] ?? false) === true) {
                Currency::query()
                    ->where('is_default', true)
                    ->whereKeyNot($currency->id)
                    ->update(['is_default' => false]);
                $data['exchange_rate'] = 1;
            }

            if (
                array_key_exists('is_default', $data)
                && $data['is_default'] === false
                && $currency->is_default
                && ! Currency::query()->where('is_default', true)->whereKeyNot($currency->id)->exists()
            ) {
                $data['is_default'] = true;
                $data['exchange_rate'] = 1;
            }

            $rateChanging = array_key_exists('exchange_rate', $data)
                && abs((float) $data['exchange_rate'] - (float) $currency->exchange_rate) > 0.00000001;

            if ($rateChanging) {
                $this->rates->setRate(
                    currency: $currency,
                    rate: (float) $data['exchange_rate'],
                    user: $request->user(),
                    note: $data['note'] ?? null,
                );
                unset($data['exchange_rate']);
            }

            unset($data['note']);

            if ($data !== []) {
                $currency->update($data);
            }

            $fresh = $currency->fresh();
            if ($fresh?->is_default) {
                if ((float) $fresh->exchange_rate !== 1.0) {
                    $fresh->update(['exchange_rate' => 1]);
                }
                $this->syncCompanyCurrency($fresh->code);
            }
        });

        return response()->json(['data' => $this->present($currency->fresh())]);
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

    public function rates(Request $request, Currency $currency): JsonResponse
    {
        $limit = min(200, max(1, (int) $request->integer('limit', 50)));

        return response()->json([
            'data' => $this->rates->historyFor($currency, $limit),
            'meta' => [
                'currency' => $currency->code,
                'current_rate' => (float) $currency->exchange_rate,
                'base_currency' => $this->converter->defaultCode(),
            ],
        ]);
    }

    public function storeRate(Request $request, Currency $currency): JsonResponse
    {
        $data = $request->validate([
            'rate' => ['required', 'numeric', 'min:0.00000001'],
            'note' => ['nullable', 'string', 'max:255'],
            'effective_at' => ['nullable', 'date'],
        ]);

        $result = $this->rates->setRate(
            currency: $currency,
            rate: (float) $data['rate'],
            user: $request->user(),
            note: $data['note'] ?? null,
            effectiveAt: isset($data['effective_at']) ? \Carbon\Carbon::parse($data['effective_at']) : null,
        );

        return response()->json([
            'data' => [
                'currency' => $this->present($result['currency']),
                'history' => $result['history'],
            ],
        ], 201);
    }

    public function convert(Request $request): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'integer'],
            'from' => ['required', 'string', 'size:3'],
            'to' => ['required', 'string', 'size:3'],
            'at' => ['nullable', 'date'],
        ]);

        $from = $this->converter->assertActive($data['from']);
        $to = $this->converter->assertActive($data['to']);
        $at = isset($data['at']) ? \Carbon\Carbon::parse($data['at']) : null;

        $converted = $this->converter->convert((int) $data['amount'], $from, $to, $at);

        return response()->json([
            'data' => [
                'amount' => (int) $data['amount'],
                'from' => $from,
                'to' => $to,
                'converted' => $converted,
                'rate' => $this->converter->crossRate($from, $to, $at),
                'at' => $at?->toIso8601String(),
            ],
        ]);
    }

    /** @return array<string, mixed> */
    private function present(Currency $currency): array
    {
        return [
            ...$currency->toArray(),
            'role' => $currency->is_default ? 'primary' : 'secondary',
        ];
    }

    private function syncCompanyCurrency(string $code): void
    {
        $normalized = strtoupper($code);
        Company::query()->update(['currency_code' => $normalized]);

        /** @var TenantContext $context */
        $context = app(TenantContext::class);
        if ($context->isBound()) {
            Tenant::query()
                ->whereKey($context->id())
                ->update(['currency_code' => $normalized]);
        }
    }
}
