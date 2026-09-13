<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Tax;
use App\Support\Money\MoneyMath;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TaxController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Tax::query()->orderBy('name');

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        return response()->json(['data' => $query->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'code' => ['required', 'string', 'max:50'],
            'rate' => ['required', 'numeric', 'min:0', 'max:100'],
            'is_inclusive' => ['boolean'],
            'is_active' => ['boolean'],
        ]);

        $tax = Tax::query()->create([
            ...$data,
            'tenant_id' => app('tenant.id'),
            'is_inclusive' => $data['is_inclusive'] ?? false,
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json(['data' => $tax], 201);
    }

    public function show(Tax $tax): JsonResponse
    {
        return response()->json(['data' => $tax]);
    }

    public function update(Request $request, Tax $tax): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'code' => ['sometimes', 'string', 'max:50'],
            'rate' => ['sometimes', 'numeric', 'min:0', 'max:100'],
            'is_inclusive' => ['boolean'],
            'is_active' => ['boolean'],
        ]);

        $tax->update($data);

        return response()->json(['data' => $tax->fresh()]);
    }

    public function calculate(Request $request): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:0'],
            'amount_is_inclusive' => ['boolean'],
            'tax_ids' => ['nullable', 'array'],
            'tax_ids.*' => ['uuid'],
        ]);

        $inclusive = (bool) ($data['amount_is_inclusive'] ?? false);
        $amount = (int) $data['amount'];
        $taxes = Tax::query()
            ->where('is_active', true)
            ->when($data['tax_ids'] ?? [], fn ($query, $ids) => $query->whereIn('id', $ids))
            ->orderBy('name')
            ->get();

        if (($data['tax_ids'] ?? []) === []) {
            $taxes = collect();
        }

        $lines = [];
        $taxTotal = 0;
        foreach ($taxes as $tax) {
            $taxAmount = $inclusive
                ? MoneyMath::extractInclusiveTax($amount, $tax->rate)
                : MoneyMath::taxOnExclusive($amount, $tax->rate);
            $taxTotal += $taxAmount;
            $lines[] = [
                'tax_id' => $tax->id,
                'name' => $tax->name,
                'code' => $tax->code,
                'rate' => (float) $tax->rate,
                'priority' => 0,
                'is_inclusive' => $inclusive,
                'is_compound' => false,
                'taxable_amount' => $inclusive ? $amount - $taxAmount : $amount,
                'tax_amount' => $taxAmount,
            ];
        }

        $net = $inclusive ? $amount - $taxTotal : $amount;
        $total = $inclusive ? $amount : $amount + $taxTotal;

        return response()->json([
            'data' => [
                'net' => max(0, $net),
                'tax_total' => $taxTotal,
                'total' => max(0, $total),
                'lines' => $lines,
            ],
        ]);
    }

    public function destroy(Tax $tax): JsonResponse
    {
        $tax->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
