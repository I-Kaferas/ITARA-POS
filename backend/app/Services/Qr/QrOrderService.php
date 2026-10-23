<?php

namespace App\Services\Qr;

use App\DTOs\Cart\CalculatedCartLine;
use App\Enums\CashierShiftStatus;
use App\Enums\PosTableStatus;
use App\Enums\QrOrderStatus;
use App\Enums\QrSessionStatus;
use App\Enums\SaleStatus;
use App\Models\CashierShift;
use App\Models\DeskDocument;
use App\Models\PosTable;
use App\Models\Product;
use App\Models\ProductAccompanimentLink;
use App\Models\QrOrder;
use App\Models\QrOrderItem;
use App\Models\QrTableSession;
use App\Models\Sale;
use App\Models\StockBalance;
use App\Models\Store;
use App\Models\StoreProduct;
use App\Models\TableQrToken;
use App\Models\User;
use App\Models\Warehouse;
use App\Services\Audit\AuditLogService;
use App\Services\Desk\HospitalityDesk;
use App\Services\Realtime\RealtimePublisher;
use App\Services\Sales\CartEngine;
use App\Services\Sales\SaleEngine;
use App\Support\QrCodeSvg;
use App\Tenancy\Scopes\TenantScope;
use App\Tenancy\TenantContext;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use InvalidArgumentException;

class QrOrderService
{
    public const MAX_QTY = 20;

    public const MAX_LINES = 40;

    public function __construct(
        private readonly CartEngine $cartEngine,
        private readonly SaleEngine $saleEngine,
        private readonly HospitalityDesk $kitchen,
        private readonly AuditLogService $audit,
        private readonly RealtimePublisher $realtime,
        private readonly TenantContext $tenants,
    ) {}

    public function findToken(string $token): ?TableQrToken
    {
        $token = trim($token);
        if ($token === '') {
            return null;
        }

        return TableQrToken::query()
            ->withoutGlobalScope(TenantScope::class)
            ->where('token', $token)
            ->first();
    }

    /** @return array<string, mixed> */
    public function menu(TableQrToken $token): array
    {
        return $this->tenants->runAs($token->tenant_id, function () use ($token): array {
            $token->loadMissing('table.store.branch.company');
            $table = $this->requireTable($token);
            $store = $table->store;
            $gate = $this->orderingGate($token, $table);
            $session = $this->openSession($table);

            return [
                'restaurant' => $store->branch?->company?->name ?: $store->name,
                'logo_url' => $store->branch?->company?->logo_url,
                'table' => [
                    'name' => $table->name,
                    'code' => $table->code,
                ],
                'currency' => $store->branch?->company?->currency_code ?: 'FBU',
                'ordering_open' => $gate['open'],
                'ordering_message' => $gate['message'],
                'cashier_present' => $this->cashierPresent($store),
                'approval_mode' => $store->qr_approval_mode ?: 'manual',
                'categories' => $this->categories($store),
                'orders' => $session
                    ? $session->orders->map(fn (QrOrder $order) => $this->presentGuest($order))->values()->all()
                    : [],
            ];
        }) ?? throw ValidationException::withMessages([
            'table' => ['Ce QR code est invalide ou désactivé.'],
        ]);
    }

    /** @param  array<string, mixed>  $payload */
    public function submit(TableQrToken $token, array $payload): QrOrder
    {
        $order = $this->tenants->runAs($token->tenant_id, function () use ($token, $payload): QrOrder {
            $token->loadMissing('table.store');
            $table = $this->requireTable($token);
            $store = $table->store;
            $gate = $this->orderingGate($token, $table);
            if (! $gate['open']) {
                throw ValidationException::withMessages(['table' => [$gate['message']]]);
            }

            $key = trim((string) ($payload['idempotency_key'] ?? ''));
            if ($key === '') {
                throw ValidationException::withMessages([
                    'idempotency_key' => ['La clé d’idempotence est obligatoire.'],
                ]);
            }

            $existing = QrOrder::query()
                ->where('store_id', $store->id)
                ->where('idempotency_key', $key)
                ->first();
            if ($existing !== null) {
                return $existing->load('items', 'table');
            }

            $priced = $this->priceLines($store, $payload['items'] ?? []);

            try {
                return DB::transaction(function () use ($token, $table, $store, $payload, $key, $priced): QrOrder {
                    $again = QrOrder::query()
                        ->where('store_id', $store->id)
                        ->where('idempotency_key', $key)
                        ->lockForUpdate()
                        ->first();
                    if ($again !== null) {
                        return $again->load('items', 'table');
                    }

                    $session = $this->openOrCreateSession($table);
                    $order = QrOrder::query()->create([
                        'tenant_id' => $store->tenant_id,
                        'store_id' => $store->id,
                        'pos_table_id' => $table->id,
                        'session_id' => $session->id,
                        'source' => 'qr_client',
                        'status' => QrOrderStatus::Submitted,
                        'guest_locale' => $this->locale($payload['locale'] ?? null),
                        'idempotency_key' => $key,
                        'subtotal' => $priced['subtotal'],
                        'tax_total' => $priced['tax_total'],
                        'total' => $priced['total'],
                        'currency' => $priced['currency'],
                    ]);

                    foreach ($priced['lines'] as $index => $line) {
                        QrOrderItem::query()->create([
                            'tenant_id' => $store->tenant_id,
                            'qr_order_id' => $order->id,
                            'sort_order' => $index,
                            ...$line,
                        ]);
                    }

                    $order = $order->fresh(['items', 'table']);
                    $this->audit->log('qr_order.submitted', $order, null, [
                        'table' => $table->name,
                        'total' => $order->total,
                    ]);
                    $this->notify($store, 'qr.order.submitted', $order);

                    if (($store->qr_approval_mode ?: 'manual') === 'automatic') {
                        $user = $this->automaticApprover($store);
                        if ($user !== null) {
                            return $this->approveLocked($order, $user);
                        }
                    }

                    return $order;
                });
            } catch (UniqueConstraintViolationException) {
                return QrOrder::query()
                    ->where('store_id', $store->id)
                    ->where('idempotency_key', $key)
                    ->firstOrFail()
                    ->load('items', 'table');
            }
        });

        if (! $order instanceof QrOrder) {
            throw ValidationException::withMessages([
                'table' => ['Ce QR code est invalide ou désactivé.'],
            ]);
        }

        return $order;
    }

