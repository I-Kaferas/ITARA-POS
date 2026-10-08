<?php

namespace App\Jobs;

use App\Services\Notifications\ChannelDispatcher;

class DeliverNotificationJob extends TenantAwareJob
{
    public int $tries = 1;

    public int $timeout = 20;

    public function __construct(public string $deliveryId)
    {
        parent::__construct();
    }

    public function handle(ChannelDispatcher $channels): void
    {
        $channels->deliver($this->deliveryId);
    }
}
