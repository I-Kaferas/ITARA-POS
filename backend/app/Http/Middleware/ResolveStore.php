<?php

namespace App\Http\Middleware;

use App\Models\Store;
use App\Support\ApiError;
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
                return ApiError::json('errors.store_not_found', 404);
            }

            if (! $store->is_active) {
                return ApiError::json('errors.store_inactive', 403);
            }

            if ((string) $store->tenant_id !== (string) app('tenant.id')) {
                return ApiError::json('errors.store_forbidden', 403);
            }

            app()->instance('store', $store);
            app()->instance('store.id', $store->id);
        }

        return $next($request);
    }
}