    /** @return array<string, mixed> */
    public function show(TableQrToken $token, string $orderId): array
    {
        $presented = $this->tenants->runAs($token->tenant_id, function () use ($token, $orderId): array {
            $order = $this->orderForToken($token, $orderId);

            return $this->presentGuest($order);
        });

        if (! is_array($presented)) {
            throw ValidationException::withMessages([
                'table' => ['Ce QR code est invalide ou désactivé.'],
            ]);
        }

        return $presented;
    }

    public function cancel(TableQrToken $token, string $orderId): QrOrder
    {
        $order = $this->tenants->runAs($token->tenant_id, function () use ($token, $orderId): QrOrder {
            return DB::transaction(function () use ($token, $orderId): QrOrder {
                $order = $this->orderForToken($token, $orderId, lock: true);
                $this->assertSubmitted($order);
                $order->update(['status' => QrOrderStatus::Cancelled]);
                $order = $order->fresh(['items', 'table']);
                $this->audit->log('qr_order.cancelled', $order, null, ['by' => 'guest']);
                $this->notify($order->table->store, 'qr.order.cancelled', $order);

                return $order;
            });
        });

        return $order instanceof QrOrder ? $order : throw ValidationException::withMessages([
            'table' => ['Ce QR code est invalide ou désactivé.'],
        ]);
    }

    /** @param  array<string, mixed>  $payload */
    public function updateGuest(TableQrToken $token, string $orderId, array $payload): QrOrder
    {
        $order = $this->tenants->runAs($token->tenant_id, function () use ($token, $orderId, $payload): QrOrder {
            $token->loadMissing('table.store');
            $store = $this->requireTable($token)->store;
            $priced = $this->priceLines($store, $payload['items'] ?? []);

            return DB::transaction(function () use ($token, $orderId, $priced): QrOrder {
                $order = $this->orderForToken($token, $orderId, lock: true);
                $this->assertSubmitted($order);
                $this->replaceLines($order, $priced);
                $this->audit->log('qr_order.updated', $order, null, ['by' => 'guest', 'total' => $order->total]);
                $this->notify($order->table->store, 'qr.order.updated', $order);

                return $order->fresh(['items', 'table']);
            });
        });

        return $order instanceof QrOrder ? $order : throw ValidationException::withMessages([
            'table' => ['Ce QR code est invalide ou désactivé.'],
        ]);
    }

    /** @return list<array<string, mixed>> */
    public function listForCashier(Store $store, ?string $status = null): array
    {
        $query = QrOrder::query()
            ->with(['items', 'table:id,name,code,status', 'approver:id,name'])
            ->where('store_id', $store->id)
            ->orderByDesc('created_at');

        if ($status !== null && $status !== '' && $status !== 'all') {
            $query->where('status', $status);
        } else {
            $query->where('status', QrOrderStatus::Submitted);
        }

        return $query->limit(100)->get()->map(fn (QrOrder $order) => $this->presentCashier($order))->all();
    }

    public function pendingCount(Store $store): int
    {
        return QrOrder::query()
            ->where('store_id', $store->id)
            ->where('status', QrOrderStatus::Submitted)
            ->count();
    }

    public function approve(QrOrder $order, User $user): QrOrder
    {
        return DB::transaction(function () use ($order, $user): QrOrder {
            $locked = QrOrder::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();

            return $this->approveLocked($locked, $user);
        });
    }

    public function reject(QrOrder $order, User $user, string $reason): QrOrder
    {
        $reason = trim($reason);
        if ($reason === '') {
            throw ValidationException::withMessages([
                'reason' => ['Indiquez le motif du refus.'],
            ]);
        }

        return DB::transaction(function () use ($order, $user, $reason): QrOrder {
            $locked = QrOrder::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();
            $this->assertSubmitted($locked);
            $locked->update([
                'status' => QrOrderStatus::Rejected,
                'rejection_reason' => $reason,
                'rejected_by' => $user->id,
                'rejected_at' => now(),
            ]);
            $locked = $locked->fresh(['items', 'table']);
            $this->audit->log('qr_order.rejected', $locked, $user->id, ['reason' => $reason]);
            $this->notify($locked->table->store, 'qr.order.rejected', $locked);

            return $locked;
        });
    }

