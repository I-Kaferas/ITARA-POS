<?php

namespace Tests\Feature\Settings;

use App\Models\MerchantQrCode;
use App\Models\PosTable;
use App\Tenancy\Scopes\TenantScope;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class MerchantQrTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_table_pdf_and_external_qrs_open_in_the_browser(): void
    {
        $fixture = $this->createTenantFixture('qr-web', 'qr-web@test.local');
        $table = PosTable::create([
            'tenant_id' => $fixture['tenant']->id,
            'store_id' => $fixture['store']->id,
            'name' => 'Terrace 4',
            'code' => 'T4',
            'capacity' => 4,
            'status' => 'available',
            'is_active' => true,
        ]);

        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        $companyId = $fixture['company']->id;

        $tableQr = $this->postJson("/api/v1/companies/{$companyId}/merchant-qr-codes", [
            'label' => 'Terrace 4',
            'type' => 'table',
            'table_id' => $table->id,
        ], $headers);

        $tableQr->assertCreated()
            ->assertJsonPath('data.scan', 'browser')
            ->assertJsonPath('data.service', 'web')
            ->assertJsonPath('data.company_public_id', $companyId)
            ->assertJsonPath('data.type', 'table');

        $this->assertStringEndsWith('/q/'.$tableQr->json('data.id'), $tableQr->json('data.scan_value'));

        $this->postJson("/api/v1/companies/{$companyId}/merchant-qr-codes", [
            'label' => 'Lunch PDF',
            'type' => 'pdf_menu',
            'url' => 'https://cdn.example.com/menu.pdf',
        ], $headers)->assertCreated()
            ->assertJsonPath('data.scan_value', 'https://cdn.example.com/menu.pdf')
            ->assertJsonPath('data.service', 'web');

        $this->postJson("/api/v1/companies/{$companyId}/merchant-qr-codes", [
            'label' => 'External menu',
            'type' => 'external_link',
            'url' => 'https://menu.example.com/lunch',
        ], $headers)->assertCreated()
            ->assertJsonPath('data.scan_value', 'https://menu.example.com/lunch');
    }

    public function test_pdf_menu_qr_stores_an_uploaded_file(): void
    {
        Storage::fake('public');
        $fixture = $this->createTenantFixture('qr-pdf', 'qr-pdf@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        $companyId = $fixture['company']->id;
        $pdf = "%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF\n";

        $this->postJson("/api/v1/companies/{$companyId}/merchant-qr-codes", [
            'label' => 'Missing file',
            'type' => 'pdf_menu',
        ], $headers)->assertStatus(422)->assertJsonValidationErrors(['pdf']);

        $created = $this->post("/api/v1/companies/{$companyId}/merchant-qr-codes", [
            'label' => 'Lunch menu',
            'type' => 'pdf_menu',
            'pdf' => UploadedFile::fake()->createWithContent('lunch-menu.pdf', $pdf),
        ], $headers);

        $created->assertCreated()
            ->assertJsonPath('data.scan', 'browser')
            ->assertJsonPath('data.service', 'web')
            ->assertJsonPath('data.payload.filename', 'lunch-menu.pdf');

        $path = $created->json('data.payload.storage_path');
        $this->assertIsString($path);
        Storage::disk('public')->assertExists($path);
        $this->assertStringEndsWith('.pdf', $created->json('data.scan_value'));

        $this->deleteJson('/api/v1/merchant-qr-codes/'.$created->json('data.id'), [], $headers)
            ->assertOk();

        Storage::disk('public')->assertMissing($path);
    }

    public function test_merchant_payment_and_company_qrs_are_json_for_the_mobile_app(): void
    {
        $fixture = $this->createTenantFixture('qr-app', 'qr-app@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        $companyId = $fixture['company']->id;

        $response = $this->postJson("/api/v1/companies/{$companyId}/merchant-qr-codes", [
            'label' => 'Terrace table 5',
            'type' => 'merchant',
            'display_name' => 'Main till',
        ], $headers);

        $response->assertCreated()
            ->assertJsonPath('data.scan', 'app')
            ->assertJsonPath('data.service', 'mobile')
            ->assertJsonPath('data.payload.display_name', 'Main till')
            ->assertJsonPath('data.payload.company_public_id', $companyId);

        $payload = json_decode($response->json('data.scan_value'), true);
        $this->assertSame('merchant', $payload['kind']);
        $this->assertSame($companyId, $payload['company_public_id']);
        $this->assertSame('Main till', $payload['display_name']);

        $this->postJson("/api/v1/companies/{$companyId}/merchant-qr-codes", [
            'type' => 'payment',
            'amount' => 15000,
            'currency' => 'BIF',
            'reference' => 'INV-12',
        ], $headers)->assertCreated()
            ->assertJsonPath('data.service', 'mobile')
            ->assertJsonPath('data.label', 'INV-12')
            ->assertJsonPath('data.payload.amount', '15000.00')
            ->assertJsonPath('data.payload.currency', 'BIF')
            ->assertJsonPath('data.payload.reference', 'INV-12');

        $this->postJson("/api/v1/companies/{$companyId}/merchant-qr-codes", [
            'label' => 'Profile',
            'type' => 'company',
        ], $headers)->assertCreated()->assertJsonPath('data.scan', 'app');
    }

    public function test_table_must_belong_to_the_company_and_public_scan_opens_the_table(): void
    {
        $owner = $this->createTenantFixture('qr-owner', 'qr-owner@test.local');
        $other = $this->createTenantFixture('qr-other', 'qr-other@test.local');
        $foreignTable = PosTable::create([
            'tenant_id' => $other['tenant']->id,
            'store_id' => $other['store']->id,
            'name' => 'Other',
            'code' => 'O1',
            'capacity' => 2,
            'status' => 'available',
            'is_active' => true,
        ]);

        $this->postJson("/api/v1/companies/{$owner['company']->id}/merchant-qr-codes", [
            'label' => 'Wrong table',
            'type' => 'table',
            'table_id' => $foreignTable->id,
        ], $this->tenantHeaders($owner['token'], $owner['tenant']))
            ->assertStatus(422)
            ->assertJsonValidationErrors(['table_id']);

        $table = PosTable::create([
            'tenant_id' => $owner['tenant']->id,
            'store_id' => $owner['store']->id,
            'name' => 'Salle 1',
            'code' => 'S1',
            'capacity' => 2,
            'status' => 'available',
            'is_active' => true,
        ]);

        $created = $this->postJson("/api/v1/companies/{$owner['company']->id}/merchant-qr-codes", [
            'label' => 'Salle 1',
            'type' => 'table',
            'table_id' => $table->id,
        ], $this->tenantHeaders($owner['token'], $owner['tenant']))->assertCreated();

        $this->getJson('/api/v1/public/merchant-qr/'.$created->json('data.id'))
            ->assertOk()
            ->assertJsonPath('data.table.name', 'Salle 1')
            ->assertJsonPath('data.company_name', $owner['company']->name);

        app(\App\Tenancy\TenantContext::class)->clear();

        $this->getJson(
            "/api/v1/companies/{$owner['company']->id}/merchant-qr-codes",
            $this->tenantHeaders($other['token'], $other['tenant']),
        )->assertNotFound();

        $this->assertSame(1, MerchantQrCode::query()->withoutGlobalScope(TenantScope::class)->where('company_id', $owner['company']->id)->count());
    }
}
