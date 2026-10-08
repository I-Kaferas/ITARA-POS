<?php

namespace App\Services\Notifications;

use App\Enums\InventoryAlertStatus;
use App\Enums\InventoryAlertType;
use App\Enums\NotificationEvent;
use App\Enums\PaymentTransactionStatus;
use App\Enums\PurchaseRequisitionStatus;
use App\Enums\SaleStatus;
use App\Models\DeskDocument;
use App\Models\InventoryAlert;
use App\Models\InventoryVerificationFinding;
use App\Models\PaymentTransaction;
use App\Models\PosReservation;
use App\Models\PurchaseRequisition;
use App\Models\Sale;
use App\Models\SyncFailure;
use App\Models\User;
use App\Tenancy\TenantCache;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Schema;

class NotificationDigest
{
    public function __construct(private readonly NotificationCenter $center) {}

    public function scanIfDue(): void
    {
        $cache = app(TenantCache::class);
        $key = $cache->key('notification-digest');
        if (! Cache::add($key, 1, 60)) {
            return;
        }

        try {
            $this->scan();
        } catch (\Throwable $exception) {
            Cache::forget($key);
            report($exception);
        }
    }

    public function scan(): void
    {
        $users = User::query()->where('is_active', true)->get();
        if ($users->isEmpty()) {
            return;
        }

        foreach ($this->notices() as $notice) {
            $this->center->notify(
                $notice['event'],
                $notice['title'],
                $notice['body'],
                $notice['context'],
                $notice['fingerprint'],
                $users,
            );
        }
    }

    /**
     * @return list<array{event: NotificationEvent, title: string, body: string, context: array<string, mixed>, fingerprint: string}>
     */
    private function notices(): array
    {
        return [
            ...$this->guard(fn () => $this->orders()),
            ...$this->guard(fn () => $this->payments()),
            ...$this->guard(fn () => $this->lowStock()),
            ...$this->guard(fn () => $this->reservations()),
            ...$this->guard(fn () => $this->unpaidInvoices()),
            ...$this->guard(fn () => $this->approvals()),
            ...$this->guard(fn () => $this->anomalies()),
            ...$this->guard(fn () => $this->maintenance()),
        ];
    }

    /** @return list<array{event: NotificationEvent, title: string, body: string, context: array<string, mixed>, fingerprint: string}> */
    private function orders(): array
    {
        if (! Schema::hasTable('sales')) {
            return [];
        }

        return Sale::query()
            ->where('status', SaleStatus::Pending)
            ->latest()
            ->limit(20)
            ->get()
            ->map(fn (Sale $sale) => $this->notice(
                NotificationEvent::NewOrder,
                $sale->reference ?: 'Commande',
                'Commande en attente',
                'new_order:'.$sale->id,
                ['sale_id' => $sale->id],
            ))
            ->all();
    }

    /** @return list<array{event: NotificationEvent, title: string, body: string, context: array<string, mixed>, fingerprint: string}> */
    private function payments(): array
    {
        if (! Schema::hasTable('payment_transactions')) {
            return [];
        }

        return PaymentTransaction::query()
            ->where('status', PaymentTransactionStatus::Completed)
            ->where('created_at', '>=', now()->subDays(2))
            ->latest()
            ->limit(20)
            ->get()
            ->map(function (PaymentTransaction $payment) {
                $fingerprint = 'payment:'.($payment->transaction_number ?: $payment->id);

                return $this->notice(
                    NotificationEvent::Payment,
                    $payment->transaction_number,
                    trim($payment->amount.' '.$payment->currency),
                    $fingerprint,
                    ['payment_id' => $payment->id, 'sale_id' => $payment->sale_id],
                );
            })
            ->all();
    }