    /** @param  list<array<string, mixed>>  $items */
    public function updateByCashier(QrOrder $order, User $user, array $items): QrOrder
    {
        $order->loadMissing('table.store');
        $priced = $this->priceLines($order->table->store, $items);

        return DB::transaction(function () use ($order, $user, $priced): QrOrder {
            $locked = QrOrder::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();
            $this->assertSubmitted($locked);
            $this->replaceLines($locked, $priced);
            $this->audit->log('qr_order.updated', $locked, $user->id, ['by' => 'cashier', 'total' => $locked->total]);
            $this->notify($locked->table->store, 'qr.order.updated', $locked);

            return $locked->fresh(['items', 'table', 'approver']);
        });
    }

    public function approveAll(Store $store, User $user): int
    {
        $ids = QrOrder::query()
            ->where('store_id', $store->id)
            ->where('status', QrOrderStatus::Submitted)
            ->orderBy('created_at')
            ->pluck('id');

        $count = 0;
        foreach ($ids as $id) {
            $order = QrOrder::query()->find($id);
            if ($order === null) {
                continue;
            }
            $this->approve($order, $user);
            $count++;
        }

        return $count;
    }

    public function issueToken(PosTable $table, bool $rotate = false): TableQrToken
    {
        return DB::transaction(function () use ($table, $rotate): TableQrToken {
            $current = TableQrToken::query()
                ->where('pos_table_id', $table->id)
                ->where('is_active', true)
                ->lockForUpdate()
                ->first();

            if ($current !== null && ! $rotate) {
                return $current;
            }

            if ($current !== null) {
                $current->update(['is_active' => false]);
            }

            $created = TableQrToken::query()->create([
                'tenant_id' => $table->tenant_id,
                'store_id' => $table->store_id,
                'pos_table_id' => $table->id,
                'token' => bin2hex(random_bytes(32)),
                'is_active' => true,
            ]);

            $this->audit->log($rotate ? 'qr_token.rotated' : 'qr_token.created', $created, auth()->id(), [
                'table' => $table->name,
            ]);

            return $created;
        });
    }

    public function setTokenActive(TableQrToken $token, bool $active): TableQrToken
    {
        if ($active) {
            TableQrToken::query()
                ->where('pos_table_id', $token->pos_table_id)
                ->where('id', '!=', $token->id)
                ->update(['is_active' => false]);
        }

        $token->update(['is_active' => $active]);
        $this->audit->log('qr_token.toggled', $token, auth()->id(), ['active' => $active]);

        return $token->fresh();
    }

    /** @return list<array<string, mixed>> */
    public function tokensForStore(Store $store): array
    {
        $tables = PosTable::query()
            ->with(['zone:id,name'])
            ->where('store_id', $store->id)
            ->orderBy('name')
            ->get();

        $tokens = TableQrToken::query()
            ->where('store_id', $store->id)
            ->where('is_active', true)
            ->get()
            ->keyBy('pos_table_id');

        return $tables->map(function (PosTable $table) use ($tokens): array {
            $token = $tokens->get($table->id);

            return [
                'table_id' => $table->id,
                'name' => $table->name,
                'code' => $table->code,
                'status' => $table->status->value,
                'zone' => $table->zone?->name,
                'token_id' => $token?->id,
                'active' => (bool) $token?->is_active,
                'order_url' => $token ? $this->orderUrl($token) : null,
            ];
        })->all();
    }

    public function setApprovalMode(Store $store, string $mode): Store
    {
        if (! in_array($mode, ['manual', 'automatic'], true)) {
            throw ValidationException::withMessages([
                'mode' => ['Choisissez manual ou automatic.'],
            ]);
        }

        $store->update(['qr_approval_mode' => $mode]);
        $this->audit->log('qr_settings.updated', $store, auth()->id(), ['qr_approval_mode' => $mode]);

        return $store;
    }

    public function orderUrl(TableQrToken $token): string
    {
        return rtrim((string) config('app.frontend_url'), '/').'/order?table='.$token->token;
    }

    public function svg(TableQrToken $token): string
    {
        return QrCodeSvg::render($this->orderUrl($token));
    }

    public function closeSessionsForTable(string $tableId): void
    {
        QrTableSession::query()
            ->where('pos_table_id', $tableId)
            ->where('status', QrSessionStatus::Open)
            ->update([
                'status' => QrSessionStatus::Closed->value,
                'closed_at' => now(),
            ]);
    }

