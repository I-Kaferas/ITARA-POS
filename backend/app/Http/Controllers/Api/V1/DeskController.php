<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Store;
use App\Services\Desk\HospitalityDesk;
use App\Services\Desk\ProductionDesk;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeskController extends Controller
{
    public function __construct(
        private readonly HospitalityDesk $hospitality,
        private readonly ProductionDesk $production,
    ) {}

    public function hospitality(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->hospitality->snapshot($this->store())]);
    }

    public function hospitalityAction(Request $request): JsonResponse
    {
        $data = $request->validate([
            'action' => ['required', 'string', 'max:40'],
        ]);

        return response()->json([
            'data' => $this->hospitality->apply($this->store(), array_merge($data, $request->all())),
        ]);
    }

    public function production(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->production->snapshot($this->store())]);
    }

    public function productionAction(Request $request): JsonResponse
    {
        $data = $request->validate([
            'action' => ['required', 'string', 'max:40'],
            'recipe_id' => ['nullable', 'string', 'max:80'],
            'batches' => ['nullable', 'integer', 'min:1', 'max:500'],
        ]);

        return response()->json([
            'data' => $this->production->apply($this->store(), $data, $request->user()?->id),
        ]);
    }

    private function store(): Store
    {
        $store = app()->bound('store') ? app('store') : null;
        if (! $store instanceof Store) {
            abort(400, 'X-Store-ID header is required.');
        }

        return $store;
    }
}
