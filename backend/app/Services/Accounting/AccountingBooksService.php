<?php

namespace App\Services\Accounting;

use App\Models\Expense;
use App\Models\Sale;
use App\Models\SalePayment;
use App\Models\StockBalance;
use App\Models\SupplierPayment;
use App\Services\Payable\PayableService;
use Illuminate\Support\Facades\Schema;

class AccountingBooksService
{
    public function __construct(private readonly PayableService $payables) {}

    /**
     * @return list<array{code: string, balance: int}>
     */
    public function books(string $tenantId, ?string $from = null, ?string $to = null): array
    {
        $sales = $this->sales($tenantId, $from, $to);
        $revenue = (int) $sales->sum('total');
        $receivable = (int) $this->openSales($tenantId)->sum(fn (Sale $sale) => $sale->outstandingAmount());
        $expenses = $this->expenses($tenantId, $from, $to);
        $expenseTotal = (int) $expenses->sum('amount');
        $cashExpenses = (int) $expenses
            ->filter(fn (Expense $expense) => $expense->cash_register_session_id !== null)
            ->sum('amount');
        $payable = max(0, ($expenseTotal - $cashExpenses) + $this->supplierDebt($tenantId));
        $cash = $this->collected($sales) - $cashExpenses - $this->supplierPayments($tenantId, $from, $to);
        $inventory = $this->inventory();
        $profit = $revenue - $expenseTotal;

        return [
            ['code' => 'revenue', 'balance' => $revenue],
            ['code' => 'expense', 'balance' => $expenseTotal],
            ['code' => 'receivable', 'balance' => $receivable],
            ['code' => 'payable', 'balance' => $payable],
            ['code' => 'cash', 'balance' => $cash],
            ['code' => 'inventory', 'balance' => $inventory],
            ['code' => 'profit', 'balance' => $profit],
        ];
    }

    /** @return \Illuminate\Support\Collection<int, Sale> */
    private function sales(string $tenantId, ?string $from, ?string $to)
    {
        if (! Schema::hasTable('sales')) {
            return collect();
        }

        $query = Sale::query()->where('tenant_id', $tenantId)->where('status', 'completed');
        if ($from) {
            $query->where('completed_at', '>=', $from);
        }
        if ($to) {
            $query->where('completed_at', '<=', $to.' 23:59:59');
        }

        return $query->get(['id', 'total', 'paid_amount']);
    }

    /** @return \Illuminate\Support\Collection<int, Sale> */
    private function openSales(string $tenantId)
    {
        if (! Schema::hasTable('sales')) {
            return collect();
        }

        return Sale::query()
            ->where('tenant_id', $tenantId)
            ->where('status', 'completed')
            ->whereColumn('paid_amount', '<', 'total')
            ->get(['id', 'total', 'paid_amount']);
    }

    /** @return \Illuminate\Support\Collection<int, Expense> */
    private function expenses(string $tenantId, ?string $from, ?string $to)
    {
        if (! Schema::hasTable('branch_expenses')) {
            return collect();
        }

        $query = Expense::query()->where('tenant_id', $tenantId);
        if ($from) {
            $query->whereDate('occurred_on', '>=', $from);
        }
        if ($to) {
            $query->whereDate('occurred_on', '<=', $to);
        }

        return $query->get(['id', 'amount', 'cash_register_session_id']);
    }

    /** @param  \Illuminate\Support\Collection<int, Sale>  $sales */
    private function collected($sales): int
    {
        if ($sales->isEmpty()) {
            return 0;
        }

        if (! Schema::hasTable('sale_payments')) {
            return (int) $sales->sum('paid_amount');
        }

        return (int) SalePayment::query()
            ->whereIn('sale_id', $sales->pluck('id'))
            ->where('payment_method', '!=', 'credit')
            ->sum('amount');
    }

    private function supplierPayments(string $tenantId, ?string $from, ?string $to): int
    {
        if (! Schema::hasTable('supplier_payments')) {
            return 0;
        }

        $query = SupplierPayment::query()
            ->where('tenant_id', $tenantId)
            ->where('status', 'completed');
        if ($from) {
            $query->where('paid_at', '>=', $from);
        }
        if ($to) {
            $query->where('paid_at', '<=', $to.' 23:59:59');
        }

        return (int) $query->sum('amount');
    }

    private function supplierDebt(string $tenantId): int
    {
        try {
            return (int) ($this->payables->summary($tenantId)['total_debt'] ?? 0);
        } catch (\Throwable) {
            return 0;
        }
    }

    private function inventory(): int
    {
        if (! Schema::hasTable('stock_balances')) {
            return 0;
        }

        return (int) StockBalance::query()
            ->with('product:id,base_price,cost_price')
            ->get()
            ->sum(function (StockBalance $balance) {
                $price = (int) ($balance->product?->cost_price ?: $balance->product?->base_price ?: 0);
                return max(0, (int) $balance->quantity_on_hand) * $price;
            });
    }
}
