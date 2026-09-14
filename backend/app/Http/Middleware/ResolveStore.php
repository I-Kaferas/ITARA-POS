<?php

namespace App\Http\Middleware;

use App\Models\Store;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class ResolveStore
{
    public function handle(Request $request, Closure $next): Response
    {
        $storeId = $request->header('X-Store-ID');

        if ($storeId && app()->bound('tenant.id')) {
            $store = Store::query()->find($storeId);

            if ($store === null) {
                return response()->json(['message' => 'Store not found.'], 404);
            }

            if (! $store->is_active) {
                return response()->json(['message' => 'Store is not active.'], 403);
            }

            if ((string) $store->tenant_id !== (string) app('tenant.id')) {
                return response()->json(['message' => 'Forbidden store access.'], 403);
            }

            app()->instance('store', $store);
            app()->instance('store.id', $store->id);
        }

        return $next($request);
    }
}