    private function approveLocked(QrOrder $order, User $user): QrOrder
    {
        $order->loadMissing('items', 'table.store', 'session');
        if ($order->status === QrOrderStatus::Approved) {
            return $order;
        }
        $this->assertSubmitted($order);

        $table = $order->table;
        $store = $table->store;
        if (! $table->is_active || in_array($table->status, [PosTableStatus::Inactive, PosTableStatus::Cleaning], true)) {
            throw ValidationException::withMessages([
                'table' => ['La table est fermée. Refusez la commande ou rouvrez la table.'],
            ]);
        }
        $priced = $this->priceLines($store, $this->guestPayloadFromStored($order));
        $this->replaceLines($order, $priced);
        $order->load('items');

        $flat = $this->flatFromStored($order);
        $sale = $this->openSale($table);
        if ($sale !== null) {
            $sale->loadMissing('items');
            $existing = $sale->items->map(fn ($item) => array_filter([
                'product_id' => $item->product_id,
                'product_variant_id' => $item->product_variant_id,
                'sale_unit_id' => $item->sale_unit_id,
                'quantity' => $item->quantity,
                'unit_price' => $item->unit_price,
                'is_accompaniment' => (bool) $item->is_accompaniment,
            ], fn ($value) => $value !== null && $value !== false))->all();

            $this->saleEngine->updateHold($sale, [
                'items' => array_merge($existing, $flat),
                'customer_id' => $sale->customer_id,
                'notes' => $sale->notes,
                'table_id' => $table->id,
            ], $user);
        } else {
            $sale = $this->saleEngine->hold($store, [
                'items' => $flat,
                'table_id' => $table->id,
                'source' => 'qr_client',
                'notes' => 'Commande QR · '.$table->name,
                'idempotency_key' => 'qr-sale-'.$order->id,
            ], $user);
        }

        $ticket = $this->kitchen->receiveQrTicket(
            $store,
            $table->name,
            $order->session_id,
            $order->id,
            $this->kitchenLines($order),
        );

        $order->update([
            'status' => QrOrderStatus::Approved,
            'sale_id' => $sale->id,
            'approved_by' => $user->id,
            'approved_at' => now(),
            'kitchen_ticket_code' => $ticket,
        ]);
        $order->session?->update(['sale_id' => $sale->id]);

        $order = $order->fresh(['items', 'table', 'approver']);
        $this->audit->log('qr_order.approved', $order, $user->id, [
            'sale_id' => $sale->id,
            'reference' => $sale->reference,
            'ticket' => $ticket,
        ]);
        $this->notify($store, 'qr.order.approved', $order);

        return $order;
    }

    private function openSale(PosTable $table): ?Sale
    {
        $table->refresh();
        if (! $table->currentSaleIsOpen()) {
            return null;
        }

        $sale = $table->currentSale ?? Sale::query()->find($table->current_sale_id);

        return $sale !== null && $sale->status === SaleStatus::Pending ? $sale : null;
    }

    /** @param  array{lines: list<array<string, mixed>>, subtotal: int, tax_total: int, total: int, currency: string}  $priced */
    private function replaceLines(QrOrder $order, array $priced): void
    {
        $order->items()->delete();
        foreach ($priced['lines'] as $index => $line) {
            QrOrderItem::query()->create([
                'tenant_id' => $order->tenant_id,
                'qr_order_id' => $order->id,
                'sort_order' => $index,
                ...$line,
            ]);
        }
        $order->update([
            'subtotal' => $priced['subtotal'],
            'tax_total' => $priced['tax_total'],
            'total' => $priced['total'],
            'currency' => $priced['currency'],
        ]);
    }

