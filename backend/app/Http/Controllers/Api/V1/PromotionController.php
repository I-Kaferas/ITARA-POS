<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\PromotionType;
use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\Promotion;
use App\Models\Store;
use App\Services\Promotions\PromotionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PromotionController extends Controller
{
    public function __construct(
        private readonly PromotionService $promotionService,
    ) {}

    public function types(): JsonResponse
    {
        $types = collect(config('promotions.types'))
            ->map(fn (array $meta, string $value) => [
                'value' => $value,
                'label' => $meta['label'],
                'label_fr' => $meta['label_fr'],
                'requires' => $meta['requires'],
            ])
            ->values();

        return response()->json(['data' => $types]);
    }

    public function index(Request $request): JsonResponse
    {
        $query = Promotion::query()
            ->with(['items', 'customers', 'category', 'store'])
            ->orderByDesc('priority')
            ->orderBy('name');

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        if ($request->filled('type')) {
            $query->where('type', $request->string('type'));
        }

        if ($request->filled('store_id')) {
            $query->where(fn ($q) => $q
                ->whereNull('store_id')
                ->orWhere('store_id', $request->string('store_id')));
        }

        return response()->json(['data' => $query->get()]);
    }

    public function activeForStore(Request $request, Store $store): JsonResponse
    {
        $customer = null;
        if ($request->filled('customer_id')) {
            $customer = Customer::query()->findOrFail($request->string('customer_id'));
        }

        $promotions = $this->promotionService->activeForStore($store, $customer);

        return response()->json(['data' => $promotions]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validatePromotion($request);

        $promotion = $this->promotionService->create($data);

        return response()->json(['data' => $promotion], 201);
    }

    public function show(Promotion $promotion): JsonResponse
    {
        $promotion->load(['items.product', 'customers.customer', 'category', 'store']);

        return response()->json(['data' => $promotion]);
    }

    public function update(Request $request, Promotion $promotion): JsonResponse
    {
        $data = $this->validatePromotion($request, true);

        $promotion = $this->promotionService->update($promotion, $data);

        return response()->json(['data' => $promotion]);
    }

    public function destroy(Promotion $promotion): JsonResponse
    {
        $promotion->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    /** @return array<string, mixed> */
    private function validatePromotion(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'name' => [$required, 'string', 'max:255'],
            'code' => ['nullable', 'string', 'max:50'],
            'type' => [$required, 'string', Rule::in(PromotionType::values())],
            'description' => ['nullable', 'string'],
            'store_id' => ['nullable', 'uuid', 'exists:stores,id'],
            'category_id' => ['nullable', 'uuid', 'exists:categories,id'],
            'starts_at' => ['nullable', 'date'],
            'ends_at' => ['nullable', 'date', 'after_or_equal:starts_at'],
            'min_quantity' => ['nullable', 'integer', 'min:1'],
            'max_uses' => ['nullable', 'integer', 'min:1'],
            'priority' => ['nullable', 'integer'],
            'discount_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'discount_amount' => ['nullable', 'integer', 'min:0'],
            'buy_quantity' => ['nullable', 'integer', 'min:1'],
            'get_quantity' => ['nullable', 'integer', 'min:1'],
            'bundle_price' => ['nullable', 'integer', 'min:0'],
            'schedule' => ['nullable', 'array'],
            'schedule.days_of_week' => ['nullable', 'array'],
            'schedule.days_of_week.*' => ['integer', 'min:1', 'max:7'],
            'schedule.time_start' => ['nullable', 'string', 'regex:/^\d{2}:\d{2}$/'],
            'schedule.time_end' => ['nullable', 'string', 'regex:/^\d{2}:\d{2}$/'],
            'is_active' => ['boolean'],
            'items' => ['nullable', 'array'],
            'items.*.product_id' => ['nullable', 'uuid', 'exists:products,id'],
            'items.*.product_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
            'items.*.role' => ['nullable', 'string', Rule::in(config('promotions.item_roles'))],
            'items.*.quantity' => ['nullable', 'integer', 'min:1'],
            'customer_ids' => ['nullable', 'array'],
            'customer_ids.*' => ['uuid', 'exists:customers,id'],
        ]);
    }
}
