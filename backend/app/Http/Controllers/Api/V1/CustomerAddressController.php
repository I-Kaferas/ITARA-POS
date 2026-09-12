<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\CustomerAddress;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CustomerAddressController extends Controller
{
    public function index(Customer $customer): JsonResponse
    {
        return response()->json(['data' => $customer->addresses]);
    }

    public function store(Request $request, Customer $customer): JsonResponse
    {
        $data = $request->validate([
            'label' => ['nullable', 'string', 'max:50'],
            'line1' => ['required', 'string', 'max:255'],
            'line2' => ['nullable', 'string', 'max:255'],
            'city' => ['nullable', 'string', 'max:100'],
            'state' => ['nullable', 'string', 'max:100'],
            'postal_code' => ['nullable', 'string', 'max:20'],
            'country_code' => ['nullable', 'string', 'size:2'],
            'is_primary' => ['boolean'],
            'is_billing' => ['boolean'],
            'is_shipping' => ['boolean'],
        ]);

        if ($data['is_primary'] ?? false) {
            CustomerAddress::query()
                ->where('customer_id', $customer->id)
                ->update(['is_primary' => false]);
        }

        $address = $customer->addresses()->create([
            ...$data,
            'tenant_id' => $customer->tenant_id,
            'label' => $data['label'] ?? 'default',
            'country_code' => $data['country_code'] ?? 'BI',
            'is_primary' => $data['is_primary'] ?? false,
            'is_billing' => $data['is_billing'] ?? false,
            'is_shipping' => $data['is_shipping'] ?? true,
        ]);

        return response()->json(['data' => $address], 201);
    }

    public function update(Request $request, CustomerAddress $customerAddress): JsonResponse
    {
        $data = $request->validate([
            'label' => ['nullable', 'string', 'max:50'],
            'line1' => ['sometimes', 'string', 'max:255'],
            'line2' => ['nullable', 'string', 'max:255'],
            'city' => ['nullable', 'string', 'max:100'],
            'state' => ['nullable', 'string', 'max:100'],
            'postal_code' => ['nullable', 'string', 'max:20'],
            'country_code' => ['nullable', 'string', 'size:2'],
            'is_primary' => ['boolean'],
            'is_billing' => ['boolean'],
            'is_shipping' => ['boolean'],
        ]);

        if ($data['is_primary'] ?? false) {
            CustomerAddress::query()
                ->where('customer_id', $customerAddress->customer_id)
                ->whereKeyNot($customerAddress->id)
                ->update(['is_primary' => false]);
        }

        $customerAddress->update($data);

        return response()->json(['data' => $customerAddress->fresh()]);
    }

    public function destroy(CustomerAddress $customerAddress): JsonResponse
    {
        $customerAddress->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
