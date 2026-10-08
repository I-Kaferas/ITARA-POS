<?php

namespace App\Services\Sync;

use App\Enums\CashMovementType;
use App\Enums\ConflictAction;
use App\Models\CashierShift;
use App\Models\CashMovement;
use App\Models\CashRegister;
use App\Models\Customer;
use App\Models\DeskDocument;
use App\Models\OfflineTransaction;
use App\Models\Sale;
use App\Models\Store;
use App\Models\User;
use App\Services\Authorization\AuthorizationService;
use App\Services\Desk\HospitalityDesk;
use App\Services\Registers\CashRegisterSessionService;
use App\Services\Sales\SaleEngine;
use App\Services\Shifts\CashierShiftService;
use Carbon\Carbon;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;

class OfflineSyncService
{
    /** @var list<string> */
    private const RESTAURANT_ACTIONS = [
        'open_order', 'add_line', 'send_course', 'set_ticket_status', 'split_lines', 'pay_check',
        'charge_room', 'upsert_zone', 'delete_zone', 'upsert_table', 'delete_table',
    ];

    /** @var list<string> */
    private const HOTEL_ACTIONS = [
        'create_reservation', 'upsert_reservation', 'delete_reservation', 'check_in', 'walk_in_check_in',
        'check_out', 'post_folio', 'change_stay_room', 'collect_stay_payment',
        'set_room_housekeeping', 'upsert_housekeeping_task', 'delete_housekeeping_task', 'set_housekeeping_task_status',
        'upsert_room_type', 'delete_room_type', 'upsert_amenity', 'delete_amenity',
        'upsert_building', 'delete_building', 'upsert_wing', 'delete_wing', 'upsert_floor', 'delete_floor',
        'upsert_room', 'delete_room', 'upsert_hotel_settings', 'upsert_concierge_request',
        'delete_concierge_request', 'set_concierge_status',
    ];

    /** @var list<string> */
    private const STATE_KEYS = [
        'cash_register', 'cashier', 'cashier_shift', 'cash_register_session',
        'room', 'table', 'reservation', 'stay', 'order', 'folio', 'stock', 'items',
    ];

    public function __construct(
        private readonly SaleEngine $sales,
        private readonly HospitalityDesk $hospitality,
        private readonly CashierShiftService $shifts,
        private readonly CashRegisterSessionService $sessions,
        private readonly AuthorizationService $authorization,
        private readonly ConflictResolutionEngine $conflicts,
    ) {}

    /**
     * Remember a successful online write so a lost response can be replayed
     * without applying the same UUID twice.
     */
    public function rememberHttp(Request $request, Response $response): void
    {
        $uuid = (string) $request->header('X-Client-UUID', '');
        if (! Str::isUuid($uuid)) {
            return;
        }

        if ($response->getStatusCode() < 200 || $response->getStatusCode() >= 300) {
            return;
        }

        $user = $request->user();
        if (! $user instanceof User) {
            return;
        }

        $path = $request->path();
        if (str_contains($path, '/sync/')) {
            return;
        }

        $payload = $request->json()->all();
        if ($payload === []) {
            $payload = $request->except(['pin']);
        }

        $json = json_decode($response->getContent(), true);
        $serverId = $uuid;
        if (is_array($json)) {
            $serverId = (string) ($json['data']['sale']['id'] ?? $json['data']['id'] ?? $uuid);
        }

        $classified = $this->classifyHttp($request);
        $result = [
            'id' => $uuid,
            'entity_id' => $uuid,
            'client_uuid' => $uuid,
            'status' => 'synced',
            'server_id' => $serverId,
            'retryable' => false,
        ];

        $this->storeClaim(
            $user->tenant_id,
            app()->bound('store') && app('store') instanceof Store ? app('store')->id : null,
            $uuid,
            $classified['domain'],
            $classified['entity_type'],
            $uuid,
            $classified['operation'],
            $payload,
            null,
            'synced',
            $result,
            null,
            null,
        );
    }