    /**
     * Prix, taxes et stock sont relus côté serveur. Les montants du client sont ignorés.
     *
     * @param  list<mixed>  $rawLines
     * @return array{lines: list<array<string, mixed>>, subtotal: int, tax_total: int, total: int, currency: string}
     */
    private function priceLines(Store $store, array $rawLines): array
    {
        if ($rawLines === []) {
            throw ValidationException::withMessages([
                'items' => ['Ajoutez au moins un article.'],
            ]);
        }
        if (count($rawLines) > self::MAX_LINES) {
            throw ValidationException::withMessages([
                'items' => ['Maximum '.self::MAX_LINES.' articles par commande.'],
            ]);
        }

        $guestLines = [];
        foreach ($rawLines as $index => $raw) {
            if (! is_array($raw)) {
                throw ValidationException::withMessages([
                    "items.$index" => ['Article invalide.'],
                ]);
            }
            $guestLines[] = $this->normalizeGuestLine($raw, $index);
        }

        $productIds = [];
        foreach ($guestLines as $line) {
            $productIds[] = $line['product_id'];
            foreach ($line['side_ids'] as $id) {
                $productIds[] = $id;
            }
            foreach ($line['extras'] as $extra) {
                $productIds[] = $extra['product_id'];
            }
        }

        $storeProducts = StoreProduct::query()
            ->where('store_id', $store->id)
            ->whereIn('product_id', array_unique($productIds))
            ->where('is_available', true)
            ->with(['product.variants', 'product.saleUnits'])
            ->get()
            ->keyBy('product_id');

        $links = ProductAccompanimentLink::query()
            ->whereIn('product_id', array_column($guestLines, 'product_id'))
            ->get()
            ->groupBy('product_id');

        $flat = [];
        $spans = [];
        $stock = [];

        foreach ($guestLines as $index => $line) {
            $main = $storeProducts->get($line['product_id']);
            if ($main === null || $main->product === null || ! $main->product->is_active) {
                throw ValidationException::withMessages([
                    "items.$index" => ['Cet article n’est plus disponible.'],
                ]);
            }
            $product = $main->product;
            if ($line['variant_id'] !== null && $product->variants->firstWhere('id', $line['variant_id']) === null) {
                throw ValidationException::withMessages([
                    "items.$index.variant_id" => ['Option inconnue pour cet article.'],
                ]);
            }
            if ($line['sale_unit_id'] !== null && $product->saleUnits->firstWhere('id', $line['sale_unit_id']) === null) {
                throw ValidationException::withMessages([
                    "items.$index.sale_unit_id" => ['Unité de vente inconnue.'],
                ]);
            }

            $allowedSides = ($links->get($line['product_id']) ?? collect())->pluck('accompaniment_product_id')->all();
            foreach ($line['side_ids'] as $sideId) {
                if (! in_array($sideId, $allowedSides, true) || ! $storeProducts->has($sideId)) {
                    throw ValidationException::withMessages([
                        "items.$index.side_ids" => ['Accompagnement indisponible.'],
                    ]);
                }
            }
            foreach ($line['extras'] as $extra) {
                $extraProduct = $storeProducts->get($extra['product_id']);
                if ($extraProduct === null || ! $extraProduct->product?->is_active) {
                    throw ValidationException::withMessages([
                        "items.$index.extra_ids" => ['Supplément indisponible.'],
                    ]);
                }
            }

            $start = count($flat);
            $mainRow = array_filter([
                'product_id' => $line['product_id'],
                'product_variant_id' => $line['variant_id'],
                'sale_unit_id' => $line['sale_unit_id'],
                'quantity' => $line['quantity'],
            ], fn ($value) => $value !== null);
            $flat[] = $mainRow;
            $stock[$line['product_id']] = ($stock[$line['product_id']] ?? 0) + $line['quantity'];

            foreach ($line['side_ids'] as $sideId) {
                $flat[] = [
                    'product_id' => $sideId,
                    'quantity' => $line['quantity'],
                    'is_accompaniment' => true,
                ];
            }
            foreach ($line['extras'] as $extra) {
                $flat[] = [
                    'product_id' => $extra['product_id'],
                    'quantity' => $extra['quantity'],
                ];
                $stock[$extra['product_id']] = ($stock[$extra['product_id']] ?? 0) + $extra['quantity'];
            }
            $spans[] = [$start, count($flat) - $start, $line];
        }

        $this->assertStock($store, $stock);

        try {
            $cart = $this->cartEngine->calculateForStore($store, [
                'items' => $flat,
                'apply_promotions' => true,
            ]);
        } catch (InvalidArgumentException $exception) {
            throw ValidationException::withMessages([
                'items' => [$exception->getMessage()],
            ]);
        }

        $stored = [];
        foreach ($spans as [$start, $length, $line]) {
            $slice = array_slice($cart->lines, $start, $length);
            $mainLine = $slice[0] ?? null;
            if (! $mainLine instanceof CalculatedCartLine) {
                throw ValidationException::withMessages([
                    'items' => ['Impossible de calculer cette commande.'],
                ]);
            }
            $product = $storeProducts->get($line['product_id'])?->product;
            $variantName = $line['variant_id']
                ? $product?->variants->firstWhere('id', $line['variant_id'])?->name
                : null;
            $sides = [];
            $extras = [];
            $offset = 1;
            foreach ($line['side_ids'] as $sideId) {
                $sideLine = $slice[$offset] ?? null;
                $offset++;
                $sides[] = [
                    'id' => $sideId,
                    'name' => $sideLine instanceof CalculatedCartLine ? $sideLine->name : $storeProducts->get($sideId)?->product?->name,
                ];
            }
            foreach ($line['extras'] as $extra) {
                $extraLine = $slice[$offset] ?? null;
                $offset++;
                $extras[] = [
                    'id' => $extra['product_id'],
                    'name' => $extraLine instanceof CalculatedCartLine ? $extraLine->name : $storeProducts->get($extra['product_id'])?->product?->name,
                    'quantity' => $extra['quantity'],
                    'unit_price' => $extraLine instanceof CalculatedCartLine ? $extraLine->unitPrice : 0,
                    'line_total' => $extraLine instanceof CalculatedCartLine ? $extraLine->lineTotal : 0,
                ];
            }

            $stored[] = [
                'product_id' => $line['product_id'],
                'product_variant_id' => $line['variant_id'],
                'sale_unit_id' => $line['sale_unit_id'],
                'name' => $mainLine->name ?: $product?->name ?: 'Article',
                'quantity' => $line['quantity'],
                'note' => $line['note'],
                'options' => [
                    'variant_name' => $variantName,
                    'sides' => $sides,
                    'extras' => $extras,
                ],
                'unit_price' => $mainLine->unitPrice,
                'line_subtotal' => array_sum(array_map(fn (CalculatedCartLine $row) => $row->lineSubtotal, $slice)),
                'line_tax' => array_sum(array_map(fn (CalculatedCartLine $row) => $row->lineTax, $slice)),
                'line_total' => array_sum(array_map(fn (CalculatedCartLine $row) => $row->lineTotal, $slice)),
            ];
        }

        return [
            'lines' => $stored,
            'subtotal' => $cart->subtotal,
            'tax_total' => $cart->taxTotal,
            'total' => $cart->grandTotal,
            'currency' => $cart->currency,
        ];
    }

