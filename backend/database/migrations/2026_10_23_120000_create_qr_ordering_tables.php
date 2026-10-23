<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Commande table par QR.
 * L'attente d'approbation vit ici. sales.status n'est pas étendu.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('stores', function (Blueprint $table) {
            $table->string('qr_approval_mode', 20)->default('manual');
        });

        Schema::table('sales', function (Blueprint $table) {
            $table->string('source', 20)->default('cashier');
        });

        Schema::create('table_qr_tokens', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('store_id')->constrained('stores')->cascadeOnDelete();
            $table->foreignUuid('pos_table_id')->constrained('pos_tables')->cascadeOnDelete();
            $table->string('token', 64)->unique();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->index(['store_id', 'pos_table_id']);
            $table->index(['pos_table_id', 'is_active']);
        });

        Schema::create('qr_table_sessions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('store_id')->constrained('stores')->cascadeOnDelete();
            $table->foreignUuid('pos_table_id')->constrained('pos_tables')->cascadeOnDelete();
            $table->foreignUuid('sale_id')->nullable()->constrained('sales')->nullOnDelete();
            $table->string('status', 20)->default('open');
            $table->timestamp('opened_at');
            $table->timestamp('closed_at')->nullable();
            $table->timestamps();

            $table->index(['pos_table_id', 'status']);
            $table->index(['store_id', 'status']);
        });

        Schema::create('qr_orders', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('store_id')->constrained('stores')->cascadeOnDelete();
            $table->foreignUuid('pos_table_id')->constrained('pos_tables')->cascadeOnDelete();
            $table->foreignUuid('session_id')->constrained('qr_table_sessions')->cascadeOnDelete();
            $table->foreignUuid('sale_id')->nullable()->constrained('sales')->nullOnDelete();
            $table->string('source', 20)->default('qr_client');
            $table->string('status', 32)->default('submitted');
            $table->string('guest_locale', 5)->default('fr');
            $table->string('idempotency_key', 80);
            $table->text('rejection_reason')->nullable();
            $table->foreignUuid('approved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('approved_at')->nullable();
            $table->foreignUuid('rejected_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('rejected_at')->nullable();
            $table->string('kitchen_ticket_code', 64)->nullable();
            $table->unsignedBigInteger('subtotal')->default(0);
            $table->unsignedBigInteger('tax_total')->default(0);
            $table->unsignedBigInteger('total')->default(0);
            $table->string('currency', 8)->default('FBU');
            $table->timestamps();

            $table->unique(['store_id', 'idempotency_key']);
            $table->index(['store_id', 'status']);
            $table->index(['session_id', 'created_at']);
        });

        Schema::create('qr_order_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('qr_order_id')->constrained('qr_orders')->cascadeOnDelete();
            $table->foreignUuid('product_id')->nullable()->constrained('products')->nullOnDelete();
            $table->foreignUuid('product_variant_id')->nullable()->constrained('product_variants')->nullOnDelete();
            $table->foreignUuid('sale_unit_id')->nullable()->constrained('product_sale_units')->nullOnDelete();
            $table->string('name');
            $table->unsignedSmallInteger('quantity');
            $table->text('note')->nullable();
            $table->json('options')->nullable();
            $table->unsignedBigInteger('unit_price')->default(0);
            $table->unsignedBigInteger('line_subtotal')->default(0);
            $table->unsignedBigInteger('line_tax')->default(0);
            $table->unsignedBigInteger('line_total')->default(0);
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('qr_order_items');
        Schema::dropIfExists('qr_orders');
        Schema::dropIfExists('qr_table_sessions');
        Schema::dropIfExists('table_qr_tokens');

        Schema::table('sales', function (Blueprint $table) {
            $table->dropColumn('source');
        });

        Schema::table('stores', function (Blueprint $table) {
            $table->dropColumn('qr_approval_mode');
        });
    }
};