    /**
     * @param  array<string, mixed>  $operation
     * @return array<string, mixed>
     */
    public function accept(Store $store, User $user, array $operation): array
    {
        $uuid = (string) ($operation['client_uuid'] ?? '');
        if (! Str::isUuid($uuid)) {
            return $this->envelope($operation, $this->outcome('failed', 'Chaque transaction hors ligne doit avoir un UUID.', retryable: false));
        }

        $payload = $operation['payload'] ?? null;
        if (! is_array($payload)) {
            return $this->envelope($operation, $this->outcome('failed', 'Payload invalide.', retryable: false));
        }

        $domain = (string) ($operation['domain'] ?? '');
        if (! in_array($domain, ['pos', 'restaurant', 'hotel', 'cash_register'], true)) {
            return $this->envelope($operation, $this->outcome('failed', 'Domaine hors ligne inconnu.', retryable: false));
        }

        $hash = $this->hashPayload($payload);
        $force = ($operation['resolution'] ?? null) === 'keep_local';
        $baseVersion = isset($operation['base_version']) ? (string) $operation['base_version'] : null;

        try {
            return DB::transaction(function () use ($store, $user, $operation, $uuid, $payload, $domain, $hash, $force, $baseVersion): array {
                $existing = OfflineTransaction::query()
                    ->where('tenant_id', $store->tenant_id)
                    ->where('client_uuid', $uuid)
                    ->lockForUpdate()
                    ->first();

                if ($existing !== null && $existing->payload_hash !== $hash) {
                    return $this->envelope($operation, $this->outcome(
                        'conflict',
                        'Cet UUID est déjà utilisé par une autre transaction.',
                        'uuid_payload_mismatch',
                    ));
                }

                if ($existing !== null && $existing->status === 'synced') {
                    return $this->alreadyProcessed(
                        $existing->result
                            ?? $this->envelope($operation, $this->outcome('synced', serverId: $existing->entity_id ?? $existing->client_uuid))
                    );
                }

                if ($existing !== null && $existing->status === 'discarded') {
                    return $existing->result ?? $this->envelope($operation, $this->outcome('discarded'));
                }

                if ($existing !== null && $existing->status === 'conflict' && ! $force) {
                    return $existing->result ?? $this->envelope($operation, $this->outcome('conflict', $existing->error, $existing->conflict_code));
                }

                $denied = $this->authorize($user, $domain);
                if ($denied !== null) {
                    return $this->saveRow($store, $operation, $existing, $payload, $hash, $baseVersion, $denied);
                }

                $outcome = $this->apply($store, $user, $operation, $payload, $uuid, $force);

                return $this->saveRow($store, $operation, $existing, $payload, $hash, $baseVersion, $outcome);
            });
        } catch (UniqueConstraintViolationException) {
            $existing = OfflineTransaction::query()
                ->where('tenant_id', $store->tenant_id)
                ->where('client_uuid', $uuid)
                ->first();

            if ($existing?->result) {
                return $existing->result;
            }

            return $this->envelope($operation, $this->outcome('failed', 'Transaction en cours de traitement.', retryable: true));
        }
    }

    /**
     * @return array<string, mixed>
     */
    public function resolve(Store $store, User $user, string $clientUuid, string $resolution): array
    {
        $row = OfflineTransaction::query()
            ->where('tenant_id', $store->tenant_id)
            ->where('client_uuid', $clientUuid)
            ->first();

        if ($row === null) {
            return [
                'client_uuid' => $clientUuid,
                'status' => 'failed',
                'error' => 'Transaction inconnue.',
                'retryable' => false,
            ];
        }

        if (in_array($resolution, ['discard', 'accept_server'], true)) {
            $result = [
                'id' => $row->client_uuid,
                'entity_id' => $row->entity_id,
                'client_uuid' => $row->client_uuid,
                'status' => 'discarded',
                'resolution' => $resolution,
                'retryable' => false,
            ];
            $payload = $row->payload ?? [];
            unset($payload['pin']);
            $row->fill([
                'status' => 'discarded',
                'conflict_code' => null,
                'error' => null,
                'payload' => $payload,
                'result' => $result,
            ])->save();

            return $result;
        }

        return $this->accept($store, $user, [
            'id' => $row->client_uuid,
            'client_uuid' => $row->client_uuid,
            'domain' => $row->domain,
            'entity_type' => $row->entity_type,
            'entity_id' => $row->entity_id,
            'operation' => $row->operation,
            'payload' => $row->payload ?? [],
            'base_version' => $row->base_version,
            'resolution' => 'keep_local',
        ]);
    }

