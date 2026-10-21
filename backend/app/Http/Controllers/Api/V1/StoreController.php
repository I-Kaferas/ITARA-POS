<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Branch;
use App\Models\Catalog;
use App\Models\Store;
use App\Models\User;
use App\Services\Authorization\AuthorizationService;
use App\Services\Catalog\StoreCatalogService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class StoreController extends Controller
{
    public function __construct(
        private readonly StoreCatalogService $storeCatalogs,
    ) {}

    public function index(Branch $branch): JsonResponse
    {
        return response()->json([
            'data' => $branch->stores()->orderByDesc('is_main')->orderBy('name')->get(),
        ]);
    }

    public function indexAll(Request $request): JsonResponse
    {
        $stores = Store::query()
            ->with(['branch.company'])
            ->orderBy('name');

        $user = $request->user();
        $directory = $request->query('scope') === 'directory'
            && $user instanceof User
            && app(AuthorizationService::class)->hasPermission($user, 'users.manage');

        if (! $directory && $user instanceof User && ! $user->isSuperAdmin() && $user->stores()->exists()) {
            $stores->whereIn('id', $user->stores()->pluck('stores.id'));
        }

        return response()->json(['data' => $stores->get()]);
    }

    public function store(Request $request, Branch $branch): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'code' => ['required', 'string', 'max:50'],
            'kind' => ['nullable', 'in:store,boutique'],
            'is_active' => ['boolean'],
            'is_main' => ['boolean'],
        ]);

        $makeMain = (bool) ($data['is_main'] ?? false) || ! Store::query()->where('is_main', true)->exists();
        unset($data['is_main']);

        $store = $branch->stores()->create([
            ...$data,
            'tenant_id' => app('tenant.id'),
            'kind' => $data['kind'] ?? 'store',
            'is_active' => $data['is_active'] ?? true,
            'is_main' => false,
        ]);

        if ($makeMain) {
            $store->makeMain();
        }

        $this->storeCatalogs->bootstrap($store);

        return response()->json(['data' => $store->load('branch.company')], 201);
    }

    public function show(Store $store): JsonResponse
    {
        return response()->json(['data' => $store->load('branch.company')]);
    }

    public function update(Request $request, Store $store): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'code' => ['sometimes', 'string', 'max:50'],
            'kind' => ['sometimes', 'in:store,boutique'],
            'is_active' => ['boolean'],
            'is_main' => ['boolean'],
        ]);

        $makeMain = array_key_exists('is_main', $data) && $data['is_main'];
        unset($data['is_main']);

        $store->update($data);

        if ($makeMain) {
            $store->makeMain();
        }

        return response()->json(['data' => $store->fresh()]);
    }

    public function destroy(Store $store): JsonResponse
    {
        DB::transaction(function () use ($store) {
            $wasMain = $store->is_main;
            if ($wasMain) {
                $store->forceFill(['is_main' => false])->save();
            }
            $store->delete();

            if ($wasMain) {
                $next = Store::query()->orderBy('created_at')->orderBy('id')->first();
                $next?->makeMain();
            }
        });

        return response()->json(['message' => 'Deleted.']);
    }

    public function all(): JsonResponse
    {
        $stores = Store::query()
            ->where('is_active', true)
            ->with(['branch.company:id,name'])
            ->orderBy('name')
            ->get();

        return response()->json(['data' => $stores]);
    }
}
