<?php

namespace App\Services\Settings;

use App\Models\Company;
use App\Models\MerchantQrCode;
use App\Models\PosTable;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

class MerchantQrService
{
    /** @var list<string> */
    public const TYPES = [
        'table',
        'pdf_menu',
        'external_link',
        'merchant',
        'payment',
        'company',
    ];

    /** @var list<string> */
    public const WEB_TYPES = [
        'table',
        'pdf_menu',
        'external_link',
    ];

    /**
     * @param  array{label?: string|null, type: string, url?: string|null, table_id?: string|null, amount?: float|int|string|null, currency?: string|null, reference?: string|null, display_name?: string|null}  $input
     */
    public function create(Company $company, array $input, ?UploadedFile $pdf = null): MerchantQrCode
    {
        $type = $input['type'];
        $label = $this->labelFor($company, $type, $input);
        $table = $type === 'table'
            ? $this->tableForCompany($company, (string) ($input['table_id'] ?? ''))
            : null;

        $payload = $this->payload($company, $type, $label, $input, $table);
        $web = in_array($type, self::WEB_TYPES, true);
        $encoded = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        return DB::transaction(function () use ($company, $table, $label, $type, $payload, $web, $encoded, $pdf) {
            $code = MerchantQrCode::query()->create([
                'company_id' => $company->id,
                'store_id' => $table?->store_id,
                'table_id' => $table?->id,
                'label' => $label,
                'type' => $type,
                'scan' => $web ? 'browser' : 'app',
                'service' => $web ? 'web' : 'mobile',
                'payload' => $payload,
                'scan_value' => $web ? $this->webTarget($type, $payload) : (string) $encoded,
            ]);

            if ($type === 'table') {
                $code->scan_value = rtrim((string) config('app.frontend_url'), '/').'/q/'.$code->id;
                $code->save();
            }

            if ($pdf !== null) {
                $this->storePdf($code, $company, $pdf);
            }

            return $code->fresh() ?? $code;
        });
    }

    public function delete(MerchantQrCode $code): void
    {
        $path = is_array($code->payload) ? ($code->payload['storage_path'] ?? null) : null;
        $code->delete();

        if (is_string($path) && $path !== '' && ! str_contains($path, '..')) {
            Storage::disk('public')->delete($path);
        }
    }

