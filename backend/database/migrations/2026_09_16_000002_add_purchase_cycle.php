<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('purchase_requisitions')) {
            Schema::create('purchase_requisitions', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->uuid('branch_id')->nullable();
                $table->foreignUuid('warehouse_id')->nullable()->constrained('warehouses')->nullOnDelete();
                $table->foreignUuid('supplier_id')->nullable()->constrained('suppliers')->nullOnDelete();
                $table->string('number', 40);
                $table->string('status', 30)->default('draft');
                $table->string('priority', 20)->default('normal');
                $table->string('department', 100)->nullable();
                $table->date('needed_at')->nullable();
                $table->string('reason', 255)->nullable();
                $table->text('notes')->nullable();
                $table->text('rejection_comment')->nullable();
                $table->bigInteger('subtotal')->default(0);
                $table->bigInteger('tax_total')->default(0);
                $table->bigInteger('total')->default(0);
                $table->timestamp('submitted_at')->nullable();
                $table->timestamp('approved_at')->nullable();
                $table->timestamp('rejected_at')->nullable();
                $table->timestamp('converted_at')->nullable();
                $table->uuid('created_by')->nullable();
                $table->uuid('submitted_by')->nullable();
                $table->uuid('approved_by')->nullable();
                $table->uuid('rejected_by')->nullable();
                $table->uuid('converted_proforma_id')->nullable();
                $table->uuid('converted_purchase_order_id')->nullable();
                $table->timestamps();
                $table->softDeletes();

                $table->unique(['tenant_id', 'number']);
                $table->index(['tenant_id', 'status']);
            });
        }

        if (! Schema::hasTable('purchase_requisition_items')) {
            Schema::create('purchase_requisition_items', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->foreignUuid('purchase_requisition_id')->constrained('purchase_requisitions')->cascadeOnDelete();
                $table->foreignUuid('product_id')->constrained('products')->restrictOnDelete();
                $table->uuid('product_variant_id')->nullable();
                $table->unsignedInteger('quantity')->default(1);
                $table->bigInteger('unit_cost')->default(0);
                $table->decimal('tax_rate', 8, 4)->default(0);
                $table->bigInteger('line_total')->default(0);
                $table->unsignedInteger('sort_order')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('purchase_proformas')) {
            Schema::create('purchase_proformas', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->uuid('branch_id')->nullable();
                $table->foreignUuid('warehouse_id')->nullable()->constrained('warehouses')->nullOnDelete();
                $table->foreignUuid('supplier_id')->constrained('suppliers')->restrictOnDelete();
                $table->foreignUuid('purchase_requisition_id')->nullable()->constrained('purchase_requisitions')->nullOnDelete();
                $table->string('number', 40);
                $table->string('status', 30)->default('draft');
                $table->string('payment_terms', 255)->nullable();
                $table->string('delivery_terms', 255)->nullable();
                $table->date('expires_at')->nullable();
                $table->text('notes')->nullable();
                $table->text('rejection_comment')->nullable();
                $table->bigInteger('subtotal')->default(0);
                $table->bigInteger('tax_total')->default(0);
                $table->bigInteger('total')->default(0);
                $table->timestamp('sent_at')->nullable();
                $table->timestamp('reviewed_at')->nullable();
                $table->timestamp('approved_at')->nullable();
                $table->timestamp('rejected_at')->nullable();
                $table->timestamp('converted_at')->nullable();
                $table->uuid('created_by')->nullable();
                $table->uuid('sent_by')->nullable();
                $table->uuid('reviewed_by')->nullable();
                $table->uuid('approved_by')->nullable();
                $table->uuid('rejected_by')->nullable();
                $table->uuid('converted_purchase_order_id')->nullable();
                $table->timestamps();
                $table->softDeletes();

                $table->unique(['tenant_id', 'number']);
                $table->index(['tenant_id', 'status']);
                $table->index(['tenant_id', 'supplier_id']);
            });
        }

        if (! Schema::hasTable('purchase_proforma_items')) {
            Schema::create('purchase_proforma_items', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->foreignUuid('purchase_proforma_id')->constrained('purchase_proformas')->cascadeOnDelete();
                $table->foreignUuid('product_id')->constrained('products')->restrictOnDelete();
                $table->uuid('product_variant_id')->nullable();
                $table->unsignedInteger('quantity')->default(1);
                $table->bigInteger('unit_cost')->default(0);
                $table->decimal('tax_rate', 8, 4)->default(0);
                $table->bigInteger('line_total')->default(0);
                $table->unsignedInteger('sort_order')->default(0);
                $table->timestamps();
            });
        }

        if (Schema::hasTable('purchase_orders')) {
            Schema::table('purchase_orders', function (Blueprint $table) {
                if (! Schema::hasColumn('purchase_orders', 'purchase_requisition_id')) {
                    $table->uuid('purchase_requisition_id')->nullable();
                    $table->index('purchase_requisition_id');
                }
                if (! Schema::hasColumn('purchase_orders', 'purchase_proforma_id')) {
                    $table->uuid('purchase_proforma_id')->nullable();
                    $table->index('purchase_proforma_id');
                }
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('purchase_orders')) {
            Schema::table('purchase_orders', function (Blueprint $table) {
                if (Schema::hasColumn('purchase_orders', 'purchase_proforma_id')) {
                    $table->dropColumn('purchase_proforma_id');
                }
                if (Schema::hasColumn('purchase_orders', 'purchase_requisition_id')) {
                    $table->dropColumn('purchase_requisition_id');
                }
            });
        }

        Schema::dropIfExists('purchase_proforma_items');
        Schema::dropIfExists('purchase_proformas');
        Schema::dropIfExists('purchase_requisition_items');
        Schema::dropIfExists('purchase_requisitions');
    }
};