    /** @param  array<string, mixed>  $payload */
    public function hashPayload(array $payload): string
    {
        unset($payload['pin']);

        return hash('sha256', json_encode($this->canonicalize($payload), JSON_THROW_ON_ERROR));
    }

    /**
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $outcome
     * @return array<string, mixed>
     */
    private function saveRow(Store $store, array $operation, ?OfflineTransaction $existing, array $payload, string $hash, ?string $baseVersion, array $outcome): array
    {
        $envelope = $this->envelope($operation, $outcome);
        $status = (string) $outcome['status'];
        $storedPayload = $payload;
        if (in_array($status, ['synced', 'discarded'], true)) {
            unset($storedPayload['pin']);
        }

        $attributes = [
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'client_uuid' => (string) $operation['client_uuid'],
            'domain' => (string) $operation['domain'],
            'entity_type' => (string) $operation['entity_type'],
            'entity_id' => (string) $operation['entity_id'],
            'operation' => (string) $operation['operation'],
            'payload_hash' => $hash,
            'payload' => $storedPayload,
            'base_version' => $baseVersion,
            'status' => $status,
            'result' => $envelope,
            'conflict_code' => $outcome['conflict_code'] ?? null,
            'error' => $outcome['error'] ?? null,
            'attempts' => ($existing->attempts ?? 0) + 1,
            'synced_at' => $status === 'synced' ? now() : null,
        ];

        if ($existing === null) {
            OfflineTransaction::query()->create($attributes);
        } else {
            $existing->fill($attributes)->save();
        }

        return $envelope;
    }

    /**
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $result
     */
    private function storeClaim(
        string $tenantId,
        ?string $storeId,
        string $uuid,
        string $domain,
        string $entityType,
        string $entityId,
        string $operation,
        array $payload,
        ?string $baseVersion,
        string $status,
        array $result,
        ?string $conflictCode,
        ?string $error,
    ): void {
        unset($payload['pin']);
        $hash = $this->hashPayload($payload);

        $existing = OfflineTransaction::query()
            ->where('tenant_id', $tenantId)
            ->where('client_uuid', $uuid)
            ->first();

        if ($existing !== null) {
            if ($existing->status === 'synced') {
                return;
            }

            $existing->fill([
                'status' => $status,
                'result' => $result,
                'payload' => $payload,
                'payload_hash' => $hash,
                'synced_at' => $status === 'synced' ? now() : $existing->synced_at,
                'error' => $error,
                'conflict_code' => $conflictCode,
            ])->save();

            return;
        }

        try {
            OfflineTransaction::query()->create([
                'tenant_id' => $tenantId,
                'store_id' => $storeId,
                'client_uuid' => $uuid,
                'domain' => $domain,
                'entity_type' => $entityType,
                'entity_id' => $entityId,
                'operation' => $operation,
                'payload_hash' => $hash,
                'payload' => $payload,
                'base_version' => $baseVersion,
                'status' => $status,
                'result' => $result,
                'conflict_code' => $conflictCode,
                'error' => $error,
                'attempts' => 1,
                'synced_at' => $status === 'synced' ? now() : null,
            ]);
        } catch (UniqueConstraintViolationException) {
            // The sync worker stored the same UUID first.
        }
    }

