<?php

namespace App\Services\Notifications;

use App\Enums\CashierShiftStatus;
use App\Enums\CashRegisterSessionStatus;
use App\Enums\InventoryAlertStatus;
use App\Enums\InventoryAlertType;
use App\Enums\SaleStatus;
use App\Models\CashierShift;
use App\Models\CashRegisterSession;
use App\Models\CustomerTransaction;
use App\Models\DeskDocument;
use App\Models\InventoryAlert;
use App\Models\Sale;
use App\Models\SaleInstallment;
use App\Models\StockBalance;
use App\Models\SyncFailure;
use Illuminate\Support\Facades\Schema;

class NotificationWatch
{
    /** @return list<array{kind: string, title: string, detail: string}> */
    public function collect(): array
    {
        return [
            ...$this->stock(),
            ...$this->expired(),
            ...$this->syncFailed(),
            ...$this->cashOpen(),
            ...$this->creditOverdue(),
            ...$this->ordersPending(),
        ];
    }

    /** @return list<array{kind: string, title: string, detail: string}> */
    private function stock(): array
    {
        $fromAlerts = InventoryAlert::query()
            ->with('product:id,name')
            ->where('status', InventoryAlertStatus::Active)
            ->whereIn('alert_type', [InventoryAlertType::LowStock, InventoryAlertType::OutOfStock])
            ->latest()
            ->limit(20)
            ->get()
            ->map(fn (InventoryAlert $alert) => [
                'kind' => 'low_stock',
                'title' => $alert->product?->name ?? 'Stock faible',
                'detail' => $alert->alert_type === InventoryAlertType::OutOfStock ? 'Rupture' : 'Stock faible',
            ])
            ->all();

        return $this->merge($fromAlerts, $this->lowStockBalances());
    }

    /** @return list<array{kind: string, title: string, detail: string}> */
    private function expired(): array
    {
        $fromAlerts = InventoryAlert::query()
            ->with('product:id,name')
            ->where('status', InventoryAlertStatus::Active)
            ->whereIn('alert_type', [InventoryAlertType::Expired, InventoryAlertType::ExpiringSoon])
            ->latest()
            ->limit(20)
            ->get()
            ->map(fn (InventoryAlert $alert) => [
                'kind' => 'expired',
                'title' => $alert->product?->name ?? 'Produit expiré',
                'detail' => $alert->expires_at?->toDateString() ?? 'Produit expiré',
            ])
            ->all();

        return $this->merge($fromAlerts, $this->expiredBatches());
    }

    /** @return list<array{kind: string, title: string, detail: string}> */
    private function syncFailed(): array
    {
        return SyncFailure::query()
            ->whereNull('resolved_at')
            ->latest('occurred_at')
            ->limit(20)
            ->get()
            ->map(fn (SyncFailure $failure) => [
                'kind' => 'sync_failed',
                'title' => 'Sync échouée',
                'detail' => $failure->error,
            ])
            ->all();
    }

    /** @return list<array{kind: string, title: string, detail: string}> */
    private function cashOpen(): array
    {
        $sessions = CashRegisterSession::query()
            ->with('register:id,name')
            ->where('status', CashRegisterSessionStatus::Open)
            ->latest('opened_at')
            ->limit(20)
            ->get()
            ->map(fn (CashRegisterSession $session) => [
                'kind' => 'cash_open',
                'title' => $session->register?->name ?? 'Caisse ouverte',
                'detail' => 'Session ouverte',
            ]);

        if ($sessions->isNotEmpty()) {
            return $sessions->all();
        }

        return CashierShift::query()
            ->with('cashRegister:id,name')
            ->where('status', CashierShiftStatus::Open)
            ->latest('opened_at')
            ->limit(20)
            ->get()
            ->map(fn (CashierShift $shift) => [
                'kind' => 'cash_open',
                'title' => $shift->cashRegister?->name ?? 'Caisse ouverte',
                'detail' => 'Shift ouvert',
            ])
            ->all();
    }

    /** @return list<array{kind: string, title: string, detail: string}> */
    private function creditOverdue(): array
    {
        $fromLedger = CustomerTransaction::query()
            ->with('customer:id,name')
            ->whereDate('due_date', '<', now()->toDateString())
            ->whereColumn('paid_amount', '<', 'amount')
            ->whereIn('transaction_type', ['SALE', 'OPENING_BALANCE'])
            ->orderBy('due_date')
            ->limit(20)
            ->get()
            ->filter(fn (CustomerTransaction $tx) => $tx->isOverdue())
            ->map(fn (CustomerTransaction $tx) => [
                'kind' => 'credit_overdue',
                'title' => $tx->customer?->name ?? 'Crédit en retard',
                'detail' => $tx->due_date?->toDateString() ?? 'Échéance dépassée',
            ])
            ->values()
            ->all();

        return $this->merge($fromLedger, $this->overdueSales());
    }

