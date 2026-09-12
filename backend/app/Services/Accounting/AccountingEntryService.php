<?php

namespace App\Services\Accounting;

use App\Enums\AccountingEntryType;
use App\Models\AccountingEntry;
use App\Models\Sale;
use App\Models\SaleReturn;
use Illuminate\Database\Eloquent\Model;

class AccountingEntryService
{
    /**
     * @return list<AccountingEntry>
     */
    public function recordPurchaseReceipt(
        Model $reference,
        int $amount,
        ?string $recordedBy = null,
    ): array {
        $tenantId = $reference->getAttribute('tenant_id');
        $occurredAt = now();

        $inventory = AccountingEntry::query()->create([
            'tenant_id' => $tenantId,
            'entry_type' => AccountingEntryType::PurchaseReceiptInventory,
            'reference_type' => $reference->getMorphClass(),
            'reference_id' => $reference->getKey(),
            'debit' => $amount,
            'credit' => 0,
            'account_code' => '1300',
            'description' => 'Inventory increase from goods receipt',
            'recorded_by' => $recordedBy,
            'occurred_at' => $occurredAt,
        ]);

        $payable = AccountingEntry::query()->create([
            'tenant_id' => $tenantId,
            'entry_type' => AccountingEntryType::PurchaseReceiptPayable,
            'reference_type' => $reference->getMorphClass(),
            'reference_id' => $reference->getKey(),
            'debit' => 0,
            'credit' => $amount,
            'account_code' => '2100',
            'description' => 'Accounts payable from goods receipt',
            'recorded_by' => $recordedBy,
            'occurred_at' => $occurredAt,
        ]);

        return [$inventory, $payable];
    }

    /**
     * @return list<AccountingEntry>
     */
    public function recordSale(Sale $sale, ?string $recordedBy = null): array
    {
        $occurredAt = $sale->completed_at ?? now();
        $entries = [];

        $entries[] = AccountingEntry::query()->create([
            'tenant_id' => $sale->tenant_id,
            'entry_type' => AccountingEntryType::SaleCash,
            'reference_type' => $sale->getMorphClass(),
            'reference_id' => $sale->getKey(),
            'debit' => $sale->total,
            'credit' => 0,
            'account_code' => '1000',
            'description' => "Cash/receivables from sale {$sale->reference}",
            'recorded_by' => $recordedBy,
            'occurred_at' => $occurredAt,
        ]);

        $entries[] = AccountingEntry::query()->create([
            'tenant_id' => $sale->tenant_id,
            'entry_type' => AccountingEntryType::SaleRevenue,
            'reference_type' => $sale->getMorphClass(),
            'reference_id' => $sale->getKey(),
            'debit' => 0,
            'credit' => $sale->subtotal - $sale->discount_total,
            'account_code' => '4000',
            'description' => "Revenue from sale {$sale->reference}",
            'recorded_by' => $recordedBy,
            'occurred_at' => $occurredAt,
        ]);

        if ($sale->tax_total > 0) {
            $entries[] = AccountingEntry::query()->create([
                'tenant_id' => $sale->tenant_id,
                'entry_type' => AccountingEntryType::SaleTax,
                'reference_type' => $sale->getMorphClass(),
                'reference_id' => $sale->getKey(),
                'debit' => 0,
                'credit' => $sale->tax_total,
                'account_code' => '2200',
                'description' => "Tax collected on sale {$sale->reference}",
                'recorded_by' => $recordedBy,
                'occurred_at' => $occurredAt,
            ]);
        }

        $cogs = $this->estimateCogs($sale);

        if ($cogs > 0) {
            $entries[] = AccountingEntry::query()->create([
                'tenant_id' => $sale->tenant_id,
                'entry_type' => AccountingEntryType::SaleCogs,
                'reference_type' => $sale->getMorphClass(),
                'reference_id' => $sale->getKey(),
                'debit' => $cogs,
                'credit' => 0,
                'account_code' => '5000',
                'description' => "COGS for sale {$sale->reference}",
                'recorded_by' => $recordedBy,
                'occurred_at' => $occurredAt,
            ]);

            $entries[] = AccountingEntry::query()->create([
                'tenant_id' => $sale->tenant_id,
                'entry_type' => AccountingEntryType::SaleInventory,
                'reference_type' => $sale->getMorphClass(),
                'reference_id' => $sale->getKey(),
                'debit' => 0,
                'credit' => $cogs,
                'account_code' => '1300',
                'description' => "Inventory decrease for sale {$sale->reference}",
                'recorded_by' => $recordedBy,
                'occurred_at' => $occurredAt,
            ]);
        }

        return $entries;
    }

