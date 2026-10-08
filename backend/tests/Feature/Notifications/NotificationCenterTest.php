<?php

namespace Tests\Feature\Notifications;

use App\Enums\InventoryAlertStatus;
use App\Enums\InventoryAlertType;
use App\Events\SaleCompleted;
use App\Mail\BusinessNotificationMail;
use App\Models\InventoryAlert;
use App\Models\NotificationChannelSetting;
use App\Models\Sale;
use App\Models\User;
use App\Services\Auth\AuthTokenService;
use App\Tenancy\TenantContext;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Mail;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class NotificationCenterTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_low_stock_is_delivered_to_the_inbox(): void
    {
        $fixture = $this->createTenantFixture('alerts', 'alerts@test.local');
        app(TenantContext::class)->bind($fixture['tenant']);
        InventoryAlert::create([
            'tenant_id' => $fixture['tenant']->id,
            'product_id' => $fixture['product']->id,
            'alert_type' => InventoryAlertType::LowStock,
            'status' => InventoryAlertStatus::Active,
            'quantity_on_hand' => 2,
            'threshold_value' => 5,
        ]);

        $response = $this->getJson(
            '/api/v1/notification-center',
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
        );

        $response->assertOk()
            ->assertJsonPath('data.0.event', 'low_stock')
            ->assertJsonPath('data.0.title', 'Product alerts')
            ->assertJsonPath('meta.unread', 1);
    }

    public function test_a_completed_sale_creates_an_order_notification(): void
    {
        $fixture = $this->createTenantFixture('orders', 'orders@test.local');
        app(TenantContext::class)->bind($fixture['tenant']);
        $sale = Sale::create([
            'tenant_id' => $fixture['tenant']->id,
            'store_id' => $fixture['store']->id,
            'reference' => 'CMD-100',
            'status' => 'completed',
            'total' => 2500,
            'paid_amount' => 2500,
        ]);

        SaleCompleted::dispatch($sale);

        $this->assertDatabaseHas('inbox_notifications', [
            'user_id' => $fixture['user']->id,
            'event' => 'new_order',
            'fingerprint' => 'new_order:'.$sale->id,
            'title' => 'Nouvelle commande',
        ]);
    }

    public function test_a_user_can_mute_an_event(): void
    {
        $fixture = $this->createTenantFixture('mute', 'mute@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $this->putJson('/api/v1/notification-center/preferences', [
            'scope' => 'user',
            'rules' => [
                ['event' => 'new_order', 'channels' => []],
            ],
        ], $headers)->assertOk()->assertJsonPath('data.0.channels', []);

        app(TenantContext::class)->bind($fixture['tenant']);
        $sale = Sale::create([
            'tenant_id' => $fixture['tenant']->id,
            'store_id' => $fixture['store']->id,
            'reference' => 'CMD-MUTE',
            'status' => 'completed',
            'total' => 1000,
        ]);
        SaleCompleted::dispatch($sale);

        $this->assertDatabaseMissing('inbox_notifications', [
            'fingerprint' => 'new_order:'.$sale->id,
        ]);
    }

    public function test_email_sms_whatsapp_and_push_can_deliver_a_test(): void
    {
        Mail::fake();
        Http::fake(['*' => Http::response(['ok' => true], 200)]);

        $fixture = $this->createTenantFixture('channels', 'channels@test.local');
        $fixture['user']->update(['phone' => '+25779000000']);
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $this->postJson('/api/v1/notification-center/test', [
            'event' => 'payment',
            'channel' => 'email',
        ], $headers)->assertOk();

        Mail::assertSent(BusinessNotificationMail::class, function (BusinessNotificationMail $mail) use ($fixture) {
            return $mail->hasTo('channels@test.local') && $mail->headline === 'Essai · Paiement';
        });

        $this->putJson('/api/v1/notification-center/channels/sms', [
            'enabled' => true,
            'config' => [
                'endpoint' => 'https://sms.test/send',
                'api_key' => 'sms-secret',
                'sender' => 'ITARA',
            ],
        ], $headers)->assertOk()->assertJsonPath('data.config.api_key', '')->assertJsonPath('data.config.api_key_set', true);

        $this->postJson('/api/v1/notification-center/test', [
            'event' => 'payment',
            'channel' => 'sms',
        ], $headers)->assertOk();

        $this->putJson('/api/v1/notification-center/channels/whatsapp', [
            'enabled' => true,
            'config' => [
                'phone_number_id' => '12345',
                'access_token' => 'wa-secret',
            ],
        ], $headers)->assertOk();

        $this->postJson('/api/v1/notification-center/test', [
            'event' => 'reservation',
            'channel' => 'whatsapp',
        ], $headers)->assertOk();

        $this->postJson('/api/v1/notification-center/push-tokens', [
            'token' => 'device-token-1',
            'platform' => 'android',
        ], $headers)->assertCreated();

        $this->putJson('/api/v1/notification-center/channels/push', [
            'enabled' => true,
            'config' => ['server_key' => 'fcm-secret'],
        ], $headers)->assertOk();

        $this->postJson('/api/v1/notification-center/test', [
            'event' => 'maintenance',
            'channel' => 'push',
        ], $headers)->assertOk();

        Http::assertSent(fn ($request) => $request->url() === 'https://sms.test/send'
            && $request['to'] === '+25779000000'
            && $request['from'] === 'ITARA');
        Http::assertSent(fn ($request) => str_contains($request->url(), 'graph.facebook.com')
            && $request['to'] === '25779000000');
        Http::assertSent(fn ($request) => $request->url() === 'https://fcm.googleapis.com/fcm/send'
            && $request['registration_ids'] === ['device-token-1']);

        $this->assertSame('sms-secret', NotificationChannelSetting::query()->where('channel', 'sms')->first()->config['api_key']);
        $this->assertSame('wa-secret', NotificationChannelSetting::query()->where('channel', 'whatsapp')->first()->config['access_token']);
    }

    public function test_an_unconfigured_channel_cannot_send_a_test(): void
    {
        $fixture = $this->createTenantFixture('nosms', 'nosms@test.local');

        $this->postJson('/api/v1/notification-center/test', [
            'event' => 'anomaly',
            'channel' => 'sms',
        ], $this->tenantHeaders($fixture['token'], $fixture['tenant']))
            ->assertStatus(422)
            ->assertJsonValidationErrors(['channel']);
    }

    public function test_notifications_stay_inside_the_tenant(): void
    {
        $alpha = $this->createTenantFixture('alpha-note', 'alpha-note@test.local');
        $beta = $this->createTenantFixture('beta-note', 'beta-note@test.local');
        app(TenantContext::class)->bind($alpha['tenant']);
        InventoryAlert::create([
            'tenant_id' => $alpha['tenant']->id,
            'product_id' => $alpha['product']->id,
            'alert_type' => InventoryAlertType::OutOfStock,
            'status' => InventoryAlertStatus::Active,
            'quantity_on_hand' => 0,
        ]);
        app(TenantContext::class)->clear();

        $this->getJson('/api/v1/notification-center', $this->tenantHeaders($beta['token'], $beta['tenant']))
            ->assertOk()
            ->assertJsonPath('meta.total', 0);

        $this->getJson('/api/v1/notification-center', $this->tenantHeaders($alpha['token'], $alpha['tenant']))
            ->assertOk()
            ->assertJsonPath('data.0.title', 'Product alpha-note');
    }

    public function test_only_the_recipient_can_mark_a_notification_read(): void
    {
        $fixture = $this->createTenantFixture('readers', 'readers@test.local');
        app(TenantContext::class)->bind($fixture['tenant']);
        InventoryAlert::create([
            'tenant_id' => $fixture['tenant']->id,
            'product_id' => $fixture['product']->id,
            'alert_type' => InventoryAlertType::LowStock,
            'status' => InventoryAlertStatus::Active,
            'quantity_on_hand' => 1,
        ]);

        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        $id = $this->getJson('/api/v1/notification-center', $headers)->json('data.0.id');

        $other = User::create([
            'tenant_id' => $fixture['tenant']->id,
            'name' => 'Other',
            'email' => 'other-readers@test.local',
            'password' => Hash::make('password'),
            'is_active' => true,
        ]);
        $otherToken = app(AuthTokenService::class)->issue($other)['access_token'];

        $this->postJson(
            '/api/v1/notification-center/'.$id.'/read',
            [],
            $this->tenantHeaders($otherToken, $fixture['tenant']),
        )->assertNotFound();

        $read = $this->postJson('/api/v1/notification-center/'.$id.'/read', [], $headers)->assertOk();
        $this->assertNotNull($read->json('data.read_at'));

        $this->postJson('/api/v1/notification-center/read-all', [], $headers)
            ->assertOk()
            ->assertJsonPath('data.unread', 0);
    }

    public function test_channel_settings_require_an_administrator(): void
    {
        $fixture = $this->createTenantFixture('staff', 'staff@test.local');
        $staff = User::create([
            'tenant_id' => $fixture['tenant']->id,
            'name' => 'Cashier',
            'email' => 'cashier-staff@test.local',
            'password' => Hash::make('password'),
            'is_active' => true,
        ]);
        $headers = $this->tenantHeaders(
            app(AuthTokenService::class)->issue($staff)['access_token'],
            $fixture['tenant'],
        );

        $this->getJson('/api/v1/notification-center', $headers)->assertOk();
        $this->putJson('/api/v1/notification-center/channels/email', [
            'enabled' => true,
            'config' => [],
        ], $headers)->assertForbidden();
    }
}