    /**
     * @param  array<string, mixed>  $raw
     * @return array{product_id: string, quantity: int, note: ?string, variant_id: ?string, sale_unit_id: ?string, side_ids: list<string>, extras: list<array{product_id: string, quantity: int}>}
     */
    private function normalizeGuestLine(array $raw, int $index): array
    {
        $productId = trim((string) ($raw['product_id'] ?? ''));
        if ($productId === '') {
            throw ValidationException::withMessages([
                "items.$index.product_id" => ['Article requis.'],
            ]);
        }

        $quantity = (int) ($raw['quantity'] ?? 1);
        if ($quantity < 1 || $quantity > self::MAX_QTY) {
            throw ValidationException::withMessages([
                "items.$index.quantity" => ['La quantité doit être entre 1 et '.self::MAX_QTY.'.'],
            ]);
        }

        $note = trim((string) ($raw['note'] ?? ''));
        if (mb_strlen($note) > 200) {
            throw ValidationException::withMessages([
                "items.$index.note" => ['La note est trop longue.'],
            ]);
        }

        $sideIds = [];
        foreach ($raw['side_ids'] ?? [] as $sideId) {
            $sideId = trim((string) $sideId);
            if ($sideId !== '') {
                $sideIds[] = $sideId;
            }
        }

        $extras = [];
        foreach ($raw['extras'] ?? [] as $extra) {
            if (! is_array($extra)) {
                continue;
            }
            $extraId = trim((string) ($extra['product_id'] ?? ''));
            $extraQty = (int) ($extra['quantity'] ?? 1);
            if ($extraId === '') {
                continue;
            }
            if ($extraQty < 1 || $extraQty > self::MAX_QTY) {
                throw ValidationException::withMessages([
                    "items.$index.extras" => ['La quantité d’un supplément doit être entre 1 et '.self::MAX_QTY.'.'],
                ]);
            }
            $extras[] = ['product_id' => $extraId, 'quantity' => $extraQty];
        }

        return [
            'product_id' => $productId,
            'quantity' => $quantity,
            'note' => $note !== '' ? $note : null,
            'variant_id' => ($raw['variant_id'] ?? null) ? (string) $raw['variant_id'] : null,
            'sale_unit_id' => ($raw['sale_unit_id'] ?? null) ? (string) $raw['sale_unit_id'] : null,
            'side_ids' => array_values(array_unique($sideIds)),
            'extras' => $extras,
        ];
    }

    /** @param  array<string, int>  $quantities */
    private function assertStock(Store $store, array $quantities): void
    {
        $store->loadMissing('branch');
        $warehouse = Warehouse::query()
            ->where('branch_id', $store->branch_id)
            ->where('is_active', true)
            ->orderBy('created_at')
            ->first();
        if ($warehouse === null) {
            return;
        }

        $missing = [];
        foreach ($quantities as $productId => $qty) {
            $rows = StockBalance::query()
                ->where('warehouse_id', $warehouse->id)
                ->where('product_id', $productId)
                ->whereNull('product_variant_id')
                ->get();
            if ($rows->isEmpty()) {
                continue;
            }
            $available = (int) $rows->sum('quantity_on_hand') - (int) $rows->sum('quantity_reserved');
            if ($available < $qty) {
                $missing[] = Product::query()->find($productId)?->name ?: 'Article';
            }
        }

        if ($missing !== []) {
            throw ValidationException::withMessages([
                'items' => ['Plus disponible : '.implode(', ', $missing)],
            ]);
        }
    }

    /** @return list<array<string, mixed>> */
    private function guestPayloadFromStored(QrOrder $order): array
    {
        return $order->items->map(function (QrOrderItem $item): array {
            $options = $item->options ?? [];

            return [
                'product_id' => $item->product_id,
                'quantity' => $item->quantity,
                'note' => $item->note,
                'variant_id' => $item->product_variant_id,
                'sale_unit_id' => $item->sale_unit_id,
                'side_ids' => array_values(array_filter(array_map(
                    fn ($side) => is_array($side) ? (string) ($side['id'] ?? '') : '',
                    $options['sides'] ?? [],
                ))),
                'extras' => array_values(array_map(fn ($extra) => [
                    'product_id' => is_array($extra) ? (string) ($extra['id'] ?? '') : '',
                    'quantity' => is_array($extra) ? (int) ($extra['quantity'] ?? 1) : 1,
                ], $options['extras'] ?? [])),
            ];
        })->all();
    }