    /**
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function apply(Store $store, User $user, array $operation, array $payload, string $uuid, bool $force): array
    {
        $domain = (string) $operation['domain'];

        try {
            if (in_array((string) ($operation['entity_type'] ?? ''), ['sale', 'customer'], true)) {
                if (! $this->authorization->hasPermission($user, 'sales.create')) {
                    return $this->outcome('failed', 'Permission refusée.', retryable: false);
                }

                return $this->applyPos($store, $user, $operation, $payload, $uuid, $force);
            }

            return match ($domain) {
                'pos' => $this->applyPos($store, $user, $operation, $payload, $uuid, $force),
                'restaurant', 'hotel' => $this->applyHospitality($store, $operation, $payload, $uuid, $force),
                'cash_register' => $this->applyCashRegister($store, $user, $operation, $payload, $uuid),
                default => $this->outcome('failed', 'Domaine non pris en charge.', retryable: false),
            };
        } catch (ValidationException $exception) {
            return $this->fromValidation($exception);
        } catch (\Throwable $exception) {
            return $this->outcome('failed', $exception->getMessage(), retryable: true);
        }
    }

    /**
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function applyPos(Store $store, User $user, array $operation, array $payload, string $uuid, bool $force = false): array
    {
        $entity = (string) $operation['entity_type'];
        $operationName = (string) $operation['operation'];

        if ($entity === 'customer' && $operationName === 'create') {
            return $this->applyCustomer($store, $operation, $payload);
        }

        if ($this->isStockEntity($entity)) {
            return $this->applyStockConflictGate($operation, $payload);
        }

        if ($this->isConfigurationEntity($entity)) {
            return $this->applyConfigurationConflictGate($operation, $payload, $force);
        }

        if ($entity !== 'sale') {
            return $this->outcome('conflict', 'Opération POS non prise en charge.', 'unsupported');
        }

        unset($payload['client_uuid'], $payload['action'], $payload['pin']);
        $payload['idempotency_key'] = $payload['idempotency_key'] ?? $uuid;

        if (! empty($payload['cashier_shift_id']) && ! CashierShift::query()->whereKey($payload['cashier_shift_id'])->exists()) {
            return $this->outcome('failed', 'Cashier shift not found.', retryable: true);
        }

        if (! empty($payload['sale_id']) && ! Sale::query()->where('store_id', $store->id)->whereKey($payload['sale_id'])->exists()) {
            return $this->outcome('failed', 'Sale not found.', retryable: true);
        }

        if ($operationName === 'hold') {
            $sale = $this->sales->hold($store, $payload, $user);

            return $this->outcome('synced', serverId: $sale->id, reference: $sale->reference);
        }

        if ($operationName === 'update' || $operationName === 'delete') {
            $sale = Sale::query()->where('store_id', $store->id)->whereKey((string) $operation['entity_id'])->first();
            if ($sale === null) {
                return $this->outcome('failed', 'Sale not found.', retryable: true);
            }

            $blocked = $this->guardSaleMutation($sale, $operationName, $payload, $force);
            if ($blocked !== null) {
                return $blocked;
            }

            if ($operationName === 'delete') {
                $this->sales->discardHold($sale, $user);

                return $this->outcome('synced', serverId: $sale->id, reference: $sale->reference);
            }

            $sale = $this->sales->updateHold($sale, $payload, $user);

            return $this->outcome('synced', serverId: $sale->id, reference: $sale->reference);
        }

        if (! empty($payload['sale_id'])) {
            $pending = Sale::query()->where('store_id', $store->id)->whereKey((string) $payload['sale_id'])->first();
            if ($pending !== null) {
                $blocked = $this->guardSaleMutation($pending, 'complete', $payload, $force);
                if ($blocked !== null) {
                    return $blocked;
                }
            }
        }

        $result = ! empty($payload['sale_id'])
            ? $this->sales->completePending($store, $payload, $user)
            : $this->sales->create($store, $payload, $user);

        return $this->outcome('synced', serverId: $result->sale->id, reference: $result->sale->reference);
    }

    /**
     * Never overwrite completed / final sales.
     *
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>|null
     */
    private function guardSaleMutation(Sale $sale, string $operation, array $payload, bool $force): ?array
    {
        $decision = $this->conflicts->evaluate(ConflictContext::make(
            entityType: 'sale',
            operation: $operation,
            localPayload: $payload,
            serverRecord: [
                'id' => $sale->id,
                'status' => $sale->status?->value ?? (string) $sale->status,
                'reference' => $sale->reference,
            ],
            force: $force,
            conflictDomain: 'sales',
        ));

        return $this->decisionToOutcome($decision, $sale->id, $sale->reference);
    }

