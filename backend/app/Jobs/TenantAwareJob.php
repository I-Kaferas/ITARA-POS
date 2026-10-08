<?php

namespace App\Jobs;

use App\Tenancy\BindTenant;
use App\Tenancy\TenantContext;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

abstract class TenantAwareJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public ?string $tenantId;

    public function __construct()
    {
        $this->tenantId = app(TenantContext::class)->id();
    }

    /** @return list<object> */
    public function middleware(): array
    {
        return [new BindTenant];
    }
}
