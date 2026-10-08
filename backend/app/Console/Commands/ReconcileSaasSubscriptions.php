<?php

namespace App\Console\Commands;

use App\Services\Platform\SaasSubscriptionService;
use Illuminate\Console\Command;

class ReconcileSaasSubscriptions extends Command
{
    protected $signature = 'saas:reconcile';

    protected $description = 'Apply trial expiry, renewals, scheduled downgrades, grace and suspension';

    public function handle(SaasSubscriptionService $subscriptions): int
    {
        $changed = $subscriptions->reconcileAll();
        $this->info('Reconciled '.$changed.' subscription(s).');

        return self::SUCCESS;
    }
}
