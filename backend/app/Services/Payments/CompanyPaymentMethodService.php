<?php

namespace App\Services\Payments;

use App\Enums\SalePaymentMethod;
use App\Models\Company;
use App\Models\CompanyPaymentMethod;
use App\Models\Store;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

class CompanyPaymentMethodService
{
    /** Methods enabled for the company by default (API + backoffice). */
    private const DEFAULT_ENABLED = [
        'cash',
        'card',
        'bank_transfer',
        'mobile_money',
        'wallet',
        'credit',
    ];

    /** Methods shown on the POS cash register by default. */
    private const DEFAULT_POS = ['cash', 'card', 'mobile_money'];

    public function ensureDefaults(Company $company): Collection
    {
        $existing = CompanyPaymentMethod::query()
            ->where('company_id', $company->id)
            ->get()
            ->keyBy('code');

        if ($existing->isNotEmpty()) {
            return $existing->values()->sortBy('sort_order')->values();
        }

        $sort = 0;
        foreach (SalePaymentMethod::cases() as $method) {
            $code = $method->value;
            if ($existing->has($code)) {
                continue;
            }

            $cfg = config("payments.methods.{$code}", []);
            $row = CompanyPaymentMethod::query()->create([
                'tenant_id' => $company->tenant_id,
                'company_id' => $company->id,
                'code' => $code,
                'label' => $cfg['label'] ?? $method->label(),
                'label_fr' => $cfg['label_fr'] ?? ($cfg['label'] ?? $code),
                'is_enabled' => in_array($code, self::DEFAULT_ENABLED, true),
                'available_on_pos' => in_array($code, self::DEFAULT_POS, true),
                'sort_order' => $sort,
                'config' => null,
            ]);
            $existing->put($code, $row);
            $sort += 10;
        }

        return $existing->values()->sortBy('sort_order')->values();
    }

    public function forCompany(Company $company, bool $enabledOnly = false, bool $posOnly = false): Collection
    {
        $this->ensureDefaults($company);

        $query = CompanyPaymentMethod::query()
            ->where('company_id', $company->id)
            ->orderBy('sort_order')
            ->orderBy('code');

        if ($enabledOnly) {
            $query->where('is_enabled', true);
        }

        if ($posOnly) {
            $query->where('available_on_pos', true)->where('is_enabled', true);
        }

        return $query->get();
    }

    public function forStore(Store $store, bool $posOnly = true): Collection
    {
        $store->loadMissing('branch.company');
        $company = $store->branch?->company;

        if (! $company) {
            return collect();
        }

        return $this->forCompany($company, enabledOnly: true, posOnly: $posOnly);
    }

    /** @return list<string> */
    public function enabledCodesForStore(Store $store): array
    {
        return $this->forStore($store, posOnly: false)
            ->pluck('code')
            ->map(fn ($c) => (string) $c)
            ->all();
    }

    public function isEnabledForStore(Store $store, string $code): bool
    {
        return in_array($code, $this->enabledCodesForStore($store), true);
    }

    /**
     * Map a company payment-method code to an engine method the sale pipeline can settle.
     */
    public function engineCodeForStore(Store $store, string $code): ?string
    {
        $store->loadMissing('branch.company');
        $company = $store->branch?->company;
        $row = $company
            ? CompanyPaymentMethod::query()
                ->where('company_id', $company->id)
                ->where('code', $code)
                ->first()
            : null;

        if ($row) {
            if (! $row->is_enabled) {
                return null;
            }

            $settle = $row->config['settle_as'] ?? null;
            if (is_string($settle) && SalePaymentMethod::tryFrom($settle)) {
                return $settle;
            }

            if (SalePaymentMethod::tryFrom($row->code)) {
                return $row->code;
            }

            return SalePaymentMethod::Cash->value;
        }

        return SalePaymentMethod::tryFrom($code)?->value;
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    public function normalizePaymentPayload(Store $store, array $payload): array
    {
        if (! isset($payload['payments']) || ! is_array($payload['payments'])) {
            return $payload;
        }

        foreach ($payload['payments'] as $index => $payment) {
            if (! is_array($payment) || ! isset($payment['method'])) {
                continue;
            }

            $code = (string) $payment['method'];
            $engine = $this->engineCodeForStore($store, $code);
            if ($engine === null) {
                throw ValidationException::withMessages([
                    "payments.{$index}.method" => ["Mode de paiement inconnu ou désactivé : {$code}."],
                ]);
            }

            $metadata = is_array($payment['metadata'] ?? null) ? $payment['metadata'] : [];
            if ($engine !== $code) {
                $metadata['method_code'] = $code;
            }
            $payment['method'] = $engine;
            $payment['metadata'] = $metadata;
            $payload['payments'][$index] = $payment;
        }

        return $payload;
    }
}
