<?php

namespace App\Services\Notifications;

use App\Enums\NotificationChannel;
use App\Enums\NotificationDeliveryStatus;
use App\Enums\NotificationEvent;
use App\Models\NotificationChannelSetting;
use App\Models\NotificationDelivery;
use App\Models\NotificationPreference;
use App\Models\PushSubscription;
use App\Models\User;
use App\Services\Authorization\AuthorizationService;
use App\Tenancy\TenantContext;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class NotificationCenter
{
    public function __construct(
        private readonly ChannelDispatcher $channels,
        private readonly TenantContext $tenants,
        private readonly AuthorizationService $authorization,
    ) {}

    /**
     * @param  array<string, mixed>  $context
     * @param  Collection<int, User>|null  $users
     * @param  list<NotificationChannel>|null  $onlyChannels
     */
    public function notify(
        NotificationEvent $event,
        string $title,
        string $body,
        array $context = [],
        ?string $fingerprint = null,
        ?Collection $users = null,
        ?array $onlyChannels = null,
        bool $force = false,
    ): void {
        if (! $this->tenants->isBound()) {
            return;
        }

        $fingerprint ??= $event->value.':'.(string) Str::uuid();
        $context += ['link' => $event->link()];
        $recipients = $users ?? User::query()->where('is_active', true)->get();

        foreach ($recipients as $user) {
            if (! $user->is_active) {
                continue;
            }

            foreach ($onlyChannels ?? $this->enabledChannels($user, $event) as $channel) {
                $this->channels->queue($user, $event, $channel, $title, $body, $context, $fingerprint, $force);
            }
        }
    }

    public function sendTest(User $user, NotificationEvent $event, NotificationChannel $channel): void
    {
        $this->channels->ensureOpen($channel);
        $fingerprint = 'test:'.(string) Str::uuid();
        $this->channels->queue(
            $user,
            $event,
            $channel,
            'Essai · '.$event->title(),
            'Message d\'essai du centre de notifications.',
            ['link' => '/admin/notifications', 'test' => true],
            $fingerprint,
            true,
        );

        $delivery = NotificationDelivery::query()->where('fingerprint', $fingerprint)->first();
        if ($delivery?->status === NotificationDeliveryStatus::Failed || $delivery?->status === NotificationDeliveryStatus::Skipped) {
            throw ValidationException::withMessages([
                'channel' => [$delivery->error ?: 'Envoi impossible.'],
            ]);
        }
    }

    public function canManage(User $user): bool
    {
        return $this->authorization->hasAnyPermission($user, ['settings.manage', 'notifications.manage']);
    }

    /**
     * @return list<array{event: string, channels: list<string>, customized: bool}>
     */
    public function rulesFor(User $user, string $scope): array
    {
        $stored = $this->storedChannels($scope === 'tenant' ? 'tenant' : $user->id);
        $tenant = $scope === 'user' ? $this->storedChannels('tenant') : [];
        $rules = [];

        foreach (NotificationEvent::cases() as $event) {
            $customized = $scope === 'user' && isset($stored[$event->value]);
            $channels = $stored[$event->value]
                ?? $tenant[$event->value]
                ?? [NotificationChannel::Application->value];

            $rules[] = [
                'event' => $event->value,
                'channels' => array_values($channels),
                'customized' => $customized,
            ];
        }

        return $rules;
    }

    /**
     * @param  list<array{event: string, channels: list<string>}>  $rules
     */
    public function saveRules(User $user, string $scope, array $rules): void
    {
        if ($scope === 'tenant' && ! $this->canManage($user)) {
            throw ValidationException::withMessages([
                'scope' => ['Seul un administrateur peut modifier le défaut de l\'entreprise.'],
            ]);
        }

        $scopeKey = $scope === 'tenant' ? 'tenant' : $user->id;
        $allowed = NotificationChannel::values();

        foreach ($rules as $rule) {
            $event = NotificationEvent::from($rule['event']);
            $channels = array_values(array_unique(array_filter(
                $rule['channels'],
                fn (string $channel) => in_array($channel, $allowed, true),
            )));

            NotificationPreference::query()->updateOrCreate(
                [
                    'tenant_id' => $this->tenants->requireId(),
                    'scope_key' => $scopeKey,
                    'event' => $event,
                ],
                [
                    'user_id' => $scope === 'tenant' ? null : $user->id,
                    'channels' => $channels,
                ],
            );
        }
    }

    public function resetUserRules(User $user): void
    {
        NotificationPreference::query()->where('scope_key', $user->id)->delete();
    }

    /**
     * @param  array<string, mixed>  $config
     */
    public function saveChannel(NotificationChannel $channel, bool $enabled, array $config): NotificationChannelSetting
    {
        if ($channel === NotificationChannel::Application) {
            throw ValidationException::withMessages([
                'channel' => ['Le canal application est toujours disponible.'],
            ]);
        }

        $current = NotificationChannelSetting::query()->where('channel', $channel)->first();
        $merged = $this->channels->mergeConfig($channel, $config, $current?->config ?? []);

        return NotificationChannelSetting::query()->updateOrCreate(
            [
                'tenant_id' => $this->tenants->requireId(),
                'channel' => $channel,
            ],
            [
                'enabled' => $enabled,
                'config' => $merged,
            ],
        );
    }

    public function registerPushToken(User $user, string $token, string $platform): PushSubscription
    {
        return PushSubscription::query()->updateOrCreate(
            [
                'user_id' => $user->id,
                'token' => $token,
            ],
            [
                'tenant_id' => $this->tenants->requireId(),
                'platform' => $platform,
            ],
        );
    }

    public function removePushToken(User $user, string $token): void
    {
        PushSubscription::query()
            ->where('user_id', $user->id)
            ->where('token', $token)
            ->delete();
    }

    /** @return list<NotificationChannel> */
    private function enabledChannels(User $user, NotificationEvent $event): array
    {
        $selected = $this->storedChannels($user->id)[$event->value]
            ?? $this->storedChannels('tenant')[$event->value]
            ?? [NotificationChannel::Application->value];

        return array_values(array_filter(array_map(
            fn (string $value) => NotificationChannel::tryFrom($value),
            $selected,
        )));
    }

    /**
     * @return array<string, list<string>>
     */
    private function storedChannels(string $scopeKey): array
    {
        return NotificationPreference::query()
            ->where('scope_key', $scopeKey)
            ->get()
            ->mapWithKeys(fn (NotificationPreference $preference) => [
                $preference->event->value => array_values($preference->channels ?? []),
            ])
            ->all();
    }
}
