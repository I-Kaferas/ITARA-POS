<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class ProductImage extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'product_id',
        'storage_path',
        'cdn_url',
        'original_filename',
        'mime_type',
        'file_size',
        'sort_order',
        'is_primary',
        'alt_text',
    ];

    protected function casts(): array
    {
        return [
            'file_size' => 'integer',
            'sort_order' => 'integer',
            'is_primary' => 'boolean',
        ];
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function publicUrl(): string
    {
        $service = app(\App\Services\Catalog\ProductImageService::class);
        $disk = $service->mediaDisk();
        $driver = config("filesystems.disks.{$disk}.driver");

        if ($driver === 's3') {
            return (string) $this->attributes['cdn_url'];
        }

        $service->publishLocalFile($this->storage_path);

        $publicFile = storage_path('app/public/'.$this->storage_path);
        if (is_file($publicFile)) {
            return $service->buildCdnUrl($this->storage_path);
        }

        return (string) ($this->attributes['cdn_url'] ?? '');
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

    public function scopeOrdered(Builder $query): Builder
    {
        return $query->orderBy('sort_order')->orderBy('created_at');
    }

    /**
     * Payload sent to POS terminals (CDN URL only — no storage path).
     *
     * @return array{id: string, cdn_url: string, is_primary: bool, sort_order: int, alt_text: string|null}
     */
    public function toPosSyncArray(): array
    {
        return [
            'id' => $this->id,
            'cdn_url' => $this->publicUrl(),
            'is_primary' => $this->is_primary,
            'sort_order' => $this->sort_order,
            'alt_text' => $this->alt_text,
        ];
    }
}
