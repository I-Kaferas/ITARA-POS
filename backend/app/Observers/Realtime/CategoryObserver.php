<?php

namespace App\Observers\Realtime;

use App\Models\Category;
use App\Services\Realtime\RealtimePublisher;

class CategoryObserver
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function created(Category $category): void
    {
        $this->publish($category, 'category.created');
    }

    public function updated(Category $category): void
    {
        $this->publish($category, 'category.updated');
    }

    private function publish(Category $category, string $type): void
    {
        $this->publisher->notify(
            type: $type,
            tenantId: $category->tenant_id,
            storeId: $category->store_id,
            entity: 'category',
            id: $category->id,
            status: $category->is_active ? 'active' : 'inactive',
            data: ['name' => $category->name],
        );
    }
}