    private function estimateCogs(Sale $sale): int
    {
        $sale->loadMissing('items.product');

        $cogs = 0;

        foreach ($sale->items as $item) {
            if ($item->product === null) {
                continue;
            }

            $cost = $item->product->cost_price ?? 0;
            $cogs += $cost * $item->quantity;
        }

        return $cogs;
    }

    /**
     * @return list<AccountingEntry>
     */
    public function recordSaleReturn(SaleReturn $saleReturn, ?string $recordedBy = null): array
    {
        $occurredAt = $saleReturn->completed_at ?? now();
        $entries = [];

        $entries[] = AccountingEntry::query()->create([
            'tenant_id' => $saleReturn->tenant_id,
            'entry_type' => AccountingEntryType::SaleReturnRevenue,
            'reference_type' => $saleReturn->getMorphClass(),
            'reference_id' => $saleReturn->getKey(),
            'debit' => max(0, $saleReturn->subtotal - $saleReturn->discount_total),
            'credit' => 0,
            'account_code' => '4000',
            'description' => "Revenue reversal for return {$saleReturn->return_number}",
            'recorded_by' => $recordedBy,
            'occurred_at' => $occurredAt,
        ]);

        $entries[] = AccountingEntry::query()->create([
            'tenant_id' => $saleReturn->tenant_id,
            'entry_type' => AccountingEntryType::SaleReturnCash,
            'reference_type' => $saleReturn->getMorphClass(),
            'reference_id' => $saleReturn->getKey(),
            'debit' => 0,
            'credit' => $saleReturn->total,
            'account_code' => '1000',
            'description' => "Cash/credit refund for return {$saleReturn->return_number}",
            'recorded_by' => $recordedBy,
            'occurred_at' => $occurredAt,
        ]);

        if ($saleReturn->tax_total > 0) {
            $entries[] = AccountingEntry::query()->create([
                'tenant_id' => $saleReturn->tenant_id,
                'entry_type' => AccountingEntryType::SaleReturnTax,
                'reference_type' => $saleReturn->getMorphClass(),
                'reference_id' => $saleReturn->getKey(),
                'debit' => $saleReturn->tax_total,
                'credit' => 0,
                'account_code' => '2200',
                'description' => "Tax reversal for return {$saleReturn->return_number}",
                'recorded_by' => $recordedBy,
                'occurred_at' => $occurredAt,
            ]);
        }

        $cogs = $this->estimateReturnCogs($saleReturn);

        if ($cogs > 0) {
            $entries[] = AccountingEntry::query()->create([
                'tenant_id' => $saleReturn->tenant_id,
                'entry_type' => AccountingEntryType::SaleReturnInventory,
                'reference_type' => $saleReturn->getMorphClass(),
                'reference_id' => $saleReturn->getKey(),
                'debit' => $cogs,
                'credit' => 0,
                'account_code' => '1300',
                'description' => "Inventory increase for return {$saleReturn->return_number}",
                'recorded_by' => $recordedBy,
                'occurred_at' => $occurredAt,
            ]);

            $entries[] = AccountingEntry::query()->create([
                'tenant_id' => $saleReturn->tenant_id,
                'entry_type' => AccountingEntryType::SaleReturnCogs,
                'reference_type' => $saleReturn->getMorphClass(),
                'reference_id' => $saleReturn->getKey(),
                'debit' => 0,
                'credit' => $cogs,
                'account_code' => '5000',
                'description' => "COGS reversal for return {$saleReturn->return_number}",
                'recorded_by' => $recordedBy,
                'occurred_at' => $occurredAt,
            ]);
        }

        return $entries;
    }

    private function estimateReturnCogs(SaleReturn $saleReturn): int
    {
        $saleReturn->loadMissing('items.product');

        $cogs = 0;

        foreach ($saleReturn->items as $item) {
            if ($item->product === null) {
                continue;
            }

            $cost = $item->product->cost_price ?? 0;
            $cogs += $cost * $item->quantity_returned;
        }

        return $cogs;
    }
}
