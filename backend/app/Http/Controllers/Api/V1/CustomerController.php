<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Services\Customer\CustomerLedgerService;
use App\Services\Customer\CustomerLoyaltyService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class CustomerController extends Controller
{
    public function __construct(
        private readonly CustomerLedgerService $ledger,
        private readonly CustomerLoyaltyService $loyalty,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $query = Customer::query()->with('addresses')->orderBy('name');

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        if ($search = $request->string('search')->toString()) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('code', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%");
            });
        }

        return response()->json(['data' => $query->paginate($request->integer('per_page', 25))]);
    }

    public function store(Request $request): JsonResponse
    {
        $tenantId = (string) app('tenant.id');

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'code' => [
                'nullable',
                'string',
                'max:50',
                Rule::unique('customers', 'code')->where(
                    fn ($q) => $q->where('tenant_id', $tenantId)->whereNull('deleted_at')
                ),
            ],
            'company_name' => ['nullable', 'string', 'max:255'],
            'tax_id' => ['nullable', 'string', 'max:100'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'date_of_birth' => ['nullable', 'date'],
            'gender' => ['nullable', 'string', 'max:20'],
            'credit_limit' => ['nullable', 'integer', 'min:0'],
            'payment_terms_days' => ['nullable', 'integer', 'min:0', 'max:365'],
            'price_tier' => ['nullable', 'string', Rule::in(array_keys(config('customers.price_tiers', [])))],
            'notes' => ['nullable', 'string'],
            'metadata' => ['nullable', 'array'],
            'is_active' => ['boolean'],
        ]);

        if (array_key_exists('code', $data)) {
            $code = is_string($data['code']) ? trim($data['code']) : '';
            $data['code'] = $code !== '' ? $code : null;
        }

        $customer = Customer::query()->create([
            ...$data,
            'tenant_id' => $tenantId,
            'payment_terms_days' => $data['payment_terms_days'] ?? 0,
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json(['data' => $customer], 201);
    }

    public function show(Customer $customer): JsonResponse
    {
        return response()->json([
            'data' => $customer->load(['addresses']),
            'summary' => $this->ledger->summary($customer),
            'loyalty' => $this->loyalty->summary($customer),
        ]);
    }

    public function update(Request $request, Customer $customer): JsonResponse
    {
        $tenantId = (string) ($customer->tenant_id ?: app('tenant.id'));

        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'code' => [
                'nullable',
                'string',
                'max:50',
                Rule::unique('customers', 'code')
                    ->where(fn ($q) => $q->where('tenant_id', $tenantId)->whereNull('deleted_at'))
                    ->ignore($customer->id),
            ],
            'company_name' => ['nullable', 'string', 'max:255'],
            'tax_id' => ['nullable', 'string', 'max:100'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'date_of_birth' => ['nullable', 'date'],
            'gender' => ['nullable', 'string', 'max:20'],
            'credit_limit' => ['nullable', 'integer', 'min:0'],
            'payment_terms_days' => ['nullable', 'integer', 'min:0', 'max:365'],
            'price_tier' => ['nullable', 'string', Rule::in(array_keys(config('customers.price_tiers', [])))],
            'notes' => ['nullable', 'string'],
            'metadata' => ['nullable', 'array'],
            'is_active' => ['boolean'],
        ]);

        if (array_key_exists('code', $data)) {
            $code = is_string($data['code']) ? trim($data['code']) : '';
            if ($code === '') {
                unset($data['code']);
            } else {
                $data['code'] = $code;
            }
        }

        if (! filled($customer->code) && ! isset($data['code'])) {
            $data['code'] = Customer::nextCode($tenantId);
        }

        $customer->update($data);

        return response()->json(['data' => $customer->fresh(['addresses'])]);
    }

    public function destroy(Customer $customer): JsonResponse
    {
        $customer->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    public function summary(Customer $customer): JsonResponse
    {
        return response()->json(['data' => $this->ledger->summary($customer)]);
    }

    public function balance(Customer $customer): JsonResponse
    {
        return response()->json([
            'data' => [
                'balance' => $this->ledger->balance($customer),
                'receivable' => $this->ledger->receivable($customer),
                'credit' => $this->ledger->credit($customer),
                'available_credit' => $this->ledger->availableCredit($customer),
            ],
        ]);
    }

    public function history(Request $request, Customer $customer): JsonResponse
    {
        $data = $request->validate([
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date', 'after_or_equal:from'],
        ]);

        $from = isset($data['from']) ? new \DateTimeImmutable($data['from']) : null;
        $to = isset($data['to']) ? new \DateTimeImmutable($data['to'].' 23:59:59') : null;

        return response()->json([
            'data' => $this->ledger->history($customer, $from, $to),
            'meta' => $this->ledger->summary($customer),
        ]);
    }

    public function salesHistory(Customer $customer): JsonResponse
    {
        return response()->json([
            'data' => $customer->sales()
                ->with(['store:id,name,code', 'transactions'])
                ->orderByDesc('created_at')
                ->get(),
        ]);
    }

    public function loyalty(Customer $customer): JsonResponse
    {
        return response()->json(['data' => $this->loyalty->summary($customer)]);
    }

    public function redeemLoyalty(Request $request, Customer $customer): JsonResponse
    {
        $data = $request->validate([
            'points' => ['required', 'integer', 'min:1'],
        ]);

        $updated = $this->loyalty->redeemPoints($customer, $data['points'], $request->user()?->id);

        return response()->json(['data' => $this->loyalty->summary($updated)]);
    }
}
