<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\SerialNumberStatus;
use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\SerialNumber;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SerialNumberController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = SerialNumber::query()
            ->with([
                'product:id,sku,name',
                'productVariant:id,sku,name',
                'batch:id,batch_number',
                'warehouse:id,name,code',
            ])
            ->orderByDesc('created_at');

        if ($request->filled('product_id')) {
            $query->where('product_id', $request->string('product_id'));
        }

        if ($request->filled('warehouse_id')) {
            $query->where('warehouse_id', $request->string('warehouse_id'));
        }

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        if ($search = $request->string('search')->toString()) {
            $query->where('serial_number', 'like', "%{$search}%");
        }

        return response()->json([
            'data' => $query->paginate($request->integer('per_page', 25)),
        ]);
    }

    public function statuses(): JsonResponse
    {
        return response()->json([
            'data' => collect(SerialNumberStatus::cases())->map(fn (SerialNumberStatus $status) => [
                'value' => $status->value,
                'label' => str_replace('_', ' ', ucfirst($status->value)),
            ])->values(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'product_id' => ['required', 'uuid', 'exists:products,id'],
            'serial_number' => ['required', 'string', 'max:100'],
            'product_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
            'batch_id' => ['nullable', 'uuid', 'exists:batches,id'],
            'warehouse_id' => ['nullable', 'uuid', 'exists:warehouses,id'],
            'status' => ['nullable', Rule::in(SerialNumberStatus::values())],
            'metadata' => ['nullable', 'array'],
        ]);

        $product = Product::query()->findOrFail($data['product_id']);

        $exists = SerialNumber::query()
            ->where('tenant_id', $product->tenant_id)
            ->where('serial_number', $data['serial_number'])
            ->exists();

        if ($exists) {
            return response()->json(['message' => 'Serial number already exists.'], 422);
        }

        $serial = SerialNumber::query()->create([
            'tenant_id' => $product->tenant_id,
            'product_id' => $data['product_id'],
            'product_variant_id' => $data['product_variant_id'] ?? null,
            'batch_id' => $data['batch_id'] ?? null,
            'warehouse_id' => $data['warehouse_id'] ?? null,
            'serial_number' => $data['serial_number'],
            'status' => $data['status'] ?? SerialNumberStatus::Available->value,
            'metadata' => $data['metadata'] ?? null,
        ]);

        return response()->json([
            'data' => $serial->load([
                'product:id,sku,name',
                'warehouse:id,name,code',
                'batch:id,batch_number',
            ]),
        ], 201);
    }

    public function show(SerialNumber $serialNumber): JsonResponse
    {
        return response()->json([
            'data' => $serialNumber->load([
                'product:id,sku,name',
                'productVariant:id,sku,name',
                'batch:id,batch_number',
                'warehouse:id,name,code',
            ]),
        ]);
    }

    public function update(Request $request, SerialNumber $serialNumber): JsonResponse
    {
        $data = $request->validate([
            'status' => ['sometimes', Rule::in(SerialNumberStatus::values())],
            'warehouse_id' => ['nullable', 'uuid', 'exists:warehouses,id'],
            'batch_id' => ['nullable', 'uuid', 'exists:batches,id'],
            'metadata' => ['nullable', 'array'],
        ]);

        $serialNumber->update($data);

        return response()->json([
            'data' => $serialNumber->fresh([
                'product:id,sku,name',
                'warehouse:id,name,code',
                'batch:id,batch_number',
            ]),
        ]);
    }

    public function destroy(SerialNumber $serialNumber): JsonResponse
    {
        $serialNumber->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
