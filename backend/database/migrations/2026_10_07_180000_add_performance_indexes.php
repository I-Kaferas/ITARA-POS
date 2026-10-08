<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $this->add('sales', ['store_id', 'status', 'completed_at'], 'sales_store_status_completed_idx', 'completed_at');
        $this->add('sales', ['tenant_id', 'status', 'completed_at'], 'sales_tenant_status_completed_idx', 'completed_at');
        $this->add('sales', ['store_id', 'order_date'], 'sales_store_order_date_idx', 'order_date');
        $this->add('products', ['catalog_id', 'name'], 'products_catalog_name_idx');
        $this->add('customers', ['tenant_id', 'phone'], 'customers_tenant_phone_idx', 'phone');
        $this->add('inventory_movements', ['warehouse_id', 'occurred_at'], 'movements_warehouse_occurred_idx');
        $this->add('cashier_shifts', ['cash_register_id', 'status'], 'shifts_register_status_idx');
        $this->add('sale_items', ['product_id', 'sale_id'], 'sale_items_product_sale_idx');
    }

    public function down(): void
    {
        $this->drop('sales', 'sales_store_status_completed_idx');
        $this->drop('sales', 'sales_tenant_status_completed_idx');
        $this->drop('sales', 'sales_store_order_date_idx');
        $this->drop('products', 'products_catalog_name_idx');
        $this->drop('customers', 'customers_tenant_phone_idx');
        $this->drop('inventory_movements', 'movements_warehouse_occurred_idx');
        $this->drop('cashier_shifts', 'shifts_register_status_idx');
        $this->drop('sale_items', 'sale_items_product_sale_idx');
    }

    /**
     * @param  list<string>  $columns
     */
    private function add(string $table, array $columns, string $name, ?string $requiredColumn = null): void
    {
        if (! Schema::hasTable($table) || Schema::hasIndex($table, $name)) {
            return;
        }

        if ($requiredColumn !== null && ! Schema::hasColumn($table, $requiredColumn)) {
            return;
        }

        foreach ($columns as $column) {
            if (! Schema::hasColumn($table, $column)) {
                return;
            }
        }

        Schema::table($table, function (Blueprint $table) use ($columns, $name): void {
            $table->index($columns, $name);
        });
    }

    private function drop(string $table, string $name): void
    {
        if (! Schema::hasTable($table) || ! Schema::hasIndex($table, $name)) {
            return;
        }

        Schema::table($table, function (Blueprint $table) use ($name): void {
            $table->dropIndex($name);
        });
    }
};
