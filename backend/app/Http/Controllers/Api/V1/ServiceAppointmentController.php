<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ServiceAppointment;
use App\Models\ServiceOffering;
use App\Models\Store;
use App\Services\Services\ServiceDesk;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ServiceAppointmentController extends Controller
{
    public function __construct(private readonly ServiceDesk $desk) {}

    public function offerings(): JsonResponse
    {
        $this->desk->ensureDefaults((string) app('tenant.id'));

        return response()->json([
            'data' => ServiceOffering::query()->where('is_active', true)->orderBy('name')->get(),
        ]);
    }

    public function index(): JsonResponse
    {
        $this->desk->ensureDefaults((string) app('tenant.id'));

        return response()->json([
            'data' => ServiceAppointment::query()
                ->with(['offering:id,name,category,price,duration_minutes', 'employee:id,name'])
                ->orderByDesc('scheduled_at')
                ->limit(200)
                ->get(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'service_offering_id' => ['required', 'uuid'],
            'customer_name' => ['required', 'string', 'max:160'],
            'scheduled_at' => ['required', 'date'],
        ]);

        $appointment = $this->desk->book((string) app('tenant.id'), $data, $this->currentStore());

        return response()->json(['data' => $appointment->load(['offering', 'employee'])], 201);
    }

    public function assign(Request $request, ServiceAppointment $serviceAppointment): JsonResponse
    {
        $data = $request->validate([
            'employee_id' => ['required', 'uuid'],
        ]);

        return response()->json([
            'data' => $this->desk->assign($serviceAppointment, $data['employee_id'])->load(['offering', 'employee']),
        ]);
    }

    public function complete(Request $request, ServiceAppointment $serviceAppointment): JsonResponse
    {
        $data = $request->validate([
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);

        return response()->json([
            'data' => $this->desk->complete($serviceAppointment, $request->user(), $data['notes'] ?? null)
                ->load(['offering', 'employee']),
        ]);
    }

    public function pay(Request $request, ServiceAppointment $serviceAppointment): JsonResponse
    {
        $store = $this->currentStore();
        if ($store === null) {
            abort(400, 'X-Store-ID header is required.');
        }

        $data = $request->validate([
            'method' => ['nullable', 'string', 'max:40'],
        ]);

        return response()->json([
            'data' => $this->desk->pay($serviceAppointment, $store, $request->user(), $data['method'] ?? 'cash')
                ->load(['offering', 'employee']),
        ]);
    }

    private function currentStore(): ?Store
    {
        $store = app()->bound('store') ? app('store') : null;

        return $store instanceof Store ? $store : null;
    }
}