    /**
     * Stock sync must go through movements — never absolute quantity overwrites.
     *
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function applyStockConflictGate(array $operation, array $payload): array
    {
        $decision = $this->conflicts->evaluate(ConflictContext::make(
            entityType: (string) $operation['entity_type'],
            operation: (string) $operation['operation'],
            localPayload: $payload,
            serverRecord: isset($payload['server_quantity']) || isset($payload['quantity_on_hand'])
                ? [
                    'quantity_on_hand' => $payload['server_quantity'] ?? $payload['quantity_on_hand'] ?? null,
                ]
                : null,
            conflictDomain: 'stock',
        ));

        if ($decision->action === ConflictAction::Apply) {
            // Movement-shaped ops are accepted by the gate; dedicated stock apply
            // paths land in later master↔slave sync work.
            return $this->outcome('synced', serverId: (string) ($operation['entity_id'] ?? ''));
        }

        return $this->decisionToOutcome($decision) ?? $this->outcome(
            'conflict',
            $decision->message ?? 'Conflit de stock.',
            $decision->code ?? 'use_stock_movements',
        );
    }

    /**
     * Master configuration always wins over slave / client copies.
     *
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function applyConfigurationConflictGate(array $operation, array $payload, bool $force): array
    {
        $fromMaster = (bool) ($payload['from_master'] ?? $operation['from_master'] ?? false);
        $serverRecord = null;
        if (is_array($operation['server_record'] ?? null)) {
            $serverRecord = $operation['server_record'];
        } elseif (array_key_exists('has_master_copy', $payload)) {
            $serverRecord = ((bool) $payload['has_master_copy']) ? ['id' => true] : null;
        } elseif (in_array(strtolower((string) $operation['operation']), ['update', 'delete', 'overwrite'], true)) {
            // Updates imply a master row already exists.
            $serverRecord = ['id' => (string) ($operation['entity_id'] ?? '')];
        }

        $decision = $this->conflicts->evaluate(ConflictContext::make(
            entityType: (string) $operation['entity_type'],
            operation: (string) $operation['operation'],
            localPayload: $payload,
            serverRecord: $serverRecord,
            baseVersion: isset($operation['base_version']) ? (string) $operation['base_version'] : null,
            serverVersion: isset($payload['server_version']) ? (string) $payload['server_version'] : null,
            force: $force,
            fromMaster: $fromMaster,
            conflictDomain: 'configuration',
        ));

        if ($decision->action === ConflictAction::Apply) {
            return $this->outcome('synced', serverId: (string) ($operation['entity_id'] ?? ''));
        }

        if ($decision->action === ConflictAction::KeepServer) {
            return $this->outcome(
                'synced',
                serverId: (string) ($operation['entity_id'] ?? ''),
            );
        }

        return $this->decisionToOutcome($decision) ?? $this->outcome(
            'conflict',
            $decision->message ?? 'La configuration maître prévaut.',
            $decision->code ?? 'master_wins',
        );
    }

    /**
     * @return array<string, mixed>|null
     */
    private function decisionToOutcome(ConflictDecision $decision, ?string $serverId = null, ?string $reference = null): ?array
    {
        if ($decision->action === ConflictAction::Apply) {
            return null;
        }

        if ($decision->action === ConflictAction::KeepServer) {
            return $this->outcome('synced', serverId: $serverId, reference: $reference);
        }

        return $this->outcome(
            'conflict',
            $decision->message ?? 'Conflit de synchronisation.',
            $decision->code ?? 'conflict',
            retryable: $decision->retryable,
            serverId: $serverId,
            reference: $reference,
        );
    }

    private function isStockEntity(string $entityType): bool
    {
        return $this->conflicts->resolveDomain(ConflictContext::make($entityType, 'create'))->value === 'stock';
    }

    private function isConfigurationEntity(string $entityType): bool
    {
        return $this->conflicts->resolveDomain(ConflictContext::make($entityType, 'update'))->value === 'configuration';
    }

