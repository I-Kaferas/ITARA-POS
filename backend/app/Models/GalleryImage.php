<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use App\Services\Catalog\ProductImageService;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class GalleryImage extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'catalog_id',
        'storage_path',
        'cdn_url',
        'original_filename',
        'mime_type',
        'file_size',
    ];

    protected function casts(): array
    {
        return [
            'file_size' => 'integer',
        ];
    }

    public function catalog(): BelongsTo
    {
        return $this->belongsTo(Catalog::class);
    }

    public function publicUrl(): string
    {
        $service = app(ProductImageService::class);
        $disk = $service->mediaDisk();
        $driver = config("filesystems.disks.{$disk}.driver");

        if ($driver === 's3') {
            return (string) $this->attributes['cdn_url'];
        }

        $service->publishLocalFile($this->storage_path);

        return $service->buildCdnUrl($this->storage_path);
    }

    public function getCdnUrlAttribute(?string $value): string
    {
        if ($value === null || $value === '') {
            return $this->publicUrl();
        }

        $driver = config('filesystems.disks.'.config('media.disk', 'public').'.driver');
        if ($driver === 's3') {
            return $value;
        }

        if (str_contains($value, '/storage/')) {
            return $value;
        }

        return $this->publicUrl();
    }
}