    /** @return list<array<string, mixed>> */
    private function flatFromStored(QrOrder $order): array
    {
        $flat = [];
        foreach ($order->items as $item) {
            $options = $item->options ?? [];
            $flat[] = array_filter([
                'product_id' => $item->product_id,
                'product_variant_id' => $item->product_variant_id,
                'sale_unit_id' => $item->sale_unit_id,
                'quantity' => $item->quantity,
            ], fn ($value) => $value !== null);
            foreach ($options['sides'] ?? [] as $side) {
                if (! empty($side['id'])) {
                    $flat[] = [
                        'product_id' => $side['id'],
                        'quantity' => $item->quantity,
                        'is_accompaniment' => true,
                    ];
                }
            }
            foreach ($options['extras'] ?? [] as $extra) {
                if (! empty($extra['id'])) {
                    $flat[] = [
                        'product_id' => $extra['id'],
                        'quantity' => max(1, (int) ($extra['quantity'] ?? 1)),
                    ];
                }
            }
        }

        return $flat;
    }

    /** @return list<array<string, mixed>> */
    private function kitchenLines(QrOrder $order): array
    {
        return $order->items->map(function (QrOrderItem $item): array {
            $options = $item->options ?? [];

            return [
                'name' => $item->name,
                'quantity' => $item->quantity,
                'notes' => (string) ($item->note ?? ''),
                'modifiers' => array_values(array_filter([(string) ($options['variant_name'] ?? '')])),
                'sides' => array_values(array_filter(array_map(
                    fn ($side) => is_array($side) ? (string) ($side['name'] ?? '') : '',
                    $options['sides'] ?? [],
                ))),
                'extras' => array_values(array_map(function ($extra): array {
                    return [
                        'name' => is_array($extra) ? (string) ($extra['name'] ?? '') : '',
                        'quantity' => is_array($extra) ? (int) ($extra['quantity'] ?? 1) : 1,
                    ];
                }, $options['extras'] ?? [])),
            ];
        })->all();
    }

    private function openOrCreateSession(PosTable $table): QrTableSession
    {
        $open = $this->openSession($table);
        if ($open !== null) {
            return $open;
        }

        return QrTableSession::query()->create([
            'tenant_id' => $table->tenant_id,
            'store_id' => $table->store_id,
            'pos_table_id' => $table->id,
            'sale_id' => $table->currentSaleIsOpen() ? $table->current_sale_id : null,
            'status' => QrSessionStatus::Open,
            'opened_at' => now(),
        ]);
    }

    private function openSession(PosTable $table): ?QrTableSession
    {
        return QrTableSession::query()
            ->with('orders.items')
            ->where('pos_table_id', $table->id)
            ->where('status', QrSessionStatus::Open)
            ->latest('opened_at')
            ->first();
    }

    /** @return array{open: bool, message: ?string} */
    private function orderingGate(TableQrToken $token, PosTable $table): array
    {
        if (! $token->is_active) {
            return ['open' => false, 'message' => 'Ce QR code est invalide ou désactivé.'];
        }
        if (! $table->is_active || $table->status === PosTableStatus::Inactive) {
            return ['open' => false, 'message' => 'Cette table est fermée.'];
        }
        if ($table->status === PosTableStatus::Cleaning) {
            return ['open' => false, 'message' => 'Cette table est en cours de libération. Réessayez dans un instant.'];
        }

        return ['open' => true, 'message' => null];
    }

    private function requireTable(TableQrToken $token): PosTable
    {
        $table = $token->table;
        if ($table === null) {
            throw ValidationException::withMessages([
                'table' => ['Ce QR code est invalide ou désactivé.'],
            ]);
        }

        return $table;
    }

    private function orderForToken(TableQrToken $token, string $orderId, bool $lock = false): QrOrder
    {
        $query = QrOrder::query()->with(['items', 'table.store'])->whereKey($orderId);
        if ($lock) {
            $query->lockForUpdate();
        }
        $order = $query->first();
        if ($order === null || $order->pos_table_id !== $token->pos_table_id) {
            throw ValidationException::withMessages([
                'order' => ['Commande introuvable pour cette table.'],
            ]);
        }

        return $order;
    }

    private function assertSubmitted(QrOrder $order): void
    {
        if ($order->status !== QrOrderStatus::Submitted) {
            throw ValidationException::withMessages([
                'status' => ['Cette commande n’est plus en attente d’approbation.'],
            ]);
        }
    }

    private function cashierPresent(Store $store): bool
    {
        return CashierShift::query()
            ->where('store_id', $store->id)
            ->where('status', CashierShiftStatus::Open)
            ->exists();
    }

    private function automaticApprover(Store $store): ?User
    {
        return User::query()
            ->where('tenant_id', $store->tenant_id)
            ->where('is_active', true)
            ->orderBy('created_at')
            ->first();
    }

