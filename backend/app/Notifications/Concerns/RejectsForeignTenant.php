<?php

namespace App\Notifications\Concerns;

use App\Tenancy\TenantContext;

trait RejectsForeignTenant
{
    /** @return list<string> */
    public function via($notifiable)
    {
        $owner = $notifiable->tenant_id ?? null;
        $current = app(TenantContext::class)->id();

        if (is_string($owner) && $owner !== '' && is_string($current) && $current !== '' && $owner !== $current) {
            return [];
        }

        if (is_callable([parent::class, 'via'])) {
            /** @var list<string> $channels */
            $channels = parent::via($notifiable);

            return $channels;
        }

        return ['mail'];
    }
}
