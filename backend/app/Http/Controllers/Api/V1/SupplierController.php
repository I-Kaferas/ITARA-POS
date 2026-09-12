<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\Supplier;
use App\Services\Supplier\SupplierLedgerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class SupplierController extends Controller
{
    public function __construct(
        private readonly SupplierLedgerService $ledger,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $query = Supplier::query()->with('contacts')->orderBy('name');

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        if ($search = $request->string('search')->toString()) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('code', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%");
            });
        }

        return response()->json(['data' => $query->paginate($request->integer('per_page', 25))]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'code' => ['nullable', 'string', 'max:50'],
            'contact_person' => ['nullable', 'string', 'max:255'],
            'legal_name' => ['nullable', 'string', 'max:255'],
            'tax_id' => ['nullable', 'string', 'max:100'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'address' => ['nullable', 'array'],
            'address.line1' => ['nullable', 'string', 'max:255'],
            'address.city' => ['nullable', 'string', 'max:100'],
            'address.country' => ['nullable', 'string', 'max:100'],
            'payment_terms_days' => ['nullable', 'integer', 'min:0', 'max:365'],
            'credit_limit' => ['nullable', 'integer', 'min:0'],
            'currency_code' => ['nullable', 'string', 'size:3'],
            'notes' => ['nullable', 'string'],
            'metadata' => ['nullable', 'array'],
            'is_active' => ['boolean'],
        ]);

        $contactPerson = $this->blankToNull($data['contact_person'] ?? null);
        unset($data['contact_person']);

        $supplier = Supplier::query()->create([
            ...$data,
            'code' => $this->uniqueCode($data['code'] ?? null, $data['name']),
            'address' => $this->normalizeAddress($data['address'] ?? null),
            'tenant_id' => app('tenant.id'),
            'payment_terms_days' => $data['payment_terms_days'] ?? 30,
            'currency_code' => strtoupper($data['currency_code'] ?? $this->defaultCurrencyCode()),
            'is_active' => $data['is_active'] ?? true,
        ]);

        $this->syncContactPerson($supplier, $contactPerson);

        return response()->json(['data' => $supplier->fresh(['contacts'])], 201);
    }

    private function blankToNull(mixed $value): ?string
    {
        $value = is_string($value) ? trim($value) : '';

        return $value === '' ? null : $value;
    }

    /** @param  array<string, mixed>|null  $address */
    private function normalizeAddress(?array $address): ?array
    {
        if ($address === null) {
            return null;
        }

        $normalized = [
            'line1' => $this->blankToNull($address['line1'] ?? null),
            'city' => $this->blankToNull($address['city'] ?? null),
            'country' => $this->blankToNull($address['country'] ?? null),
        ];

        return array_filter($normalized, fn ($value) => $value !== null) === []
            ? null
            : $normalized;
    }

    private function uniqueCode(?string $code, string $name): string
    {
        $code = $this->blankToNull($code);
        if ($code !== null) {
            return $code;
        }

        $base = Str::upper(Str::slug($name, ''));
        $base = $base !== '' ? substr($base, 0, 12) : 'SUP';
        $candidate = $base;
        $i = 1;

        while (Supplier::withTrashed()->where('code', $candidate)->exists()) {
            $candidate = $base.'-'.$i;
            $i++;
        }

        return $candidate;
    }

    private function syncContactPerson(Supplier $supplier, ?string $name): void
    {
        $primary = $supplier->contacts()->where('is_primary', true)->first()
            ?? $supplier->contacts()->first();

        if ($name === null) {
            return;
        }

        if ($primary) {
            $primary->update(['name' => $name, 'is_primary' => true]);

            return;
        }

        $supplier->contacts()->create([
            'tenant_id' => $supplier->tenant_id,
            'name' => $name,
            'is_primary' => true,
        ]);
    }

    private function defaultCurrencyCode(): string
    {
        $code = Company::query()->where('is_active', true)->value('currency_code');

        return strtoupper($code ?: 'FBU');
    }

    public function show(Supplier $supplier): JsonResponse
    {
        return response()->json([
            'data' => $supplier->load(['contacts']),
            'summary' => $this->ledger->summary($supplier),
        ]);
    }

    public function update(Request $request, Supplier $supplier): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'code' => ['sometimes', 'string', 'max:50'],
            'contact_person' => ['nullable', 'string', 'max:255'],
            'legal_name' => ['nullable', 'string', 'max:255'],
            'tax_id' => ['nullable', 'string', 'max:100'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'address' => ['nullable', 'array'],
            'address.line1' => ['nullable', 'string', 'max:255'],
            'address.city' => ['nullable', 'string', 'max:100'],
            'address.country' => ['nullable', 'string', 'max:100'],
            'payment_terms_days' => ['nullable', 'integer', 'min:0', 'max:365'],
            'credit_limit' => ['nullable', 'integer', 'min:0'],
            'currency_code' => ['nullable', 'string', 'size:3'],
            'notes' => ['nullable', 'string'],
            'metadata' => ['nullable', 'array'],
            'is_active' => ['boolean'],
        ]);

        $contactPerson = array_key_exists('contact_person', $data)
            ? $this->blankToNull($data['contact_person'])
            : null;
        $syncContact = array_key_exists('contact_person', $data);
        unset($data['contact_person']);

        if (array_key_exists('address', $data)) {
            $data['address'] = $this->normalizeAddress($data['address']);
        }

        $supplier->update($data);

        if ($syncContact) {
            $this->syncContactPerson($supplier, $contactPerson);
        }

        return response()->json(['data' => $supplier->fresh(['contacts'])]);
    }

    public function destroy(Supplier $supplier): JsonResponse
    {
        $supplier->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    public function summary(Supplier $supplier): JsonResponse
    {
        return response()->json(['data' => $this->ledger->summary($supplier)]);
    }

    public function statement(Request $request, Supplier $supplier): JsonResponse
    {
        $data = $request->validate([
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date', 'after_or_equal:from'],
        ]);

        $from = isset($data['from']) ? new \DateTimeImmutable($data['from']) : null;
        $to = isset($data['to']) ? new \DateTimeImmutable($data['to'].' 23:59:59') : null;

        return response()->json([
            'data' => $this->ledger->statement($supplier, $from, $to),
            'meta' => [
                'supplier_id' => $supplier->id,
                'balance' => $this->ledger->balance($supplier),
                'debt' => $this->ledger->debt($supplier),
                'credit' => $this->ledger->credit($supplier),
            ],
        ]);
    }

    public function dueDates(Supplier $supplier): JsonResponse
    {
        $open = $this->ledger->dueTransactions($supplier);
        $overdue = $this->ledger->dueTransactions($supplier, overdueOnly: true);

        return response()->json([
            'data' => [
                'open' => $open->map(fn ($tx) => [
                    'id' => $tx->id,
                    'reference' => $tx->reference,
                    'due_date' => $tx->due_date?->toDateString(),
                    'amount' => $tx->amount,
                    'outstanding' => $tx->outstandingAmount(),
                    'is_overdue' => $tx->isOverdue(),
                ])->values(),
                'overdue' => $overdue->map(fn ($tx) => [
                    'id' => $tx->id,
                    'reference' => $tx->reference,
                    'due_date' => $tx->due_date?->toDateString(),
                    'outstanding' => $tx->outstandingAmount(),
                ])->values(),
            ],
        ]);
    }

    public function purchaseHistory(Supplier $supplier): JsonResponse
    {
        $purchases = $supplier->purchases()
            ->with(['warehouse:id,name,code', 'transactions'])
            ->orderByDesc('created_at')
            ->get();

        return response()->json(['data' => $purchases]);
    }
}