    /** @return list<array{kind: string, title: string, detail: string}> */
    private function ordersPending(): array
    {
        $pendingSales = Sale::query()
            ->where('status', SaleStatus::Pending)
            ->latest()
            ->limit(20)
            ->get()
            ->map(fn (Sale $sale) => [
                'kind' => 'order_pending',
                'title' => $sale->reference,
                'detail' => 'Commande en attente',
            ])
            ->all();

        return $this->merge($pendingSales, $this->openDeskOrders());
    }

    /** @return list<array{kind: string, title: string, detail: string}> */
    private function lowStockBalances(): array
    {
        if (! Schema::hasTable('stock_balances')) {
            return [];
        }

        return StockBalance::query()
            ->with(['product:id,name,low_stock_threshold', 'warehouse:id,name'])
            ->where('quantity_on_hand', '>=', 0)
            ->get()
            ->filter(function (StockBalance $balance) {
                $threshold = $balance->product?->effectiveLowStockThreshold();

                return $threshold !== null && (int) $balance->quantity_on_hand <= $threshold;
            })
            ->take(20)
            ->map(fn (StockBalance $balance) => [
                'kind' => 'low_stock',
                'title' => $balance->product?->name ?? 'Stock faible',
                'detail' => 'Stock '.(int) $balance->quantity_on_hand.' · seuil '.$balance->product?->effectiveLowStockThreshold(),
            ])
            ->values()
            ->all();
    }

    /** @return list<array{kind: string, title: string, detail: string}> */
    private function expiredBatches(): array
    {
        if (! Schema::hasTable('stock_balances') || ! Schema::hasTable('batches')) {
            return [];
        }

        return StockBalance::query()
            ->with(['product:id,name', 'batch:id,batch_number,expires_at'])
            ->where('quantity_on_hand', '>', 0)
            ->whereNotNull('batch_id')
            ->get()
            ->filter(fn (StockBalance $balance) => $balance->batch?->expires_at !== null
                && $balance->batch->expires_at->lt(now()->startOfDay()))
            ->take(20)
            ->map(fn (StockBalance $balance) => [
                'kind' => 'expired',
                'title' => $balance->product?->name ?? 'Produit expiré',
                'detail' => $balance->batch?->expires_at?->toDateString() ?? 'Produit expiré',
            ])
            ->values()
            ->all();
    }

    /** @return list<array{kind: string, title: string, detail: string}> */
    private function overdueSales(): array
    {
        $items = [];
        if (Schema::hasTable('sales')) {
            $items = Sale::query()
                ->with('customer:id,name')
                ->where('status', SaleStatus::Completed)
                ->whereNotNull('due_date')
                ->whereDate('due_date', '<', now()->toDateString())
                ->whereColumn('paid_amount', '<', 'total')
                ->orderBy('due_date')
                ->limit(20)
                ->get()
                ->map(fn (Sale $sale) => [
                    'kind' => 'credit_overdue',
                    'title' => $sale->customer?->name ?? $sale->reference,
                    'detail' => $sale->due_date?->toDateString() ?? 'Échéance dépassée',
                ])
                ->all();
        }

        if (! Schema::hasTable('sale_installments')) {
            return $items;
        }

        $installments = SaleInstallment::query()
            ->with('sale.customer:id,name')
            ->whereDate('due_date', '<', now()->toDateString())
            ->whereColumn('paid_amount', '<', 'amount')
            ->orderBy('due_date')
            ->limit(20)
            ->get()
            ->map(fn (SaleInstallment $installment) => [
                'kind' => 'credit_overdue',
                'title' => $installment->sale?->customer?->name ?? $installment->sale?->reference ?? 'Crédit en retard',
                'detail' => $installment->due_date?->toDateString() ?? 'Échéance dépassée',
            ])
            ->all();

        return $this->merge($items, $installments);
    }

    /** @return list<array{kind: string, title: string, detail: string}> */
    private function openDeskOrders(): array
    {
        if (! Schema::hasTable('desk_documents')) {
            return [];
        }

        return DeskDocument::query()
            ->where('kind', 'order')
            ->whereNotIn('status', ['paid', 'closed', 'cancelled', 'voided'])
            ->latest()
            ->limit(20)
            ->get()
            ->map(function (DeskDocument $doc) {
                $payload = $doc->payload ?? [];

                return [
                    'kind' => 'order_pending',
                    'title' => (string) ($payload['table_label'] ?? $payload['reference'] ?? $doc->code),
                    'detail' => 'Commande en attente',
                ];
            })
            ->all();
    }

    /**
     * @param  list<array{kind: string, title: string, detail: string}>  $left
     * @param  list<array{kind: string, title: string, detail: string}>  $right
     * @return list<array{kind: string, title: string, detail: string}>
     */
    private function merge(array $left, array $right): array
    {
        $seen = [];
        $items = [];
        foreach ([...$left, ...$right] as $item) {
            $key = $item['kind'].'|'.$item['title'].'|'.$item['detail'];
            if (isset($seen[$key])) {
                continue;
            }
            $seen[$key] = true;
            $items[] = $item;
            if (count($items) >= 20) {
                break;
            }
        }

        return $items;
    }
}
