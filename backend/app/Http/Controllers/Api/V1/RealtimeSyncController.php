<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\RealtimeOutbox;
use App\Services\Realtime\ChannelAuthorizer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RealtimeSyncController extends Controller
{
    public function __construct(private readonly ChannelAuthorizer $channels) {}

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $tenantId = (string) $request->header('X-Tenant-ID', '');

        if ($user === null || ! $this->channels->allowsTenant($user, $tenantId)) {
            abort(403);
        }

        $since = $request->query('since');
        $query = RealtimeOutbox::query()
            ->where('tenant_id', $tenantId)
            ->orderBy('occurred_at')
            ->limit(200);

        if (is_string($since) && $since !== '') {
            $query->where('occurred_at', '>', $since);
        }

        $storeIds = $this->channels->allowedStoreIds($user, $tenantId);
        if ($storeIds !== null) {
            $query->where(function ($builder) use ($storeIds) {
                $builder->whereNull('store_id')->orWhereIn('store_id', $storeIds);
            });
        }

        $requestedStore = $request->query('store_id');
        if (is_string($requestedStore) && $requestedStore !== '') {
            if ($storeIds !== null && ! in_array($requestedStore, $storeIds, true)) {
                abort(403);
            }
            $query->where(function ($builder) use ($requestedStore) {
                $builder->whereNull('store_id')->orWhere('store_id', $requestedStore);
            });
        }

        $events = $query->get()->map(fn (RealtimeOutbox $event) => $event->envelope())->values();

        return response()->json([
            'data' => $events,
            'latest_at' => $events->last()['occurred_at'] ?? null,
        ]);
    }
}