    /** @return list<array{event: NotificationEvent, title: string, body: string, context: array<string, mixed>, fingerprint: string}> */
    private function lowStock(): array
    {
        if (! Schema::hasTable('inventory_alerts')) {
            return [];
        }

        return InventoryAlert::query()
            ->with('product:id,name')
            ->where('status', InventoryAlertStatus::Active)
            ->whereIn('alert_type', [InventoryAlertType::LowStock, InventoryAlertType::OutOfStock])
            ->latest()
            ->limit(20)
            ->get()
            ->map(function (InventoryAlert $alert) {
                $kind = $alert->alert_type === InventoryAlertType::OutOfStock ? 'Rupture' : 'Stock faible';

                return $this->notice(
                    NotificationEvent::LowStock,
                    $alert->product?->name ?? 'Stock faible',
                    trim($kind.' · '.(int) $alert->quantity_on_hand),
                    'low_stock:'.$alert->id,
                    ['alert_id' => $alert->id, 'product_id' => $alert->product_id],
                );
            })
            ->all();
    }

    /** @return list<array{event: NotificationEvent, title: string, body: string, context: array<string, mixed>, fingerprint: string}> */
    private function reservations(): array
    {
        $items = [];

        if (Schema::hasTable('pos_reservations')) {
            $items = PosReservation::query()
                ->whereIn('status', ['pending', 'confirmed'])
                ->latest('reserved_at')
                ->limit(20)
                ->get()
                ->map(fn (PosReservation $reservation) => $this->notice(
                    NotificationEvent::Reservation,
                    $reservation->guest_name ?: ($reservation->reference ?: 'Réservation'),
                    trim(($reservation->party_size ? $reservation->party_size.' pers. · ' : '').($reservation->reserved_at?->format('d/m/Y H:i') ?? '')),
                    'reservation:pos:'.$reservation->id,
                    ['reservation_id' => $reservation->id],
                ))
                ->all();
        }

        if (! Schema::hasTable('desk_documents')) {
            return $items;
        }

        $hotel = DeskDocument::query()
            ->where('kind', 'reservation')
            ->whereNotIn('status', ['cancelled', 'checked_out', 'completed', 'no_show', 'voided'])
            ->latest()
            ->limit(20)
            ->get()
            ->map(function (DeskDocument $document) {
                $payload = $document->payload ?? [];

                return $this->notice(
                    NotificationEvent::Reservation,
                    (string) ($payload['guest_name'] ?? $payload['guest'] ?? $payload['reference'] ?? $document->code),
                    'Réservation hôtel',
                    'reservation:desk:'.$document->id,
                    ['document_id' => $document->id],
                );
            })
            ->all();

        return [...$items, ...$hotel];
    }

    /** @return list<array{event: NotificationEvent, title: string, body: string, context: array<string, mixed>, fingerprint: string}> */
    private function unpaidInvoices(): array
    {
        if (! Schema::hasTable('sales')) {
            return [];
        }

        return Sale::query()
            ->where('status', SaleStatus::Completed)
            ->whereNotNull('due_date')
            ->whereDate('due_date', '<', now()->toDateString())
            ->whereColumn('paid_amount', '<', 'total')
            ->orderBy('due_date')
            ->limit(20)
            ->get()
            ->map(fn (Sale $sale) => $this->notice(
                NotificationEvent::UnpaidInvoice,
                $sale->reference ?: 'Facture',
                'Échéance '.$sale->due_date?->toDateString(),
                'unpaid_invoice:'.$sale->id,
                ['sale_id' => $sale->id],
            ))
            ->all();
    }

    /** @return list<array{event: NotificationEvent, title: string, body: string, context: array<string, mixed>, fingerprint: string}> */
    private function approvals(): array
    {
        if (! Schema::hasTable('purchase_requisitions')) {
            return [];
        }

        return PurchaseRequisition::query()
            ->where('status', PurchaseRequisitionStatus::Submitted)
            ->latest('submitted_at')
            ->limit(20)
            ->get()
            ->map(fn (PurchaseRequisition $requisition) => $this->notice(
                NotificationEvent::Approval,
                $requisition->number ?: 'Demande d\'achat',
                'En attente d\'approbation',
                'approval:'.$requisition->id,
                ['requisition_id' => $requisition->id],
            ))
            ->all();
    }

