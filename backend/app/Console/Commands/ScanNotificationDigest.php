<?php

namespace App\Console\Commands;

use App\Models\Tenant;
use App\Services\Notifications\NotificationDigest;
use App\Tenancy\TenantContext;
use Illuminate\Console\Command;

class ScanNotificationDigest extends Command
{
    protected $signature = 'notifications:digest';

    protected $description = 'Create inbox notifications for orders, payments, stock, reservations, invoices, approvals, anomalies and maintenance';

    public function handle(NotificationDigest $digest, TenantContext $context): int
    {
        $count = 0;

        Tenant::query()
            ->whereIn('status', ['trial', 'active', 'past_due'])
            ->orderBy('id')
            ->each(function (Tenant $tenant) use ($digest, $context, &$count): void {
                $context->bind($tenant);
                try {
                    $digest->scan();
                    $count++;
                } finally {
                    $context->clear();
                }
            });

        $this->info('Notification digest scanned '.$count.' tenant(s).');

        return self::SUCCESS;
    }
}