    /**
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function applyCustomer(Store $store, array $operation, array $payload): array
    {
        $entityId = (string) $operation['entity_id'];
        $name = trim((string) ($payload['name'] ?? ''));
        if ($name === '') {
            return $this->outcome('failed', 'Customer name is required.', retryable: false);
        }

        $existing = Customer::query()
            ->where('tenant_id', $store->tenant_id)
            ->where('metadata->client_id', $entityId)
            ->first();

        if ($existing !== null) {
            return $this->outcome('synced', serverId: $existing->id);
        }

        $email = trim((string) ($payload['email'] ?? ''));
        $phone = trim((string) ($payload['phone'] ?? ''));
        $customer = Customer::query()->create([
            'tenant_id' => $store->tenant_id,
            'name' => $name,
            'email' => $email !== '' ? $email : null,
            'phone' => $phone !== '' ? $phone : null,
            'payment_terms_days' => 0,
            'is_active' => true,
            'metadata' => ['client_id' => $entityId],
        ]);

        return $this->outcome('synced', serverId: $customer->id);
    }

    /**
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function applyHospitality(Store $store, array $operation, array $payload, string $uuid, bool $force): array
    {
        $actionName = (string) ($payload['action'] ?? $operation['operation'] ?? '');
        $known = array_merge(self::RESTAURANT_ACTIONS, self::HOTEL_ACTIONS);
        if (! in_array($actionName, $known, true)) {
            return $this->outcome('failed', 'Action hôtel ou restaurant non prise en charge hors ligne.', retryable: false);
        }

        $expectedDomain = in_array($actionName, self::RESTAURANT_ACTIONS, true) ? 'restaurant' : 'hotel';
        if ((string) $operation['domain'] !== $expectedDomain) {
            return $this->outcome('conflict', 'Le domaine ne correspond pas à l’action.', 'unsupported');
        }

        if (! $force) {
            $stale = $this->staleDocument($store, $actionName, $payload, isset($operation['base_version']) ? (string) $operation['base_version'] : null);
            if ($stale !== null) {
                return $stale;
            }
        }

        $payload['action'] = $actionName;
        $payload['client_uuid'] = $payload['client_uuid'] ?? $uuid;
        $this->hospitality->apply($store, $payload);

        return $this->outcome('synced', serverId: (string) ($payload['client_uuid'] ?? $uuid));
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>|null
     */
    private function staleDocument(Store $store, string $action, array $payload, ?string $baseVersion): ?array
    {
        if ($baseVersion === null || $baseVersion === '') {
            return null;
        }

        $code = match ($action) {
            'open_order' => $payload['table_id'] ?? null,
            'add_line', 'send_course', 'pay_check', 'charge_room', 'split_lines' => $payload['order_id'] ?? null,
            'set_ticket_status' => $payload['ticket_id'] ?? null,
            'check_in', 'check_out', 'change_stay_room', 'collect_stay_payment' => $payload['reservation_id'] ?? $payload['stay_id'] ?? null,
            'post_folio', 'set_room_housekeeping' => $payload['room_id'] ?? null,
            default => $payload['id'] ?? null,
        };

        if (! is_string($code) || $code === '') {
            return null;
        }

        $document = DeskDocument::query()->where('store_id', $store->id)->where('code', $code)->first();
        if ($document?->updated_at === null) {
            return null;
        }

        try {
            $stale = $document->updated_at->gt(Carbon::parse($baseVersion));
        } catch (\Throwable) {
            $stale = $document->updated_at->toIso8601String() !== $baseVersion;
        }

        if (! $stale) {
            return null;
        }

        return $this->outcome(
            'conflict',
            'Le document a été modifié sur le serveur depuis la copie locale.',
            'stale_version',
        );
    }

