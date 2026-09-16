<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\PosReservation;
use App\Models\PosTable;
use App\Models\Store;
use App\Services\Pos\PosTableService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PosReservationController extends Controller
{
    public function __construct(
        private readonly PosTableService $tables,
    ) {}
    public function index(Request $request, Store $store): JsonResponse
    {
        $data = $request->validate([
            'status' => ['nullable', 'string', Rule::in(PosReservation::STATUSES)],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date'],
            'q' => ['nullable', 'string', 'max:120'],
        ]);

        $query = PosReservation::query()
            ->with(['customer:id,name,phone'])
            ->where('store_id', $store->id)
            ->orderBy('reserved_at');

        if (! empty($data['status'])) {
            $query->where('status', $data['status']);
        }
        if (! empty($data['from'])) {
            $query->where('reserved_at', '>=', $data['from']);
        }
        if (! empty($data['to'])) {
            $query->where('reserved_at', '<=', $data['to'].' 23:59:59');
        }
        if (! empty($data['q'])) {
            $term = '%'.$data['q'].'%';
            $query->where(function ($builder) use ($term) {
                $builder->where('guest_name', 'like', $term)
                    ->orWhere('phone', 'like', $term)
                    ->orWhere('reference', 'like', $term)
                    ->orWhere('table_label', 'like', $term);
            });
        }

        return response()->json(['data' => $query->limit(200)->get()]);
    }

    public function store(Request $request, Store $store): JsonResponse
    {
        $data = $this->validated($request);
        $guest = $this->guestFrom($data);

        $reservation = PosReservation::query()->create([
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'customer_id' => $data['customer_id'] ?? null,
            'reference' => $this->nextReference($store->tenant_id),
            'guest_name' => $guest['name'],
            'phone' => $guest['phone'],
            'party_size' => $data['party_size'],
            'reserved_at' => $data['reserved_at'],
            'table_label' => $data['table_label'] ?? null,
            'table_id' => $data['table_id'] ?? null,
            'status' => $data['status'] ?? 'pending',
            'notes' => $data['notes'] ?? null,
            'created_by' => $request->user()?->id,
        ]);

        if (! empty($data['table_id'])) {
            $this->tables->applyReservationToTable($data['table_id'], $store);
            if (empty($data['table_label'])) {
                $table = PosTable::query()->find($data['table_id']);
                if ($table) {
                    $reservation->update(['table_label' => $table->name]);
                }
            }
        }

        return response()->json(['data' => $reservation->load('customer:id,name,phone')], 201);
    }

    public function update(Request $request, PosReservation $posReservation): JsonResponse
    {
        $data = $this->validated($request);
        $guest = $this->guestFrom($data);
        $previousTableId = $posReservation->table_id;

        $posReservation->update([
            'customer_id' => $data['customer_id'] ?? null,
            'guest_name' => $guest['name'],
            'phone' => $guest['phone'],
            'party_size' => $data['party_size'],
            'reserved_at' => $data['reserved_at'],
            'table_label' => $data['table_label'] ?? null,
            'table_id' => $data['table_id'] ?? null,
            'status' => $data['status'] ?? $posReservation->status,
            'notes' => $data['notes'] ?? null,
        ]);

        $this->syncReservationTable($posReservation->fresh(), $previousTableId);

        return response()->json(['data' => $posReservation->fresh(['customer:id,name,phone'])]);
    }

    public function updateStatus(Request $request, PosReservation $posReservation): JsonResponse
    {
        $data = $request->validate([
            'status' => ['required', 'string', Rule::in(PosReservation::STATUSES)],
        ]);
        $posReservation->update(['status' => $data['status']]);

        if (in_array($data['status'], ['cancelled', 'no_show', 'completed'], true)) {
            $this->tables->releaseReservation($posReservation);
        } elseif (in_array($data['status'], ['pending', 'confirmed'], true) && $posReservation->table_id) {
            $this->tables->applyReservationToTable($posReservation->table_id, $posReservation->store);
        }

        return response()->json(['data' => $posReservation->fresh(['customer:id,name,phone'])]);
    }

    /** @return array<string, mixed> */
    private function validated(Request $request): array
    {
        return $request->validate([
            'customer_id' => ['nullable', 'uuid', 'exists:customers,id'],
            'guest_name' => ['nullable', 'string', 'max:160', 'required_without:customer_id'],
            'phone' => ['nullable', 'string', 'max:40'],
            'party_size' => ['required', 'integer', 'min:1', 'max:200'],
            'reserved_at' => ['required', 'date'],
            'table_label' => ['nullable', 'string', 'max:40'],
            'table_id' => ['nullable', 'uuid', 'exists:pos_tables,id'],
            'status' => ['nullable', 'string', Rule::in(PosReservation::STATUSES)],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);
    }

    /** @param  array<string, mixed>  $data
     * @return array{name: string, phone: ?string}
     */
    private function guestFrom(array $data): array
    {
        $customer = ! empty($data['customer_id'])
            ? Customer::query()->find($data['customer_id'])
            : null;

        return [
            'name' => trim((string) ($data['guest_name'] ?? '')) ?: ($customer?->name ?? 'Client'),
            'phone' => $data['phone'] ?? $customer?->phone,
        ];
    }

    private function nextReference(string $tenantId): string
    {
        $prefix = 'RES-'.now()->year.'-';
        $last = PosReservation::query()
            ->where('tenant_id', $tenantId)
            ->where('reference', 'like', $prefix.'%')
            ->orderByDesc('reference')
            ->value('reference');
        $next = 1;
        if (is_string($last) && preg_match('/(\d+)$/', $last, $matches)) {
            $next = ((int) $matches[1]) + 1;
        }

        return $prefix.str_pad((string) $next, 4, '0', STR_PAD_LEFT);
    }

    private function syncReservationTable(?PosReservation $reservation, ?string $previousTableId): void
    {
        if ($reservation === null) {
            return;
        }

        if ($previousTableId && $previousTableId !== $reservation->table_id) {
            $previous = $reservation->replicate();
            $previous->table_id = $previousTableId;
            $this->tables->releaseReservation($previous);
        }

        if ($reservation->table_id && in_array($reservation->status, ['pending', 'confirmed'], true)) {
            $this->tables->applyReservationToTable($reservation->table_id, $reservation->store);
        }

        if ($reservation->table_id && in_array($reservation->status, ['cancelled', 'no_show', 'completed'], true)) {
            $this->tables->releaseReservation($reservation);
        }
    }
}
