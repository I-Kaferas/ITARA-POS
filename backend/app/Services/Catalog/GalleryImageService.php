<?php

namespace App\Services\Catalog;

use App\Models\Catalog;
use App\Models\GalleryImage;
use App\Tenancy\TenantContext;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use InvalidArgumentException;
use RuntimeException;

class GalleryImageService
{
    public function __construct(private ProductImageService $images) {}

    public function upload(?Catalog $catalog, UploadedFile $file): GalleryImage
    {
        $this->validateFile($file);

        $tenantId = $catalog?->tenant_id ?? app(TenantContext::class)->requireId();
        $disk = $this->images->mediaDisk();
        $extension = $file->guessExtension() ?: 'jpg';
        $filename = Str::uuid()->toString().'.'.$extension;
        $storagePath = $tenantId.'/gallery/'.$filename;

        $stored = Storage::disk($disk)->put($storagePath, $file->getContent(), 'public');

        if (! $stored) {
            throw new RuntimeException('Failed to upload gallery image.');
        }

        return GalleryImage::create([
            'tenant_id' => $tenantId,
            'catalog_id' => $catalog?->id,
            'storage_path' => $storagePath,
            'cdn_url' => $this->images->buildCdnUrl($storagePath),
            'original_filename' => $file->getClientOriginalName(),
            'mime_type' => $file->getMimeType() ?? 'application/octet-stream',
            'file_size' => $file->getSize() ?: 0,
        ]);
    }

    public function delete(GalleryImage $image): void
    {
        Storage::disk($this->images->mediaDisk())->delete($image->storage_path);
        $image->delete();
    }

    private function validateFile(UploadedFile $file): void
    {
        $maxSizeKb = (int) config('media.product.max_size_kb');
        $allowedMimes = config('media.product.allowed_mimes');

        if ($file->getSize() > $maxSizeKb * 1024) {
            throw new InvalidArgumentException("Image exceeds maximum size of {$maxSizeKb} KB.");
        }

        $mime = $file->getMimeType();

        if ($mime && ! in_array($mime, $allowedMimes, true)) {
            throw new InvalidArgumentException('Unsupported image type.');
        }
    }
}
