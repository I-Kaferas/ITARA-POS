<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tenants', function (Blueprint $table) {
            $table->string('legal_name')->nullable();
            $table->string('trade_name')->nullable();
            $table->string('logo_url')->nullable();
            $table->json('address')->nullable();
            $table->string('phone', 50)->nullable();
            $table->string('email')->nullable();
            $table->string('website')->nullable();
            $table->char('country_code', 2)->default('BI');
            $table->char('currency_code', 3)->default('FBU');
            $table->string('timezone', 64)->default('Africa/Bujumbura');
            $table->string('locale', 20)->default('fr');
            $table->string('tax_regime', 80)->nullable();
            $table->string('tax_id', 100)->nullable();
            $table->string('registration_number', 100)->nullable();
            $table->json('subscription')->nullable();
        });

        $companies = DB::table('companies')->orderBy('created_at')->get()->groupBy('tenant_id');
        foreach ($companies as $tenantId => $rows) {
            $company = $rows->first();
            $tenant = DB::table('tenants')->where('id', $tenantId)->first();
            if (! $tenant) {
                continue;
            }
            $settings = json_decode((string) ($tenant->settings ?? ''), true);
            $subscription = is_array($settings) ? ($settings['saas']['subscription'] ?? null) : null;

            DB::table('tenants')->where('id', $tenantId)->update([
                'legal_name' => $company->legal_name ?: $company->name,
                'trade_name' => $company->trade_name ?: $company->name,
                'logo_url' => $company->logo_url ?? null,
                'address' => $company->address,
                'phone' => $company->phone ?? null,
                'email' => $company->email ?? null,
                'website' => $company->website ?? null,
                'currency_code' => $company->currency_code ?: 'FBU',
                'timezone' => $company->timezone ?: 'Africa/Bujumbura',
                'locale' => $company->locale ?: 'fr',
                'tax_id' => $company->tax_id ?? null,
                'registration_number' => $company->registration_number ?? null,
                'subscription' => $subscription ? json_encode($subscription) : null,
            ]);
        }
    }

    public function down(): void
    {
        Schema::table('tenants', function (Blueprint $table) {
            $table->dropColumn([
                'legal_name',
                'trade_name',
                'logo_url',
                'address',
                'phone',
                'email',
                'website',
                'country_code',
                'currency_code',
                'timezone',
                'locale',
                'tax_regime',
                'tax_id',
                'registration_number',
                'subscription',
            ]);
        });
    }
};
