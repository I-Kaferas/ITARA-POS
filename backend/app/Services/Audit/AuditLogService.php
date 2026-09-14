<?php

namespace App\Services\Audit;

use App\Models\AuditLog;
use App\Models\Device;
use App\Models\Product;
use App\Models\ProductVariant;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;

class AuditLogService
{
    /**
     * @param  array<string, mixed>|null  $payload
     */
    public function log(
        string $action,
        Model $entity,
        ?string $userId = null,
        ?array $payload = null,
        ?Request $request = null,
    ): AuditLog {
        return AuditLog::query()->create([
            'tenant_id' => $entity->getAttribute('tenant_id'),
            'user_id' => $userId,
            'action' => $action,
            'entity_type' => $entity->getMorphClass(),
            'entity_id' => $entity->getKey(),
            'payload' => $payload,
            'ip_address' => $request?->ip(),
        ]);
    }

    public function priceChanged(Product|ProductVariant $product, int $old, int $new, ?Request $request = null): void
    {
        if ($old === $new) {
            return;
        }

        $request ??= request();
        $user = $request?->user();
        $named = $product instanceof Product
            ? $product->name
            : ($product->name ?: $product->product?->name ?: $product->sku);

        $this->log('CHANGE_PRICE', $product, $user?->id, [
            'user' => $user?->name,
            'product' => $named,
            'old' => $old,
            'new' => $new,
            'device' => $this->deviceLabel($request),
        ], $request);
    }

    private function deviceLabel(?Request $request): ?string
    {
        $header = trim((string) ($request?->header('X-Device-Name') ?: $request?->header('X-Device-ID')));
        if ($header === '' || ! Schema::hasTable('devices')) {
            return $header !== '' ? $header : null;
        }

        $device = Device::query()
            ->where(function ($query) use ($header) {
                $query->where('id', $header)
                    ->orWhere('identifier', $header)
                    ->orWhere('code', $header);
            })
            ->first(['code', 'name', 'identifier']);

        return $device?->code ?: $device?->name ?: $header;
    }
}
