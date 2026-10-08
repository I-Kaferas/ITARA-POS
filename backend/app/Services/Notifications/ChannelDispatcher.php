<?php

namespace App\Services\Notifications;

use App\Enums\NotificationChannel;
use App\Enums\NotificationDeliveryStatus;
use App\Enums\NotificationEvent;
use App\Jobs\DeliverNotificationJob;
use App\Mail\BusinessNotificationMail;
use App\Models\InboxNotification;
use App\Models\NotificationChannelSetting;
use App\Models\NotificationDelivery;
use App\Models\PushSubscription;
use App\Models\User;
use App\Services\Realtime\RealtimePublisher;
use App\Tenancy\TenantContext;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class ChannelDispatcher
{
    public function __construct(private readonly TenantContext $tenants) {}

    public function isOpen(NotificationChannel $channel): bool
    {
        if ($channel === NotificationChannel::Application) {
            return true;
        }

        $setting = $this->setting($channel);
        $enabled = $setting?->enabled ?? $channel === NotificationChannel::Email;
        if (! $enabled) {
            return false;
        }

        return $this->configured($channel, $setting?->config ?? []);
    }

    public function ensureOpen(NotificationChannel $channel): void
    {
        if ($this->isOpen($channel)) {
            return;
        }

        throw ValidationException::withMessages([
            'channel' => ['Activez et configurez ce canal avant un envoi d\'essai.'],
        ]);
    }

    /**
     * @param  array<string, mixed>  $context
     */
    public function queue(
        User $user,
        NotificationEvent $event,
        NotificationChannel $channel,
        string $title,
        string $body,
        array $context,
        string $fingerprint,
        bool $force = false,
    ): void {
        if (! $this->isOpen($channel)) {
            return;
        }

        $tenantId = $this->tenants->requireId();
        $title = Str::limit($title, 180, '');
        $body = Str::limit($body, 2000, '');

        $existing = NotificationDelivery::query()
            ->where('user_id', $user->id)
            ->where('channel', $channel)
            ->where('fingerprint', $fingerprint)
            ->first();

        if ($existing && ! $force && in_array($existing->status, [NotificationDeliveryStatus::Sent, NotificationDeliveryStatus::Pending], true)) {
            return;
        }

        $recipient = $this->recipient($user, $channel);
        $delivery = $existing ?? new NotificationDelivery([
            'tenant_id' => $tenantId,
            'user_id' => $user->id,
            'fingerprint' => $fingerprint,
            'channel' => $channel,
        ]);

        $delivery->fill([
            'tenant_id' => $tenantId,
            'event' => $event,
            'status' => $recipient === null ? NotificationDeliveryStatus::Skipped : NotificationDeliveryStatus::Pending,
            'recipient' => $recipient,
            'title' => $title,
            'body' => $body,
            'error' => $recipient === null ? $this->missingRecipient($channel) : null,
            'sent_at' => null,
        ]);
        $delivery->save();

        if ($recipient === null) {
            return;
        }

        if ($channel === NotificationChannel::Application) {
            $this->writeInbox($user, $event, $title, $body, $context, $fingerprint);
            $delivery->status = NotificationDeliveryStatus::Sent;
            $delivery->sent_at = now();
            $delivery->error = null;
            $delivery->save();

            return;
        }

        DeliverNotificationJob::dispatch($delivery->id);
    }

    public function deliver(string $deliveryId): void
    {
        $delivery = NotificationDelivery::query()->find($deliveryId);
        if ($delivery === null || $delivery->status === NotificationDeliveryStatus::Sent) {
            return;
        }

        try {
            $this->send($delivery);
            $delivery->status = NotificationDeliveryStatus::Sent;
            $delivery->sent_at = now();
            $delivery->error = null;
        } catch (\Throwable $exception) {
            $delivery->status = NotificationDeliveryStatus::Failed;
            $delivery->error = Str::limit($exception->getMessage(), 500, '');
        }

        $delivery->save();
    }

    /** @return list<array<string, mixed>> */
    public function describe(): array
    {
        $rows = [];
        foreach (NotificationChannel::cases() as $channel) {
            $setting = $this->setting($channel);
            $config = $setting?->config ?? [];
            $rows[] = [
                'channel' => $channel->value,
                'enabled' => $channel === NotificationChannel::Application
                    ? true
                    : ($setting?->enabled ?? $channel === NotificationChannel::Email),
                'configured' => $channel === NotificationChannel::Application || $this->configured($channel, $config),
                'locked' => $channel === NotificationChannel::Application,
                'config' => $this->mask($channel, $config),
            ];
        }

        return $rows;
    }

    /**
     * @param  array<string, mixed>  $incoming
     * @return array<string, mixed>
     */
    public function mergeConfig(NotificationChannel $channel, array $incoming, array $previous): array
    {
        $config = [];
        foreach ($channel->configKeys() as $key) {
            $value = isset($incoming[$key]) ? trim((string) $incoming[$key]) : '';
            if (in_array($key, $channel->secretKeys(), true) && ($value === '' || $value === '********')) {
                $value = (string) ($previous[$key] ?? '');
            }
            if ($value !== '') {
                $config[$key] = $value;
            }
        }

        return $config;
    }

    private function send(NotificationDelivery $delivery): void
    {
        $channel = $delivery->channel;
        $config = $this->setting($channel)?->config ?? [];
        $text = trim($delivery->title."\n".$delivery->body);

        match ($channel) {
            NotificationChannel::Email => Mail::to($delivery->recipient)->send(new BusinessNotificationMail(
                $delivery->title,
                $delivery->body,
                $this->blank($config['from_address'] ?? null),
                $this->blank($config['from_name'] ?? null),
            )),
            NotificationChannel::Sms => Http::withToken((string) ($config['api_key'] ?? ''))
                ->timeout(8)
                ->acceptJson()
                ->post((string) $config['endpoint'], [
                    'to' => $delivery->recipient,
                    'from' => (string) ($config['sender'] ?? ''),
                    'message' => $text,
                ])
                ->throw(),
            NotificationChannel::WhatsApp => Http::withToken((string) $config['access_token'])
                ->timeout(8)
                ->acceptJson()
                ->post('https://graph.facebook.com/v21.0/'.$config['phone_number_id'].'/messages', [
                    'messaging_product' => 'whatsapp',
                    'to' => preg_replace('/\D+/', '', (string) $delivery->recipient),
                    'type' => 'text',
                    'text' => ['body' => $text],
                ])
                ->throw(),
            NotificationChannel::Push => Http::withHeaders([
                'Authorization' => 'key='.$config['server_key'],
            ])->timeout(8)->acceptJson()->post('https://fcm.googleapis.com/fcm/send', [
                'registration_ids' => $this->pushTokens($delivery),
                'notification' => [
                    'title' => $delivery->title,
                    'body' => $delivery->body,
                ],
                'data' => [
                    'event' => $delivery->event->value,
                ],
            ])->throw(),
            NotificationChannel::Application => null,
        };
    }

    /** @return list<string> */
    private function pushTokens(NotificationDelivery $delivery): array
    {
        return PushSubscription::query()
            ->where('user_id', $delivery->user_id)
            ->pluck('token')
            ->all();
    }

    /**
     * @param  array<string, mixed>  $context
     */
    private function writeInbox(
        User $user,
        NotificationEvent $event,
        string $title,
        string $body,
        array $context,
        string $fingerprint,
    ): void {
        $tenantId = $this->tenants->requireId();
        $inbox = InboxNotification::query()->updateOrCreate(
            [
                'user_id' => $user->id,
                'fingerprint' => $fingerprint,
            ],
            [
                'tenant_id' => $tenantId,
                'event' => $event,
                'title' => $title,
                'body' => $body,
                'context' => $context + ['link' => $context['link'] ?? $event->link()],
            ],
        );

        if ($inbox->wasRecentlyCreated) {
            app(RealtimePublisher::class)->notify(
                'notification.created',
                $tenantId,
                isset($context['store_id']) ? (string) $context['store_id'] : null,
                'notification',
                (string) $inbox->id,
                $event->value,
                [
                    'title' => $title,
                    'user_id' => $user->id,
                    'event' => $event->value,
                ],
            );
        }
    }

    private function recipient(User $user, NotificationChannel $channel): ?string
    {
        return match ($channel) {
            NotificationChannel::Application => $user->email ?: $user->id,
            NotificationChannel::Email => $this->blank($user->email),
            NotificationChannel::Sms, NotificationChannel::WhatsApp => $this->blank($user->phone),
            NotificationChannel::Push => PushSubscription::query()->where('user_id', $user->id)->exists()
                ? 'push:'.$user->id
                : null,
        };
    }

    private function missingRecipient(NotificationChannel $channel): string
    {
        return match ($channel) {
            NotificationChannel::Email => 'Aucune adresse e-mail.',
            NotificationChannel::Sms, NotificationChannel::WhatsApp => 'Aucun numéro de téléphone.',
            NotificationChannel::Push => 'Aucun jeton push enregistré.',
            NotificationChannel::Application => 'Destinataire indisponible.',
        };
    }

    /** @param  array<string, mixed>  $config */
    private function configured(NotificationChannel $channel, array $config): bool
    {
        return match ($channel) {
            NotificationChannel::Application, NotificationChannel::Email => true,
            NotificationChannel::Sms => $this->blank($config['endpoint'] ?? null) !== null,
            NotificationChannel::WhatsApp => $this->blank($config['phone_number_id'] ?? null) !== null
                && $this->blank($config['access_token'] ?? null) !== null,
            NotificationChannel::Push => $this->blank($config['server_key'] ?? null) !== null,
        };
    }

    /**
     * @param  array<string, mixed>  $config
     * @return array<string, mixed>
     */
    private function mask(NotificationChannel $channel, array $config): array
    {
        $visible = [];
        foreach ($channel->configKeys() as $key) {
            $value = (string) ($config[$key] ?? '');
            if (in_array($key, $channel->secretKeys(), true)) {
                $visible[$key] = '';
                $visible[$key.'_set'] = $value !== '';
                continue;
            }
            $visible[$key] = $value;
        }

        return $visible;
    }

    private function setting(NotificationChannel $channel): ?NotificationChannelSetting
    {
        return $this->allSettings()->get($channel->value);
    }

    /** @return Collection<string, NotificationChannelSetting> */
    private function allSettings(): Collection
    {
        return NotificationChannelSetting::query()->get()->keyBy(
            fn (NotificationChannelSetting $setting) => $setting->channel->value,
        );
    }

    private function blank(mixed $value): ?string
    {
        $text = trim((string) $value);

        return $text === '' ? null : $text;
    }
}
