<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ServiceOffering extends Model
{
    use BelongsToTenant, HasUuids;

    public const CATEGORIES = ['salon', 'garage', 'repair', 'maintenance'];

    protected $fillable = [
        'tenant_id',
        'name',
        'category',
        'duration_minutes',
        'price',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'duration_minutes' => 'integer',
            'price' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    public function appointments(): HasMany
    {
        return $this->hasMany(ServiceAppointment::class);
    }
}