    /**
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function applyCashRegister(Store $store, User $user, array $operation, array $payload, string $uuid): array
    {
        $registerId = (string) ($payload['cash_register_id'] ?? '');
        $register = CashRegister::query()->where('store_id', $store->id)->whereKey($registerId)->first();
        if ($register === null) {
            return $this->outcome('failed', 'Caisse introuvable.', retryable: true);
        }

        $name = (string) $operation['operation'];
        $actor = $user;
        if (! empty($payload['pin'])) {
            $actor = User::query()->where('pin', (string) $payload['pin'])->where('is_active', true)->first();
            if ($actor === null) {
                return $this->outcome('failed', 'PIN invalide.', retryable: false);
            }
        }

        if ($name === 'open') {
            $deviceId = isset($payload['device_id']) && is_string($payload['device_id'])
                ? $payload['device_id']
                : null;

            $shift = $this->shifts->open(
                $register,
                $actor,
                (int) ($payload['opening_balance'] ?? 0),
                isset($payload['opening_notes']) ? (string) $payload['opening_notes'] : null,
                isset($payload['opened_at']) ? Carbon::parse((string) $payload['opened_at']) : null,
                $uuid,
                $deviceId,
            );

            return $this->outcome('synced', serverId: $shift->id);
        }

        if ($name === 'close') {
            $shift = $this->shifts->close(
                $register,
                $actor,
                (int) ($payload['actual_cash'] ?? 0),
                isset($payload['closing_notes']) ? (string) $payload['closing_notes'] : null,
                null,
                isset($payload['variance_reason']) ? (string) $payload['variance_reason'] : null,
            );

            return $this->outcome('synced', serverId: $shift->id);
        }

        if ($name === 'open_session') {
            $session = $this->sessions->open(
                $register,
                $actor,
                (int) ($payload['opening_balance'] ?? 0),
                isset($payload['opening_notes']) ? (string) $payload['opening_notes'] : null,
            );

            return $this->outcome('synced', serverId: $session->id);
        }

        if ($name === 'close_session') {
            $session = $this->sessions->close(
                $register,
                $actor,
                (int) ($payload['actual_cash'] ?? 0),
                isset($payload['closing_notes']) ? (string) $payload['closing_notes'] : null,
                isset($payload['variance_reason']) ? (string) $payload['variance_reason'] : null,
            );

            return $this->outcome('synced', serverId: $session->id);
        }

        if ($name === 'movement') {
            $referenceId = isset($payload['reference_id']) && Str::isUuid((string) $payload['reference_id'])
                ? (string) $payload['reference_id']
                : $uuid;
            $existing = CashMovement::query()
                ->where('tenant_id', $store->tenant_id)
                ->where('reference_id', $referenceId)
                ->first();
            if ($existing !== null) {
                return $this->outcome('synced', serverId: $existing->id);
            }

            $type = CashMovementType::tryFrom((string) ($payload['movement_type'] ?? ''));
            if ($type === null) {
                return $this->outcome('failed', 'Type de mouvement inconnu.', retryable: false);
            }

            $shiftId = isset($payload['cashier_shift_id']) ? (string) $payload['cashier_shift_id'] : '';
            $shift = $shiftId !== ''
                ? CashierShift::query()->where('cash_register_id', $register->id)->whereKey($shiftId)->first()
                : $register->openCashierShift()->first();

            if ($shift === null) {
                return $this->outcome('failed', 'No open cashier shift.', retryable: true);
            }

            $movement = $this->shifts->recordMovement(
                $register,
                $shift,
                $type,
                (int) ($payload['amount'] ?? 0),
                $actor,
                isset($payload['description']) ? (string) $payload['description'] : null,
                isset($payload['reference']) ? (string) $payload['reference'] : null,
                'offline_transaction',
                $referenceId,
            );

            return $this->outcome('synced', serverId: $movement->id);
        }

        return $this->outcome('conflict', 'Opération de caisse non prise en charge.', 'unsupported');
    }

    /** @return array<string, mixed>|null */
    private function authorize(User $user, string $domain): ?array
    {
        if (in_array($domain, ['pos', 'cash_register'], true)
            && ! $this->authorization->hasPermission($user, 'sales.create')) {
            return $this->outcome('failed', 'Permission refusée.', retryable: false);
        }

        if (in_array($domain, ['restaurant', 'hotel'], true)
            && ! $this->authorization->hasAnyPermission($user, ['sales.create', 'sales.view'])) {
            return $this->outcome('failed', 'Permission refusée.', retryable: false);
        }

        return null;
    }

