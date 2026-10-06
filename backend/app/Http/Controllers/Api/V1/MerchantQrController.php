<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\MerchantQrCode;
use App\Models\PosTable;
use App\Services\Settings\MerchantQrService;
use App\Tenancy\Scopes\TenantScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class MerchantQrController extends Controller
{
    public function __construct(private MerchantQrService $qr) {}

    public function index(Company $company): JsonResponse
    {
        $codes = MerchantQrCode::query()
            ->where('company_id', $company->id)
            ->latest()
            ->get()
            ->map(fn (MerchantQrCode $code) => $this->qr->present($code))
            ->values();

        return response()->json(['data' => $codes]);
    }

    public function tables(Company $company): JsonResponse
    {
        $tables = PosTable::query()
            ->with('zone:id,name')
            ->whereHas('store.branch', fn ($query) => $query->where('company_id', $company->id))
            ->orderBy('name')
            ->get()
            ->map(fn (PosTable $table) => [
                'id' => $table->id,
                'name' => $table->name,
                'code' => $table->code,
                'zone' => $table->zone?->name,
                'status' => $table->status instanceof \BackedEnum ? $table->status->value : (string) $table->status,
            ])
            ->values();

        return response()->json(['data' => $tables]);
    }

    public function store(Request $request, Company $company): JsonResponse
    {
        $data = $request->validate([
            'label' => ['nullable', 'string', 'max:120'],
            'type' => ['required', Rule::in(MerchantQrService::TYPES)],
            'url' => ['nullable', 'string', 'max:2048', 'regex:/^https?:\\/\\//i'],
            'table_id' => ['nullable', 'uuid'],
            'pdf' => ['nullable', 'file', 'mimes:pdf', 'max:10240'],
            'amount' => ['nullable', 'numeric', 'min:0'],
            'currency' => ['nullable', 'string', 'regex:/^[A-Za-z]{3}$/'],
            'reference' => ['nullable', 'string', 'max:120'],
            'display_name' => ['nullable', 'string', 'max:120'],
        ]);

        if (in_array($data['type'], ['table', 'pdf_menu', 'external_link', 'company'], true) && blank($data['label'] ?? null)) {
            throw ValidationException::withMessages([
                'label' => ['Enter a label.'],
            ]);
        }

        if ($data['type'] === 'payment' && ! array_key_exists('amount', $data)) {
            throw ValidationException::withMessages([
                'amount' => ['Enter an amount.'],
            ]);
        }

        if ($data['type'] === 'merchant' && blank($data['display_name'] ?? null) && blank($data['label'] ?? null)) {
            throw ValidationException::withMessages([
                'display_name' => ['Enter the name shown on the QR.'],
            ]);
        }

        if ($data['type'] === 'pdf_menu' && ! $request->hasFile('pdf') && blank($data['url'] ?? null)) {
            throw ValidationException::withMessages([
                'pdf' => ['Choose a PDF file.'],
            ]);
        }

        if ($data['type'] === 'external_link' && blank($data['url'] ?? null)) {
            throw ValidationException::withMessages([
                'url' => ['A web address is required for this QR type.'],
            ]);
        }

        if ($data['type'] === 'table' && blank($data['table_id'] ?? null)) {
            throw ValidationException::withMessages([
                'table_id' => ['Choose a table before saving.'],
            ]);
        }

        $code = $this->qr->create($company, $data, $request->file('pdf'));

        return response()->json(['data' => $this->qr->present($code)], 201);
    }

    public function destroy(MerchantQrCode $merchantQrCode): JsonResponse
    {
        $this->qr->delete($merchantQrCode);

        return response()->json(['message' => 'Deleted.']);
    }

    public function publicShow(string $merchantQr): JsonResponse
    {
        $code = MerchantQrCode::query()
            ->withoutGlobalScope(TenantScope::class)
            ->find($merchantQr);

        if ($code === null) {
            return response()->json(['message' => 'Not found.'], 404);
        }

        return response()->json(['data' => $this->qr->publicPayload($code)]);
    }
}
