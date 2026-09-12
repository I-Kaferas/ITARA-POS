<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\Payable\PayableService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PayableController extends Controller
{
    public function __construct(
        private readonly PayableService $payables,
    ) {}

    public function summary(): JsonResponse
    {
        $tenantId = app('tenant.id');

        return response()->json(['data' => $this->payables->summary($tenantId)]);
    }

    public function schedule(Request $request): JsonResponse
    {
        $tenantId = app('tenant.id');
        $overdueOnly = $request->boolean('overdue_only');

        return response()->json([
            'data' => $this->payables->schedule($tenantId, $overdueOnly),
        ]);
    }

    public function payments(Request $request): JsonResponse
    {
        $tenantId = app('tenant.id');
        $limit = min($request->integer('limit', 25), 100);

        return response()->json([
            'data' => $this->payables->recentPayments($tenantId, $limit),
        ]);
    }
}
