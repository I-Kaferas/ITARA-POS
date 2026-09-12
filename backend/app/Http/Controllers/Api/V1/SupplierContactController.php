<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Supplier;
use App\Models\SupplierContact;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SupplierContactController extends Controller
{
    public function index(Supplier $supplier): JsonResponse
    {
        return response()->json(['data' => $supplier->contacts]);
    }

    public function store(Request $request, Supplier $supplier): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'title' => ['nullable', 'string', 'max:100'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'is_primary' => ['boolean'],
            'notes' => ['nullable', 'string'],
        ]);

        if ($data['is_primary'] ?? false) {
            SupplierContact::query()
                ->where('supplier_id', $supplier->id)
                ->update(['is_primary' => false]);
        }

        $contact = $supplier->contacts()->create([
            ...$data,
            'tenant_id' => $supplier->tenant_id,
            'is_primary' => $data['is_primary'] ?? false,
        ]);

        return response()->json(['data' => $contact], 201);
    }

    public function update(Request $request, SupplierContact $supplierContact): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'title' => ['nullable', 'string', 'max:100'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'is_primary' => ['boolean'],
            'notes' => ['nullable', 'string'],
        ]);

        if ($data['is_primary'] ?? false) {
            SupplierContact::query()
                ->where('supplier_id', $supplierContact->supplier_id)
                ->whereKeyNot($supplierContact->id)
                ->update(['is_primary' => false]);
        }

        $supplierContact->update($data);

        return response()->json(['data' => $supplierContact->fresh()]);
    }

    public function destroy(SupplierContact $supplierContact): JsonResponse
    {
        $supplierContact->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