    /** @return array<string, mixed> */
    private function fromValidation(ValidationException $exception): array
    {
        $errors = $exception->errors();
        $key = (string) array_key_first($errors);
        $message = (string) (collect($errors)->flatten()->first() ?? $exception->getMessage());
        $lower = strtolower($message);
        $retryable = str_contains($lower, 'not found')
            || str_contains($lower, 'introuvable')
            || str_contains($lower, 'no open')
            || str_contains($lower, 'aucune session')
            || str_contains($lower, 'aucune caisse');

        if (str_contains($lower, 'stock') || str_contains($lower, 'insuffisant')) {
            return $this->outcome('conflict', $message, 'stock');
        }

        if (in_array($key, self::STATE_KEYS, true) && ! $retryable) {
            return $this->outcome('conflict', $message, 'state_conflict');
        }

        return $this->outcome('failed', $message, retryable: $retryable || $key === 'sale');
    }

    /**
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $outcome
     * @return array<string, mixed>
     */
    private function envelope(array $operation, array $outcome): array
    {
        $uuid = (string) ($operation['client_uuid'] ?? $operation['id'] ?? '');
        $serverId = $outcome['server_id'] ?? null;

        return [
            'id' => (string) ($operation['id'] ?? $uuid),
            'uuid' => $uuid,
            'transaction_id' => $serverId,
            'idempotency_key' => $uuid,
            'entity_id' => (string) ($operation['entity_id'] ?? ''),
            'client_uuid' => $uuid,
            'status' => $outcome['status'],
            'server_id' => $serverId,
            'reference' => $outcome['reference'] ?? null,
            'error' => $outcome['error'] ?? null,
            'conflict_code' => $outcome['conflict_code'] ?? null,
            'retryable' => (bool) ($outcome['retryable'] ?? false),
            'already_processed' => (bool) ($outcome['already_processed'] ?? false),
            'message' => $outcome['message'] ?? null,
        ];
    }

    /** @param  array<string, mixed>  $result */
    private function alreadyProcessed(array $result): array
    {
        $result['already_processed'] = true;
        $result['message'] = 'Already processed';
        $result['uuid'] = $result['uuid'] ?? $result['client_uuid'] ?? $result['id'] ?? null;
        $result['transaction_id'] = $result['transaction_id'] ?? $result['server_id'] ?? null;
        $result['idempotency_key'] = $result['idempotency_key'] ?? $result['uuid'] ?? $result['client_uuid'] ?? null;

        return $result;
    }

    /**
     * @return array{status: string, error: ?string, conflict_code: ?string, retryable: bool, server_id: ?string, reference: ?string}
     */
    private function outcome(
        string $status,
        ?string $error = null,
        ?string $conflictCode = null,
        bool $retryable = false,
        ?string $serverId = null,
        ?string $reference = null,
    ): array {
        return [
            'status' => $status,
            'error' => $error,
            'conflict_code' => $conflictCode,
            'retryable' => $retryable,
            'server_id' => $serverId,
            'reference' => $reference,
        ];
    }

    /** @return array{domain: string, entity_type: string, operation: string} */
    private function classifyHttp(Request $request): array
    {
        $path = $request->path();
        $action = (string) $request->input('action', '');

        if (str_contains($path, 'hospitality/actions')) {
            $domain = in_array($action, self::RESTAURANT_ACTIONS, true) ? 'restaurant' : 'hotel';

            return ['domain' => $domain, 'entity_type' => 'desk', 'operation' => $action !== '' ? $action : 'apply'];
        }

        if (str_contains($path, 'cash-registers')) {
            return ['domain' => 'cash_register', 'entity_type' => 'cash_register', 'operation' => strtolower($request->method())];
        }

        if (str_contains($path, '/customers')) {
            return ['domain' => 'pos', 'entity_type' => 'customer', 'operation' => 'create'];
        }

        return ['domain' => 'pos', 'entity_type' => 'sale', 'operation' => strtolower($request->method())];
    }

    private function canonicalize(mixed $value): mixed
    {
        if (! is_array($value)) {
            return $value;
        }

        if (array_is_list($value)) {
            return array_map($this->canonicalize(...), $value);
        }

        ksort($value);
        foreach ($value as $key => $item) {
            $value[$key] = $this->canonicalize($item);
        }

        return $value;
    }
}
