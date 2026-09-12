<?php

namespace App\Services\Payable;

use App\Models\Supplier;
use App\Models\SupplierPayment;
use App\Models\SupplierTransaction;
use App\Services\Supplier\SupplierLedgerService;
use Illuminate\Support\Collection;

class PayableService
{
    public function __construct(
        private readonly SupplierLedgerService $ledger,
    ) {}

    /**
     * Tenant-wide accounts payable summary.
     *
     * @return array{
     *     total_debt: int,
     *     total_overdue: int,
     *     open_invoices: int,
     *     overdue_invoices: int,
     *     suppliers_with_debt: int,
     *     suppliers: list<array<string, mixed>>,
     * }
     */
    public function summary(string $tenantId): array
    {
        $suppliers = Supplier::query()
            ->where('tenant_id', $tenantId)
            ->where('is_active', true)
            ->orderBy('name')
            ->get();

        $supplierSummaries = [];
        $totalDebt = 0;
        $totalOverdue = 0;
        $openInvoices = 0;
        $overdueInvoices = 0;
        $suppliersWithDebt = 0;

        foreach ($suppliers as $supplier) {
            $summary = $this->ledger->summary($supplier);

            if ($summary['debt'] <= 0) {
                continue;
            }

            $overdueAmount = $this->ledger->dueTransactions($supplier, overdueOnly: true)
                ->sum(fn (SupplierTransaction $tx) => $tx->outstandingAmount());

            $suppliersWithDebt++;
            $totalDebt += $summary['debt'];
            $totalOverdue += $overdueAmount;
            $openInvoices += $summary['open_invoices'];
            $overdueInvoices += $summary['overdue_invoices'];

            $supplierSummaries[] = [
                'supplier_id' => $supplier->id,
                'supplier_name' => $supplier->name,
                'supplier_code' => $supplier->code,
                'debt' => $summary['debt'],
                'credit' => $summary['credit'],
                'overdue_amount' => $overdueAmount,
                'open_invoices' => $summary['open_invoices'],
                'overdue_invoices' => $summary['overdue_invoices'],
            ];
        }

        usort($supplierSummaries, fn ($a, $b) => $b['debt'] <=> $a['debt']);

        return [
            'total_debt' => $totalDebt,
            'total_overdue' => $totalOverdue,
            'open_invoices' => $openInvoices,
            'overdue_invoices' => $overdueInvoices,
            'suppliers_with_debt' => $suppliersWithDebt,
            'suppliers' => $supplierSummaries,
        ];
    }

    /**
     * Payment schedule across all suppliers (open and overdue items).
     *
     * @return list<array<string, mixed>>
     */
    public function schedule(string $tenantId, bool $overdueOnly = false): array
    {
        $suppliers = Supplier::query()
            ->where('tenant_id', $tenantId)
            ->where('is_active', true)
            ->orderBy('name')
            ->get();

        $items = [];

        foreach ($suppliers as $supplier) {
            foreach ($this->ledger->dueTransactions($supplier, overdueOnly: $overdueOnly) as $tx) {
                $items[] = [
                    'id' => $tx->id,
                    'supplier_id' => $supplier->id,
                    'supplier_name' => $supplier->name,
                    'supplier_code' => $supplier->code,
                    'reference' => $tx->reference,
                    'due_date' => $tx->due_date?->toDateString(),
                    'amount' => $tx->amount,
                    'outstanding' => $tx->outstandingAmount(),
                    'is_overdue' => $tx->isOverdue(),
                ];
            }
        }

        usort($items, fn ($a, $b) => strcmp($a['due_date'] ?? '', $b['due_date'] ?? ''));

        return $items;
    }

    /**
     * Recent supplier payments for the tenant.
     *
     * @return Collection<int, SupplierPayment>
     */
    public function recentPayments(string $tenantId, int $limit = 25): Collection
    {
        return SupplierPayment::query()
            ->where('tenant_id', $tenantId)
            ->with(['supplier:id,name,code', 'recordedBy:id,name'])
            ->orderByDesc('paid_at')
            ->limit($limit)
            ->get();
    }
}