    /** @return list<array{event: NotificationEvent, title: string, body: string, context: array<string, mixed>, fingerprint: string}> */
    private function anomalies(): array
    {
        $items = [];

        if (Schema::hasTable('sync_failures')) {
            $items = SyncFailure::query()
                ->whereNull('resolved_at')
                ->latest('occurred_at')
                ->limit(20)
                ->get()
                ->map(fn (SyncFailure $failure) => $this->notice(
                    NotificationEvent::Anomaly,
                    'Sync échouée',
                    (string) $failure->error,
                    'anomaly:sync:'.$failure->id,
                    ['sync_failure_id' => $failure->id],
                ))
                ->all();
        }

        if (! Schema::hasTable('inventory_verification_findings')) {
            return $items;
        }

        $findings = InventoryVerificationFinding::query()
            ->whereNull('resolved_at')
            ->latest()
            ->limit(20)
            ->get()
            ->map(fn (InventoryVerificationFinding $finding) => $this->notice(
                NotificationEvent::Anomaly,
                $finding->title ?: 'Anomalie',
                (string) ($finding->message ?: $finding->code),
                'anomaly:finding:'.$finding->id,
                ['finding_id' => $finding->id],
            ))
            ->all();

        return [...$items, ...$findings];
    }

    /** @return list<array{event: NotificationEvent, title: string, body: string, context: array<string, mixed>, fingerprint: string}> */
    private function maintenance(): array
    {
        if (! Schema::hasTable('desk_documents')) {
            return [];
        }

        $tasks = DeskDocument::query()
            ->where('kind', 'housekeeping_task')
            ->whereIn('status', ['pending', 'assigned', 'in_progress'])
            ->where('payload->type', 'maintenance')
            ->latest()
            ->limit(20)
            ->get()
            ->map(function (DeskDocument $document) {
                $payload = $document->payload ?? [];

                return $this->notice(
                    NotificationEvent::Maintenance,
                    (string) ($payload['title'] ?? $payload['room_number'] ?? 'Maintenance'),
                    'Intervention ouverte',
                    'maintenance:task:'.$document->id,
                    ['document_id' => $document->id],
                );
            })
            ->all();

        $rooms = DeskDocument::query()
            ->where('kind', 'room')
            ->where('payload->housekeeping_status', 'maintenance')
            ->latest()
            ->limit(20)
            ->get()
            ->map(function (DeskDocument $document) {
                $payload = $document->payload ?? [];

                return $this->notice(
                    NotificationEvent::Maintenance,
                    'Chambre '.(string) ($payload['number'] ?? $payload['name'] ?? $document->code),
                    'En maintenance',
                    'maintenance:room:'.$document->id,
                    ['document_id' => $document->id],
                );
            })
            ->all();

        return [...$tasks, ...$rooms];
    }

    /**
     * @param  array<string, mixed>  $context
     * @return array{event: NotificationEvent, title: string, body: string, context: array<string, mixed>, fingerprint: string}
     */
    private function notice(NotificationEvent $event, string $title, string $body, string $fingerprint, array $context = []): array
    {
        return [
            'event' => $event,
            'title' => $title !== '' ? $title : $event->title(),
            'body' => $body !== '' ? $body : $event->title(),
            'context' => $context + ['link' => $event->link()],
            'fingerprint' => $fingerprint,
        ];
    }

    /**
     * @param  callable(): list<array{event: NotificationEvent, title: string, body: string, context: array<string, mixed>, fingerprint: string}>  $callback
     * @return list<array{event: NotificationEvent, title: string, body: string, context: array<string, mixed>, fingerprint: string}>
     */
    private function guard(callable $callback): array
    {
        try {
            return $callback();
        } catch (\Throwable $exception) {
            report($exception);

            return [];
        }
    }
}
