<?php

namespace Tests\Feature\Catalog;

use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class PublicStorageServeTest extends TestCase
{
    public function test_public_media_is_served_at_storage_without_signed_url(): void
    {
        Storage::disk('public')->put('media-probe.bin', 'itara-media');

        $this->get('/storage/media-probe.bin')->assertOk();

        Storage::disk('public')->delete('media-probe.bin');
    }

    public function test_private_disk_does_not_capture_public_storage_urls(): void
    {
        $this->get('/storage/missing-image.jpg')->assertNotFound();
    }
}
