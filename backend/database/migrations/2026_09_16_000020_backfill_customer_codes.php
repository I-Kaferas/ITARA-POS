<?php

use App\Models\Customer;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $tenants = DB::table('customers')
            ->where(function ($q) {
                $q->whereNull('code')->orWhere('code', '');
            })
            ->distinct()
            ->pluck('tenant_id');

        foreach ($tenants as $tenantId) {
            $tenantId = (string) $tenantId;
            $customers = Customer::withoutGlobalScopes()
                ->withTrashed()
                ->where('tenant_id', $tenantId)
                ->where(function ($q) {
                    $q->whereNull('code')->orWhere('code', '');
                })
                ->orderBy('created_at')
                ->orderBy('id')
                ->get(['id']);

            foreach ($customers as $customer) {
                DB::table('customers')
                    ->where('id', $customer->id)
                    ->update(['code' => Customer::nextCode($tenantId)]);
            }
        }
    }

    public function down(): void
    {
        // Codes are permanent identifiers; do not clear them on rollback.
    }
};
