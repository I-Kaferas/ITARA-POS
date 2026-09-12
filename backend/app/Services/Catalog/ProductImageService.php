<?php

namespace App\Services\Catalog;

use App\Models\Product;
use App\Models\ProductImage;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use InvalidArgumentException;
use RuntimeException;

class ProductImageService
{
    public function upload(Product $product, UploadedFile $file, ?bool $isPrimary = null): ProductImage
    {
        $this->validateFile($file);

        $disk = $this->mediaDisk();
        $extension = $file->guessExtension() ?: 'jpg';
        $filename = Str::uuid()->toString().'.'.$extension;
        $storagePath = $this->buildStoragePath($product, $filename);

        $stored = Storage::disk($disk)->put($storagePath, $file->getContent(), 'public');

        if (! $stored) {
            throw new RuntimeException('Failed to upload product image.');
        }

        return DB::transaction(function () use ($product, $file, $storagePath, $isPrimary): ProductImage {
            $sortOrder = (int) $product->images()->max('sort_order') + 1;
            $shouldBePrimary = $isPrimary ?? ! $product->images()->exists();

            if ($shouldBePrimary) {
                $product->images()->update(['is_primary' => false]);
            }

            return ProductImage::create([
                'tenant_id' => $product->tenant_id,
                'product_id' => $product->id,
                'storage_path' => $storagePath,
                'cdn_url' => $this->buildCdnUrl($storagePath),
                'original_filename' => $file->getClientOriginalName(),
                'mime_type' => $file->getMimeType() ?? 'application/octet-stream',
                'file_size' => $file->getSize(),
                'sort_order' => $sortOrder,
                'is_primary' => $shouldBePrimary,
            ]);
        });
    }

    public function delete(ProductImage $image): void
    {
        $wasPrimary = $image->is_primary;
        $product = $image->product;

        Storage::disk($this->mediaDisk())->delete($image->storage_path);
        if (config('media.disk') === 'local') {
            Storage::disk('local')->delete($image->storage_path);
        }
        $image->delete();

        if ($wasPrimary) {
            $nextPrimary = $product->images()->ordered()->first();
            $nextPrimary?->update(['is_primary' => true]);
        }
    }

    /**
     * @param  list<string>  $imageIds  Ordered list of image UUIDs
     */
    public function reorder(Product $product, array $imageIds): void
    {
        DB::transaction(function () use ($product, $imageIds): void {
            foreach ($imageIds as $index => $imageId) {
                $product->images()
                    ->whereKey($imageId)
                    ->update(['sort_order' => $index]);
            }
        });
    }

    public function setPrimary(ProductImage $image): void
    {
        DB::transaction(function () use ($image): void {
            $image->product->images()->update(['is_primary' => false]);
            $image->update(['is_primary' => true]);
        });
    }

    public function mediaDisk(): string
    {
        $disk = (string) config('media.disk', 'public');

        // The local disk is private and not served to the browser.
        return $disk === 'local' ? 'public' : $disk;
    }

    public function buildCdnUrl(string $storagePath): string
    {
        $disk = $this->mediaDisk();
        $driver = config("filesystems.disks.{$disk}.driver");
        $cdnBase = config('media.cdn_url');

        if ($driver === 's3' && ! empty($cdnBase)) {
            return $cdnBase.'/'.ltrim($storagePath, '/');
        }

        $url = Storage::disk('public')->url($storagePath);

        if (str_starts_with($url, 'http://') || str_starts_with($url, 'https://')) {
            return $url;
        }

        return rtrim((string) config('app.url'), '/').'/'.ltrim($url, '/');
    }

    public function publishLocalFile(string $storagePath): void
    {
        $public = storage_path('app/public/'.$storagePath);
        if (is_file($public)) {
            return;
        }

        $private = storage_path('app/private/'.$storagePath);
        if (! is_file($private)) {
            return;
        }

        $directory = dirname($public);
        if (! is_dir($directory)) {
            mkdir($directory, 0775, true);
        }

        copy($private, $public);
    }

    public function buildStoragePath(Product $product, string $filename): string
    {
        $pattern = config('media.product.path');

        return str_replace(
            ['{tenant_id}', '{product_id}'],
            [$product->tenant_id, $product->id],
            $pattern
        ).'/'.$filename;
    }

    private function validateFile(UploadedFile $file): void
    {
        $maxSizeKb = config('media.product.max_size_kb');
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
