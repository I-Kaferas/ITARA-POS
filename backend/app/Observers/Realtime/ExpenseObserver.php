<?php

namespace App\Observers\Realtime;

use App\Models\BranchExpense;
use App\Services\Realtime\RealtimePublisher;

class ExpenseObserver
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function created(BranchExpense $expense): void
    {
        $this->publish($expense, 'expense.created');
    }

    public function updated(BranchExpense $expense): void
    {
        $this->publish($expense, 'expense.updated');
    }

    private function publish(BranchExpense $expense, string $type): void
    {
        $this->publisher->notify(
            type: $type,
            tenantId: $expense->tenant_id,
            storeId: $expense->store_id,
            entity: 'expense',
            id: $expense->id,
            data: [
                'amount' => $expense->amount,
                'expense_category_id' => $expense->expense_category_id,
            ],
        );
    }
}
