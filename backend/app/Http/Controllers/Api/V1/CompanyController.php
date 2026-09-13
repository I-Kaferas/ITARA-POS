<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\Currency;
use App\Models\Tax;
use App\Services\Catalog\ProductImageService;
use App\Services\Organization\BranchEstablishmentService;
use App\Services\Organization\CompanyTaxDefaults;
use App\Services\Payments\CompanyPaymentMethodService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class CompanyController extends Controller
{
    public function __construct(
        private readonly CompanyPaymentMethodService $paymentMethods,
        private readonly ProductImageService $images,
        private readonly CompanyTaxDefaults $taxDefaults,
        private readonly BranchEstablishmentService $establishments,
    ) {}

    public function index(): JsonResponse
    {
        $companies = Company::query()->orderByDesc('created_at')->get()
            ->map(fn (Company $company) => $this->profile($company));

        return response()->json(['data' => $companies]);
    }

    public function current(): JsonResponse
    {
        $this->taxDefaults->ensure((string) app('tenant.id'));

        $company = Company::query()->where('is_active', true)->oldest()->first()
            ?? Company::query()->oldest()->first();

        if ($company === null) {
            return response()->json(['message' => 'Aucune entreprise pour ce tenant.'], 404);
        }

        return response()->json(['data' => $this->profile($company)]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->withLocaleTimezone($this->validated($request));

        $company = Company::create([
            ...$data,
            'tenant_id' => app('tenant.id'),
            'currency_code' => strtoupper($data['currency_code'] ?? $this->defaultCurrencyCode()),
            'is_active' => $data['is_active'] ?? true,
        ]);

        $this->syncDefaultCurrency($company->currency_code);
        $this->paymentMethods->ensureDefaults($company);
        $this->taxDefaults->ensure((string) $company->tenant_id);
        $this->establishments->ensure($company);

        return response()->json(['data' => $this->profile($company)], 201);
    }

    public function show(Company $company): JsonResponse
    {
        return response()->json(['data' => $this->profile($company->load(['branches.stores', 'catalogs']))]);
    }

    public function update(Request $request, Company $company): JsonResponse
    {
        $data = $this->withLocaleTimezone($this->validated($request, updating: true), $company);

        if (isset($data['currency_code'])) {
            $data['currency_code'] = strtoupper($data['currency_code']);
        }

        if (isset($data['settings']) && is_array($data['settings'])) {
            $data['settings'] = array_merge($company->settings ?? [], $data['settings']);
        }

        $company->update($data);

        if (isset($data['currency_code'])) {
            $this->syncDefaultCurrency($data['currency_code']);
        }

        return response()->json(['data' => $this->profile($company->fresh())]);
    }

    public function uploadLogo(Request $request, Company $company): JsonResponse
    {
        $request->validate([
            'logo' => ['required', 'file', 'image', 'mimes:jpeg,jpg,png,webp,gif', 'max:2048'],
        ]);

        $file = $request->file('logo');
        if ($file === null) {
            return response()->json(['message' => 'Logo manquant.'], 422);
        }

        $extension = $file->guessExtension() ?: 'png';
        $path = $company->tenant_id.'/companies/'.$company->id.'/logo.'.$extension;
        $disk = $this->images->mediaDisk();

        $this->deleteStoredLogo($company);

        if (! Storage::disk($disk)->put($path, $file->getContent(), 'public')) {
            return response()->json(['message' => 'Impossible d’enregistrer le logo.'], 500);
        }

        $settings = $company->settings ?? [];
        $settings['logo_storage_path'] = $path;
        $company->update([
            'logo_url' => $this->images->buildCdnUrl($path),
            'settings' => $settings,
        ]);

        return response()->json(['data' => $this->profile($company->fresh())]);
    }

    public function deleteLogo(Company $company): JsonResponse
    {
        $this->deleteStoredLogo($company);

        $settings = $company->settings ?? [];
        unset($settings['logo_storage_path']);
        $company->update([
            'logo_url' => null,
            'settings' => $settings,
        ]);

        return response()->json(['data' => $this->profile($company->fresh())]);
    }

    public function destroy(Company $company): JsonResponse
    {
        $company->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    /** @return array<string, mixed> */
    private function validated(Request $request, bool $updating = false): array
    {
        $required = $updating ? 'sometimes' : 'required';

        return $request->validate([
            'name' => [$required, 'string', 'max:255'],
            'trade_name' => ['nullable', 'string', 'max:255'],
            'legal_name' => ['nullable', 'string', 'max:255'],
            'legal_form' => ['nullable', 'string', 'max:50'],
            'tax_id' => ['nullable', 'string', 'max:100'],
            'registration_number' => ['nullable', 'string', 'max:100'],
            'phone' => ['nullable', 'string', 'max:50'],
            'email' => ['nullable', 'email', 'max:255'],
            'website' => ['nullable', 'string', 'max:255'],
            'logo_url' => ['nullable', 'string', 'max:500'],
            'currency_code' => [$updating ? 'sometimes' : 'nullable', 'string', 'size:3'],
            'locale' => ['nullable', 'string', 'max:20'],
            'timezone' => ['nullable', 'string', 'max:64'],
            'address' => ['nullable', 'array'],
            'address.street' => ['nullable', 'string', 'max:255'],
            'address.number' => ['nullable', 'string', 'max:50'],
            'address.avenue' => ['nullable', 'string', 'max:255'],
            'address.quarter' => ['nullable', 'string', 'max:255'],
            'address.commune' => ['nullable', 'string', 'max:100'],
            'address.city' => ['nullable', 'string', 'max:100'],
            'address.province' => ['nullable', 'string', 'max:100'],
            'address.state' => ['nullable', 'string', 'max:100'],
            'address.postal_code' => ['nullable', 'string', 'max:20'],
            'address.country' => ['nullable', 'string', 'max:100'],
            'settings' => ['nullable', 'array'],
            'settings.timezone' => ['nullable', 'string', 'max:64'],
            'settings.locale' => ['nullable', 'string', 'max:20'],
            'settings.receipt_footer' => ['nullable', 'string', 'max:2000'],
            'settings.legal_mentions' => ['nullable', 'string', 'max:2000'],
            'settings.vat_registered' => ['boolean'],
            'settings.company_type' => ['nullable', 'string', 'max:50'],
            'settings.moral_person' => ['nullable', 'string', 'max:255'],
            'settings.subject_to_tc' => ['boolean'],
            'settings.subject_to_pf' => ['boolean'],
            'settings.fiscal_center' => ['nullable', 'string', 'max:100'],
            'settings.dpmc' => ['nullable', 'string', 'max:100'],
            'settings.activity_sector' => ['nullable', 'string', 'max:255'],
            'settings.vat_status' => ['nullable', 'string', 'max:50'],
            'is_active' => ['boolean'],
        ]);
    }

    private function deleteStoredLogo(Company $company): void
    {
        $path = is_array($company->settings) ? ($company->settings['logo_storage_path'] ?? null) : null;
        if (! is_string($path) || $path === '') {
            return;
        }

        Storage::disk($this->images->mediaDisk())->delete($path);
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private function withLocaleTimezone(array $data, ?Company $company = null): array
    {
        $settings = array_merge($company->settings ?? [], is_array($data['settings'] ?? null) ? $data['settings'] : []);
        $locale = $data['locale'] ?? $settings['locale'] ?? $company?->locale ?? 'fr';
        $timezone = $data['timezone'] ?? $settings['timezone'] ?? $company?->timezone ?? 'Africa/Bujumbura';
        $settings['locale'] = $locale;
        $settings['timezone'] = $timezone;
        $data['locale'] = $locale;
        $data['timezone'] = $timezone;
        $data['settings'] = $settings;

        return $data;
    }

    /** @return array<string, mixed> */
    private function profile(Company $company): array
    {
        $data = $company->toArray();
        $settings = is_array($company->settings) ? $company->settings : [];
        $data['locale'] = $company->locale ?: ($settings['locale'] ?? 'fr');
        $data['timezone'] = $company->timezone ?: ($settings['timezone'] ?? 'Africa/Bujumbura');
        $data['taxes'] = Tax::query()
            ->orderBy('name')
            ->get()
            ->map(fn (Tax $tax) => [
                'id' => $tax->id,
                'name' => $tax->name,
                'code' => $tax->code,
                'rate' => (float) $tax->rate,
                'is_inclusive' => $tax->is_inclusive,
                'is_active' => $tax->is_active,
            ])
            ->values()
            ->all();

        return $data;
    }

    private function defaultCurrencyCode(): string
    {
        $default = Currency::query()
            ->where('is_default', true)
            ->where('is_active', true)
            ->value('code');

        return $default ?: 'FBU';
    }

    private function syncDefaultCurrency(string $code): void
    {
        Currency::query()->where('is_default', true)->update(['is_default' => false]);

        $currency = Currency::query()->where('code', strtoupper($code))->first();
        if ($currency) {
            $currency->update(['is_default' => true, 'is_active' => true]);
        }
    }
}