    /** @return list<array<string, mixed>> */
    private function categories(Store $store): array
    {
        $rows = StoreProduct::query()
            ->where('store_id', $store->id)
            ->where('is_available', true)
            ->whereHas('product', fn ($query) => $query->where('is_active', true))
            ->with([
                'product.category:id,name',
                'product.images',
                'product.variants' => fn ($query) => $query->where('is_active', true)->orderBy('sort_order'),
                'product.saleUnits' => fn ($query) => $query->where('is_active', true)->orderBy('sort_order'),
                'product.accompanimentLinks.accompanimentProduct:id,name,base_price,is_active',
            ])
            ->get();

        $warehouse = Warehouse::query()
            ->where('branch_id', $store->branch_id)
            ->where('is_active', true)
            ->orderBy('created_at')
            ->first();

        $stock = [];
        if ($warehouse !== null) {
            $stock = StockBalance::query()
                ->where('warehouse_id', $warehouse->id)
                ->whereIn('product_id', $rows->pluck('product_id'))
                ->get()
                ->groupBy('product_id')
                ->map(fn ($group) => (int) $group->sum('quantity_on_hand') - (int) $group->sum('quantity_reserved'))
                ->all();
        }

        $groups = [];
        foreach ($rows as $row) {
            $product = $row->product;
            if ($product === null) {
                continue;
            }
            $tracked = $warehouse !== null && array_key_exists($product->id, $stock);
            $available = ! $tracked || $stock[$product->id] > 0;
            $category = $product->category?->name ?: 'Carte';
            $image = null;
            $primary = $product->images->firstWhere('is_primary', true) ?? $product->images->first();
            if ($primary !== null) {
                try {
                    $image = $primary->cdn_url ?: null;
                } catch (\Throwable) {
                    $image = null;
                }
            }

            $groups[$category][] = [
                'id' => $product->id,
                'name' => $product->name,
                'description' => $product->description,
                'price' => $row->price_override ?? $product->base_price,
                'image_url' => $image,
                'available' => $available,
                'variants' => $product->variants->map(fn ($variant) => [
                    'id' => $variant->id,
                    'name' => $variant->name,
                    'price' => $variant->base_price,
                ])->values()->all(),
                'sale_units' => $product->saleUnits->map(fn ($unit) => [
                    'id' => $unit->id,
                    'name' => $unit->name,
                    'price' => $unit->price,
                ])->values()->all(),
                'sides' => $product->accompanimentLinks
                    ->filter(fn ($link) => $link->accompanimentProduct?->is_active)
                    ->map(fn ($link) => [
                        'id' => $link->accompaniment_product_id,
                        'name' => $link->accompanimentProduct?->name,
                    ])->values()->all(),
            ];
        }

        ksort($groups);

        return collect($groups)->map(fn (array $products, string $name) => [
            'name' => $name,
            'products' => $products,
        ])->values()->all();
    }

    /** @return array<string, mixed> */
    public function presentGuest(QrOrder $order): array
    {
        $order->loadMissing('items');

        return [
            'id' => $order->id,
            'status' => $order->status->value,
            'guest_status' => $this->guestStatus($order),
            'rejection_reason' => $order->rejection_reason,
            'subtotal' => $order->subtotal,
            'tax_total' => $order->tax_total,
            'total' => $order->total,
            'currency' => $order->currency,
            'created_at' => $order->created_at?->toIso8601String(),
            'items' => $order->items->map(fn (QrOrderItem $item) => [
                'id' => $item->id,
                'product_id' => $item->product_id,
                'variant_id' => $item->product_variant_id,
                'sale_unit_id' => $item->sale_unit_id,
                'name' => $item->name,
                'quantity' => $item->quantity,
                'note' => $item->note,
                'line_total' => $item->line_total,
                'options' => $item->options,
            ])->values()->all(),
        ];
    }

    /** @return array<string, mixed> */
    public function presentCashier(QrOrder $order): array
    {
        $guest = $this->presentGuest($order);
        $guest['table'] = $order->relationLoaded('table') && $order->table
            ? $order->table->only(['id', 'name', 'code'])
            : null;
        $guest['sale_id'] = $order->sale_id;
        $guest['approved_at'] = $order->approved_at?->toIso8601String();
        $guest['approved_by'] = $order->relationLoaded('approver') && $order->approver
            ? $order->approver->only(['id', 'name'])
            : null;

        return $guest;
    }

    private function guestStatus(QrOrder $order): string
    {
        if ($order->status === QrOrderStatus::Rejected) {
            return 'rejected';
        }
        if ($order->status === QrOrderStatus::Cancelled) {
            return 'cancelled';
        }
        if ($order->status === QrOrderStatus::Submitted) {
            return 'sent';
        }

        if ($order->kitchen_ticket_code) {
            $ticket = DeskDocument::query()
                ->where('store_id', $order->store_id)
                ->where('code', $order->kitchen_ticket_code)
                ->first();
            $kitchen = (string) ($ticket->status ?? '');

            return match ($kitchen) {
                'preparing' => 'preparing',
                'ready' => 'ready',
                'served' => 'served',
                'cancelled' => 'kitchen_cancelled',
                default => 'approved',
            };
        }

        return 'approved';
    }

    private function locale(mixed $value): string
    {
        $locale = is_string($value) ? strtolower(substr($value, 0, 2)) : 'fr';

        return in_array($locale, ['fr', 'en', 'sw'], true) ? $locale : 'fr';
    }

    private function notify(Store $store, string $type, QrOrder $order): void
    {
        $this->realtime->notify(
            $type,
            $store->tenant_id,
            $store->id,
            'qr_order',
            $order->id,
            $order->status->value,
            [
                'table' => $order->table?->name,
                'total' => $order->total,
            ],
        );
    }
}
