<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ExpenseCategory extends Model
{
    use BelongsToTenant, HasUuids;

    /** @var list<array{code: string, name: string, sort_order: int}> */
    public const DEFAULTS = [
        ['code' => 'transport', 'name' => 'Transport', 'sort_order' => 10],
        ['code' => 'electricity', 'name' => 'Électricité', 'sort_order' => 20],
        ['code' => 'rent', 'name' => 'Loyer', 'sort_order' => 30],
        ['code' => 'salary', 'name' => 'Salaire', 'sort_order' => 40],
        ['code' => 'urgent_purchase', 'name' => 'Achat urgent', 'sort_order' => 50],
        ['code' => 'maintenance', 'name' => 'Entretien', 'sort_order' => 60],
    ];

    protected $fillable = [
        'tenant_id',
        'code',
        'name',
        'color',
        'description',
        'is_active',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function expenses(): HasMany
    {
        return $this->hasMany(Expense::class);
    }

    public static function ensureDefaults(string $tenantId): void
    {
        foreach (self::DEFAULTS as $category) {
            self::query()->firstOrCreate(
                ['tenant_id' => $tenantId, 'code' => $category['code']],
                ['name' => $category['name'], 'sort_order' => $category['sort_order'], 'is_active' => true],
            );
        }
    }
}