    /**
     * @return array<string, mixed>
     */
    public function present(MerchantQrCode $code): array
    {
        return [
            'id' => $code->id,
            'label' => $code->label,
            'type' => $code->type,
            'scan' => $code->scan,
            'service' => $code->service,
            'scan_value' => $code->scan_value,
            'company_public_id' => $code->company_id,
            'table_id' => $code->table_id,
            'payload' => $code->payload,
            'created_at' => $code->created_at?->toIso8601String(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function publicPayload(MerchantQrCode $code): array
    {
        $code->loadMissing(['company', 'table.zone']);
        $url = is_array($code->payload) ? ($code->payload['url'] ?? null) : null;

        return [
            'id' => $code->id,
            'label' => $code->label,
            'type' => $code->type,
            'service' => $code->service,
            'company_name' => $code->company?->name,
            'table' => $code->table ? [
                'name' => $code->table->name,
                'code' => $code->table->code,
                'zone' => $code->table->zone?->name,
                'status' => $code->table->status instanceof \BackedEnum
                    ? $code->table->status->value
                    : $code->table->status,
            ] : null,
            'redirect_url' => is_string($url) ? $url : null,
        ];
    }

    /**
     * @param  array{url?: string|null}  $input
     * @return array<string, mixed>
     */
    private function payload(Company $company, string $type, string $label, array $input, ?PosTable $table): array
    {
        if ($table !== null) {
            $table->loadMissing('zone');

            return [
                'company_public_id' => $company->id,
                'label' => $label,
                'table_id' => $table->id,
                'table_name' => $table->name,
                'table_code' => $table->code,
                'zone' => $table->zone?->name,
            ];
        }

        if (in_array($type, ['pdf_menu', 'external_link'], true)) {
            return [
                'company_public_id' => $company->id,
                'label' => $label,
                'url' => (string) ($input['url'] ?? ''),
            ];
        }

        if ($type === 'payment') {
            $reference = trim((string) ($input['reference'] ?? ''));

            return [
                'v' => 1,
                'kind' => 'payment',
                'company_public_id' => $company->id,
                'company_name' => $company->name,
                'label' => $label,
                'amount' => $this->money($input['amount'] ?? 0),
                'currency' => strtoupper((string) ($input['currency'] ?? 'BIF')),
                'reference' => $reference !== '' ? $reference : null,
            ];
        }

        if ($type === 'merchant') {
            $displayName = trim((string) ($input['display_name'] ?? ''));

            return [
                'v' => 1,
                'kind' => 'merchant',
                'company_public_id' => $company->id,
                'company_name' => $company->name,
                'label' => $label,
                'display_name' => $displayName !== '' ? $displayName : $label,
            ];
        }

        return [
            'v' => 1,
            'kind' => $type,
            'company_public_id' => $company->id,
            'company_name' => $company->name,
            'label' => $label,
        ];
    }

    /**
     * @param  array<string, mixed>  $payload
     */
    private function webTarget(string $type, array $payload): string
    {
        if ($type === 'table') {
            return '';
        }

        return (string) ($payload['url'] ?? '');
    }

    private function storePdf(MerchantQrCode $code, Company $company, UploadedFile $pdf): void
    {
        $directory = $company->tenant_id.'/merchant-qr';
        $stored = Storage::disk('public')->putFileAs($directory, $pdf, $code->id.'.pdf', 'public');

        if ($stored === false) {
            throw ValidationException::withMessages([
                'pdf' => ['The PDF could not be stored.'],
            ]);
        }

        $path = $directory.'/'.$code->id.'.pdf';
        $url = $this->publicFileUrl($path);
        $payload = is_array($code->payload) ? $code->payload : [];
        $payload['url'] = $url;
        $payload['filename'] = $pdf->getClientOriginalName();
        $payload['storage_path'] = $path;
        $code->payload = $payload;
        $code->scan_value = $url;
        $code->save();
    }

    private function publicFileUrl(string $path): string
    {
        $url = Storage::disk('public')->url($path);

        if (str_starts_with($url, 'http://') || str_starts_with($url, 'https://')) {
            return $url;
        }

        return rtrim((string) config('app.url'), '/').'/'.ltrim($url, '/');
    }

    /**
     * @param  array{label?: string|null, amount?: float|int|string|null, currency?: string|null, reference?: string|null, display_name?: string|null}  $input
     */
    private function labelFor(Company $company, string $type, array $input): string
    {
        $label = trim((string) ($input['label'] ?? ''));
        if ($label !== '') {
            return $label;
        }

        if ($type === 'payment') {
            $reference = trim((string) ($input['reference'] ?? ''));
            if ($reference !== '') {
                return $reference;
            }

            return $this->money($input['amount'] ?? 0).' '.strtoupper((string) ($input['currency'] ?? 'BIF'));
        }

        if ($type === 'merchant') {
            $displayName = trim((string) ($input['display_name'] ?? ''));

            return $displayName !== '' ? $displayName : (string) $company->name;
        }

        return $label;
    }

    private function money(mixed $amount): string
    {
        return number_format((float) $amount, 2, '.', '');
    }

    private function tableForCompany(Company $company, string $tableId): PosTable
    {
        $table = PosTable::query()->with(['zone', 'store.branch'])->find($tableId);

        if ($table === null || $table->store?->branch?->company_id !== $company->id) {
            throw ValidationException::withMessages([
                'table_id' => ['Choose a table that belongs to this company.'],
            ]);
        }

        return $table;
    }
}
