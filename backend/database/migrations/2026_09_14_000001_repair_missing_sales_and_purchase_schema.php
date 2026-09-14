<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $this->addSalesColumns();
        $this->addProductColumns();
        $this->createPurchaseOrders();
        $this->createSaleItems();
        $this->createGoodsReceipts();
        $this->createPurchaseInvoices();
        $this->createSalePayments();
        $this->createSaleTaxes();
        $this->addSupplierTransactionOrder();
        $this->copyLegacyPurchases();
    }

    public function down(): void
    {
        Schema::dropIfExists('sale_taxes');
        Schema::dropIfExists('sale_payments');
        Schema::dropIfExists('purchase_payments');
        Schema::dropIfExists('purchase_invoices');
        Schema::dropIfExists('goods_receipt_items');
        Schema::dropIfExists('goods_receipts');
        Schema::dropIfExists('purchase_order_items');
        Schema::dropIfExists('purchase_orders');
        Schema::dropIfExists('sale_items');
    }

    private function addSalesColumns(): void
    {
        if (! Schema::hasTable('sales')) {
            return;
        }

        Schema::table('sales', function (Blueprint $table) {
            if (! Schema::hasColumn('sales', 'warehouse_id')) {
                $table->uuid('warehouse_id')->nullable();
            }
            if (! Schema::hasColumn('sales', 'cash_register_id')) {
                $table->uuid('cash_register_id')->nullable();
            }
            if (! Schema::hasColumn('sales', 'cashier_shift_id')) {
                $table->uuid('cashier_shift_id')->nullable();
            }
            if (! Schema::hasColumn('sales', 'device_id')) {
                $table->uuid('device_id')->nullable();
            }
            if (! Schema::hasColumn('sales', 'processed_by')) {
                $table->uuid('processed_by')->nullable();
            }
            if (! Schema::hasColumn('sales', 'subtotal')) {
                $table->bigInteger('subtotal')->default(0);
            }
            if (! Schema::hasColumn('sales', 'tax_total')) {
                $table->bigInteger('tax_total')->default(0);
            }
            if (! Schema::hasColumn('sales', 'discount_total')) {
                $table->bigInteger('discount_total')->default(0);
            }
            if (! Schema::hasColumn('sales', 'fees_total')) {
                $table->bigInteger('fees_total')->default(0);
            }
            if (! Schema::hasColumn('sales', 'currency')) {
                $table->char('currency', 3)->default('FBU');
            }
            if (! Schema::hasColumn('sales', 'payment_transaction_number')) {
                $table->string('payment_transaction_number', 40)->nullable();
            }
            if (! Schema::hasColumn('sales', 'idempotency_key')) {
                $table->string('idempotency_key', 100)->nullable();
            }
            if (! Schema::hasColumn('sales', 'completed_at')) {
                $table->timestamp('completed_at')->nullable();
            }
            if (! Schema::hasColumn('sales', 'notes')) {
                $table->text('notes')->nullable();
            }
        });

        if (Schema::hasColumn('sales', 'subtotal') && Schema::hasColumn('sales', 'total')) {
            DB::table('sales')->where('subtotal', 0)->where('total', '!=', 0)->update([
                'subtotal' => DB::raw('total'),
            ]);
        }
    }

    private function addProductColumns(): void
    {
        if (! Schema::hasTable('products')) {
            return;
        }

        Schema::table('products', function (Blueprint $table) {
            if (! Schema::hasColumn('products', 'bottle_volume_ml')) {
                $table->unsignedInteger('bottle_volume_ml')->nullable();
            }
            if (! Schema::hasColumn('products', 'inventory_class')) {
                $table->string('inventory_class', 1)->nullable();
            }
            if (! Schema::hasColumn('products', 'count_frequency')) {
                $table->string('count_frequency', 20)->nullable();
            }
            if (! Schema::hasColumn('products', 'last_counted_at')) {
                $table->date('last_counted_at')->nullable();
            }
            if (! Schema::hasColumn('products', 'next_count_at')) {
                $table->date('next_count_at')->nullable();
            }
        });
    }

    private function createPurchaseOrders(): void
    {
        if (! Schema::hasTable('purchase_orders')) {
            Schema::create('purchase_orders', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->uuid('branch_id')->nullable();
                $table->foreignUuid('supplier_id')->nullable()->constrained('suppliers')->nullOnDelete();
                $table->foreignUuid('warehouse_id')->nullable()->constrained('warehouses')->nullOnDelete();
                $table->string('order_number', 40);
                $table->string('reference', 100)->nullable();
                $table->string('status', 30)->default('draft');
                $table->bigInteger('subtotal')->default(0);
                $table->bigInteger('tax_total')->default(0);
                $table->bigInteger('total')->default(0);
                $table->date('due_date')->nullable();
                $table->text('notes')->nullable();
                $table->timestamp('ordered_at')->nullable();
                $table->timestamp('expected_at')->nullable();
                $table->timestamp('submitted_at')->nullable();
                $table->timestamp('approved_at')->nullable();
                $table->timestamp('completed_at')->nullable();
                $table->uuid('created_by')->nullable();
                $table->uuid('approved_by')->nullable();
                $table->timestamps();
                $table->softDeletes();

                $table->unique(['tenant_id', 'order_number']);
                $table->index(['tenant_id', 'status']);
                $table->index(['tenant_id', 'supplier_id']);
            });
        }

        if (! Schema::hasTable('purchase_order_items')) {
            Schema::create('purchase_order_items', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->foreignUuid('purchase_order_id')->constrained('purchase_orders')->cascadeOnDelete();
                $table->foreignUuid('product_id')->constrained('products')->restrictOnDelete();
                $table->uuid('product_variant_id')->nullable();
                $table->integer('quantity_ordered');
                $table->integer('quantity_received')->default(0);
                $table->bigInteger('unit_cost')->default(0);
                $table->decimal('tax_rate', 8, 4)->default(0);
                $table->bigInteger('line_total')->default(0);
                $table->unsignedSmallInteger('sort_order')->default(0);
                $table->timestamps();

                $table->index(['purchase_order_id', 'sort_order']);
            });
        }
    }

    private function createSaleItems(): void
    {
        if (Schema::hasTable('sale_items')) {
            return;
        }

        Schema::create('sale_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('sale_id')->constrained('sales')->cascadeOnDelete();
            $table->foreignUuid('product_id')->nullable()->constrained('products')->nullOnDelete();
            $table->uuid('product_variant_id')->nullable();
            $table->string('product_name');
            $table->string('product_sku', 120)->nullable();
            $table->integer('quantity');
            $table->uuid('sale_unit_id')->nullable();
            $table->string('sale_unit_name')->nullable();
            $table->integer('volume_ml')->nullable();
            $table->bigInteger('unit_price')->default(0);
            $table->string('price_type', 30)->default('retail');
            $table->bigInteger('catalog_price')->default(0);
            $table->decimal('tax_rate', 8, 4)->default(0);
            $table->bigInteger('line_subtotal')->default(0);
            $table->bigInteger('line_tax')->default(0);
            $table->bigInteger('line_total')->default(0);
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->timestamps();

            $table->index(['sale_id', 'sort_order']);
            $table->index(['tenant_id', 'product_id']);
        });
    }

    private function createGoodsReceipts(): void
    {
        if (! Schema::hasTable('goods_receipts')) {
            Schema::create('goods_receipts', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->foreignUuid('purchase_order_id')->constrained('purchase_orders')->cascadeOnDelete();
                $table->foreignUuid('warehouse_id')->nullable()->constrained('warehouses')->nullOnDelete();
                $table->string('receipt_number', 40);
                $table->string('status', 20)->default('completed');
                $table->uuid('received_by')->nullable();
                $table->timestamp('received_at')->nullable();
                $table->text('notes')->nullable();
                $table->timestamp('created_at')->nullable();

                $table->unique(['tenant_id', 'receipt_number']);
                $table->index(['purchase_order_id']);
            });
        }

        if (! Schema::hasTable('goods_receipt_items')) {
            Schema::create('goods_receipt_items', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->foreignUuid('goods_receipt_id')->constrained('goods_receipts')->cascadeOnDelete();
                $table->foreignUuid('purchase_order_item_id')->constrained('purchase_order_items')->restrictOnDelete();
                $table->foreignUuid('product_id')->constrained('products')->restrictOnDelete();
                $table->uuid('product_variant_id')->nullable();
                $table->uuid('batch_id')->nullable();
                $table->integer('quantity_received');
                $table->bigInteger('unit_cost')->default(0);
                $table->timestamp('created_at')->nullable();
            });
        }
    }

    private function createPurchaseInvoices(): void
    {
        if (! Schema::hasTable('purchase_invoices')) {
            Schema::create('purchase_invoices', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->foreignUuid('purchase_order_id')->nullable()->constrained('purchase_orders')->nullOnDelete();
                $table->foreignUuid('goods_receipt_id')->nullable()->constrained('goods_receipts')->nullOnDelete();
                $table->foreignUuid('supplier_id')->constrained('suppliers')->restrictOnDelete();
                $table->uuid('supplier_transaction_id')->nullable();
                $table->string('invoice_number', 40);
                $table->string('supplier_invoice_number', 80)->nullable();
                $table->string('status', 20)->default('posted');
                $table->bigInteger('subtotal')->default(0);
                $table->bigInteger('tax_total')->default(0);
                $table->bigInteger('total')->default(0);
                $table->bigInteger('paid_amount')->default(0);
                $table->date('due_date')->nullable();
                $table->timestamp('invoiced_at')->nullable();
                $table->timestamps();

                $table->unique(['tenant_id', 'invoice_number']);
                $table->index(['supplier_id', 'status']);
            });
        }

        if (! Schema::hasTable('purchase_payments')) {
            Schema::create('purchase_payments', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->foreignUuid('purchase_invoice_id')->constrained('purchase_invoices')->cascadeOnDelete();
                $table->uuid('supplier_payment_id')->nullable();
                $table->string('payment_number', 40);
                $table->bigInteger('amount');
                $table->string('payment_method', 30)->nullable();
                $table->string('reference')->nullable();
                $table->text('notes')->nullable();
                $table->timestamp('paid_at')->nullable();
                $table->uuid('recorded_by')->nullable();
                $table->timestamp('created_at')->nullable();

                $table->unique(['tenant_id', 'payment_number']);
            });
        }
    }

    private function createSalePayments(): void
    {
        if (Schema::hasTable('sale_payments')) {
            return;
        }

        Schema::create('sale_payments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('sale_id')->constrained('sales')->cascadeOnDelete();
            $table->uuid('payment_transaction_id')->nullable();
            $table->string('payment_method', 30);
            $table->bigInteger('amount');
            $table->char('currency', 3)->default('FBU');
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->timestamps();

            $table->index(['sale_id', 'sort_order']);
        });
    }

    private function createSaleTaxes(): void
    {
        if (Schema::hasTable('sale_taxes')) {
            return;
        }

        Schema::create('sale_taxes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('sale_id')->constrained('sales')->cascadeOnDelete();
            $table->uuid('sale_item_id')->nullable();
            $table->uuid('tax_id')->nullable();
            $table->string('tax_name')->nullable();
            $table->decimal('tax_rate', 8, 4)->default(0);
            $table->bigInteger('taxable_amount')->default(0);
            $table->bigInteger('tax_amount')->default(0);
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->timestamps();

            $table->index(['sale_id', 'sort_order']);
        });
    }

    private function addSupplierTransactionOrder(): void
    {
        if (! Schema::hasTable('supplier_transactions') || Schema::hasColumn('supplier_transactions', 'purchase_order_id')) {
            return;
        }

        Schema::table('supplier_transactions', function (Blueprint $table) {
            $table->uuid('purchase_order_id')->nullable();
        });
    }

    private function copyLegacyPurchases(): void
    {
        if (! Schema::hasTable('purchases') || ! Schema::hasTable('purchase_orders')) {
            return;
        }

        foreach (DB::table('purchases')->get() as $row) {
            if (DB::table('purchase_orders')->where('id', $row->id)->exists()) {
                continue;
            }

            $orderNumber = (string) $row->reference;
            $taken = DB::table('purchase_orders')
                ->where('tenant_id', $row->tenant_id)
                ->where('order_number', $orderNumber)
                ->exists();
            if ($taken) {
                $orderNumber = $orderNumber.'-'.substr((string) $row->id, 0, 8);
            }

            DB::table('purchase_orders')->insert([
                'id' => $row->id,
                'tenant_id' => $row->tenant_id,
                'supplier_id' => $row->supplier_id,
                'warehouse_id' => $row->warehouse_id,
                'order_number' => $orderNumber,
                'reference' => $row->reference,
                'status' => $row->status,
                'subtotal' => $row->total,
                'tax_total' => 0,
                'total' => $row->total,
                'due_date' => $row->due_date ?? null,
                'notes' => $row->notes ?? null,
                'created_at' => $row->created_at,
                'updated_at' => $row->updated_at,
                'deleted_at' => $row->deleted_at ?? null,
            ]);
        }
    }
};
