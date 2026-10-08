-- ITARA-POS logical database backup
-- driver: sqlite
-- created: 2026-10-07T11:23:07+00:00

PRAGMA foreign_keys=OFF;
BEGIN;

DROP TABLE IF EXISTS "accounting_entries";
CREATE TABLE "accounting_entries" ("id" varchar not null, "tenant_id" varchar not null, "entry_type" varchar not null, "reference_type" varchar, "reference_id" varchar, "debit" integer not null default '0', "credit" integer not null default '0', "account_code" varchar not null, "description" text, "recorded_by" varchar, "occurred_at" datetime, "created_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("recorded_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "audit_logs";
CREATE TABLE "audit_logs" ("id" varchar not null, "tenant_id" varchar not null, "user_id" varchar, "action" varchar not null, "entity_type" varchar not null, "entity_id" varchar, "payload" text, "ip_address" varchar, "created_at" datetime not null default CURRENT_TIMESTAMP, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("user_id") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "auth_tokens";
CREATE TABLE "auth_tokens" ("id" varchar not null, "user_id" varchar not null, "device_name" varchar, "access_token_hash" varchar not null, "refresh_token_hash" varchar not null, "ip_address" varchar, "user_agent" text, "last_used_at" datetime, "access_expires_at" datetime not null, "refresh_expires_at" datetime not null, "revoked_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("user_id") references "users"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "barcodes";
CREATE TABLE "barcodes" ("id" varchar not null, "tenant_id" varchar not null, "barcodeable_type" varchar not null, "barcodeable_id" varchar not null, "barcode" varchar not null, "type" varchar not null default 'internal', "is_primary" tinyint(1) not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "batches";
CREATE TABLE "batches" ("id" varchar not null, "tenant_id" varchar not null, "product_id" varchar not null, "batch_number" varchar not null, "manufactured_at" date, "expires_at" date, "supplier_id" varchar, "metadata" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "unit_cost" integer, "received_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete cascade, foreign key("supplier_id") references "suppliers"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "branch_expenses";
CREATE TABLE "branch_expenses" ("id" varchar not null, "tenant_id" varchar not null, "branch_id" varchar not null, "store_id" varchar, "category" varchar not null default 'other', "description" varchar not null, "amount" integer not null, "currency_code" varchar not null default 'FBU', "occurred_on" date not null, "notes" text, "created_at" datetime, "updated_at" datetime, "expense_category_id" varchar, "cash_register_session_id" varchar, "user_id" varchar, "recorded_by" varchar, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("branch_id") references "branches"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "branches";
CREATE TABLE "branches" ("id" varchar not null, "tenant_id" varchar not null, "company_id" varchar not null, "name" varchar not null, "code" varchar not null, "address" text, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "settings" text, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("company_id") references "companies"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "brands";
CREATE TABLE "brands" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "slug" varchar not null, "description" text, "logo_url" varchar, "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "store_id" varchar, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("store_id") references "stores"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "cash_movements";
CREATE TABLE "cash_movements" ("id" varchar not null, "tenant_id" varchar not null, "cash_register_id" varchar not null, "cash_register_session_id" varchar, "cashier_shift_id" varchar, "movement_type" varchar not null, "amount" integer not null, "reference_type" varchar, "reference_id" varchar, "reference" varchar, "description" varchar, "performed_by" varchar, "occurred_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("cash_register_id") references "cash_registers"("id") on delete cascade, foreign key("cash_register_session_id") references "cash_register_sessions"("id") on delete set null, foreign key("performed_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "cash_register_sessions";
CREATE TABLE "cash_register_sessions" ("id" varchar not null, "tenant_id" varchar not null, "cash_register_id" varchar not null, "opened_by" varchar, "closed_by" varchar, "status" varchar not null default 'open', "opening_balance" integer not null default '0', "sales_total" integer not null default '0', "cash_in_total" integer not null default '0', "cash_out_total" integer not null default '0', "expenses_total" integer not null default '0', "expected_cash" integer not null default '0', "actual_cash" integer, "variance" integer, "opening_notes" text, "closing_notes" text, "opened_at" datetime, "closed_at" datetime, "created_at" datetime, "updated_at" datetime, "variance_reason" text, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("cash_register_id") references "cash_registers"("id") on delete cascade, foreign key("opened_by") references "users"("id") on delete set null, foreign key("closed_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "cash_registers";
CREATE TABLE "cash_registers" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "device_id" varchar, "name" varchar not null, "code" varchar not null, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete cascade, foreign key("device_id") references "devices"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "cashier_shifts";
CREATE TABLE "cashier_shifts" ("id" varchar not null, "tenant_id" varchar not null, "cashier_id" varchar, "cash_register_id" varchar not null, "cash_register_session_id" varchar, "status" varchar not null default 'open', "opening_balance" integer not null default '0', "expected_cash" integer not null default '0', "opening_notes" text, "opened_at" datetime, "created_at" datetime, "updated_at" datetime, "sales_total" integer not null default '0', "refunds_total" integer not null default '0', "discounts_total" integer not null default '0', "cash_in_total" integer not null default '0', "cash_out_total" integer not null default '0', "expenses_total" integer not null default '0', "actual_cash" integer, "variance" integer, "variance_reason" text, "closing_notes" text, "closed_at" datetime, "client_uuid" varchar, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("cashier_id") references "users"("id") on delete set null, foreign key("cash_register_id") references "cash_registers"("id") on delete cascade, foreign key("cash_register_session_id") references "cash_register_sessions"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "catalog_attributes";
CREATE TABLE "catalog_attributes" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "code" varchar not null, "values" text not null, "sort_order" integer not null default ('0'), "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "store_id" varchar, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("store_id") references "stores"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "catalogs";
CREATE TABLE "catalogs" ("id" varchar not null, "tenant_id" varchar not null, "company_id" varchar not null, "name" varchar not null, "description" text, "is_default" tinyint(1) not null default ('0'), "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "store_id" varchar, foreign key("company_id") references companies("id") on delete cascade on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("store_id") references "stores"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "categories";
CREATE TABLE "categories" ("id" varchar not null, "tenant_id" varchar not null, "catalog_id" varchar not null, "parent_id" varchar, "name" varchar not null, "slug" varchar not null, "sort_order" integer not null default ('0'), "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "store_id" varchar, foreign key("parent_id") references categories("id") on delete set null on update no action, foreign key("catalog_id") references catalogs("id") on delete cascade on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("store_id") references "stores"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "companies";
CREATE TABLE "companies" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "legal_name" varchar, "tax_id" varchar, "currency_code" varchar not null default 'FBU', "address" text, "settings" text, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "trade_name" varchar, "legal_form" varchar, "registration_number" varchar, "phone" varchar, "email" varchar, "website" varchar, "logo_url" varchar, "locale" varchar not null default 'fr', "timezone" varchar not null default 'Africa/Bujumbura', foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "company_payment_methods";
CREATE TABLE "company_payment_methods" ("id" varchar not null, "tenant_id" varchar not null, "company_id" varchar not null, "code" varchar not null, "label" varchar not null, "label_fr" varchar, "is_enabled" tinyint(1) not null default '1', "available_on_pos" tinyint(1) not null default '1', "sort_order" integer not null default '0', "config" text, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("company_id") references "companies"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "crm_accounts";
CREATE TABLE "crm_accounts" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "legal_name" varchar, "email" varchar, "phone" varchar, "website" varchar, "tax_id" varchar, "industry" varchar, "address" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "crm_activities";
CREATE TABLE "crm_activities" ("id" varchar not null, "tenant_id" varchar not null, "customer_id" varchar, "lead_id" varchar, "opportunity_id" varchar, "type" varchar not null, "subject" varchar not null, "body" text, "direction" varchar, "status" varchar not null default 'open', "due_at" datetime, "completed_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("customer_id") references "customers"("id") on delete set null, foreign key("lead_id") references "crm_leads"("id") on delete set null, foreign key("opportunity_id") references "crm_opportunities"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "crm_campaign_members";
CREATE TABLE "crm_campaign_members" ("id" varchar not null, "tenant_id" varchar not null, "campaign_id" varchar not null, "customer_id" varchar not null, "status" varchar not null default 'subscribed', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("campaign_id") references "crm_campaigns"("id") on delete cascade, foreign key("customer_id") references "customers"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "crm_campaigns";
CREATE TABLE "crm_campaigns" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "channel" varchar not null default 'email', "status" varchar not null default 'draft', "starts_on" date, "ends_on" date, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "crm_leads";
CREATE TABLE "crm_leads" ("id" varchar not null, "tenant_id" varchar not null, "customer_id" varchar, "crm_account_id" varchar, "name" varchar not null, "email" varchar, "phone" varchar, "company_name" varchar, "source" varchar not null default 'manual', "status" varchar not null default 'new', "notes" text, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("customer_id") references "customers"("id") on delete set null, foreign key("crm_account_id") references "crm_accounts"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "crm_opportunities";
CREATE TABLE "crm_opportunities" ("id" varchar not null, "tenant_id" varchar not null, "customer_id" varchar, "crm_account_id" varchar, "stage_id" varchar not null, "title" varchar not null, "amount" integer not null default '0', "expected_close_on" date, "status" varchar not null default 'open', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("customer_id") references "customers"("id") on delete set null, foreign key("crm_account_id") references "crm_accounts"("id") on delete set null, foreign key("stage_id") references "crm_pipeline_stages"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "crm_pipeline_stages";
CREATE TABLE "crm_pipeline_stages" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "position" integer not null default '0', "probability" integer not null default '0', "is_won" tinyint(1) not null default '0', "is_lost" tinyint(1) not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "currencies";
CREATE TABLE "currencies" ("id" varchar not null, "tenant_id" varchar not null, "code" varchar not null, "name" varchar not null, "symbol" varchar, "decimal_places" integer not null default '0', "exchange_rate" numeric not null default '1', "is_default" tinyint(1) not null default '0', "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "customer_addresses";
CREATE TABLE "customer_addresses" ("id" varchar not null, "tenant_id" varchar not null, "customer_id" varchar not null, "label" varchar not null default 'default', "line1" varchar not null, "line2" varchar, "city" varchar, "state" varchar, "postal_code" varchar, "country_code" varchar not null default 'BI', "is_primary" tinyint(1) not null default '0', "is_billing" tinyint(1) not null default '0', "is_shipping" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("customer_id") references "customers"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "customer_payments";
CREATE TABLE "customer_payments" ("id" varchar not null, "tenant_id" varchar not null, "customer_id" varchar not null, "payment_number" varchar not null, "amount" integer not null, "payment_method" varchar not null default 'cash', "reference" varchar, "notes" text, "status" varchar not null default 'completed', "paid_at" datetime not null, "recorded_by" varchar, "allocations" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("customer_id") references "customers"("id") on delete cascade, foreign key("recorded_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "customer_transactions";
CREATE TABLE "customer_transactions" ("id" varchar not null, "tenant_id" varchar not null, "customer_id" varchar not null, "sale_id" varchar, "customer_payment_id" varchar, "transaction_type" varchar not null, "reference" varchar, "amount" integer not null, "paid_amount" integer not null default '0', "due_date" date, "loyalty_points_delta" integer not null default '0', "description" text, "recorded_by" varchar, "occurred_at" datetime not null, "created_at" datetime not null default CURRENT_TIMESTAMP, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("customer_id") references "customers"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete set null, foreign key("customer_payment_id") references "customer_payments"("id") on delete set null, foreign key("recorded_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "customers";
CREATE TABLE "customers" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "email" varchar, "phone" varchar, "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "code" varchar, "company_name" varchar, "tax_id" varchar, "date_of_birth" date, "gender" varchar, "credit_limit" integer, "payment_terms_days" integer not null default ('0'), "loyalty_points" integer not null default ('0'), "loyalty_tier" varchar not null default ('standard'), "notes" text, "metadata" text, "crm_role" varchar not null default 'client', "job_title" varchar, "crm_account_id" varchar, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("crm_account_id") references "crm_accounts"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "desk_documents";
CREATE TABLE "desk_documents" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "code" varchar not null, "kind" varchar not null, "parent_code" varchar, "status" varchar, "payload" text not null, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "device_warehouse";
CREATE TABLE "device_warehouse" ("device_id" varchar not null, "warehouse_id" varchar not null, foreign key("device_id") references "devices"("id") on delete cascade, foreign key("warehouse_id") references "warehouses"("id") on delete cascade, primary key ("device_id", "warehouse_id"));


DROP TABLE IF EXISTS "devices";
CREATE TABLE "devices" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "name" varchar not null, "device_type" varchar not null, "identifier" varchar not null, "is_active" tinyint(1) not null default ('1'), "last_sync_at" datetime, "created_at" datetime, "updated_at" datetime, "category" varchar not null default ('pos'), "pos_role" varchar not null default ('standalone'), "master_device_id" varchar, "master_host" varchar, "platform" varchar, "app_version" varchar, "connection_type" varchar, "ip_address" varchar, "port" integer, "description" text, "registration_status" varchar not null default ('pending'), "sync_token" varchar, "token_generated_at" datetime, "registered_at" datetime, "code" varchar, "user_id" varchar, "branch_id" varchar, "local_server" varchar, "status" varchar not null default 'pending', "revoked_at" datetime, foreign key("store_id") references stores("id") on delete cascade on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("user_id") references "users"("id") on delete set null, foreign key("branch_id") references "branches"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "expense_categories";
CREATE TABLE "expense_categories" ("id" varchar not null, "tenant_id" varchar not null, "code" varchar not null, "name" varchar not null, "is_active" tinyint(1) not null default '1', "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, "color" varchar not null default '#6366F1', "description" varchar, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "gallery_images";
CREATE TABLE "gallery_images" ("id" varchar not null, "tenant_id" varchar not null, "catalog_id" varchar, "storage_path" varchar not null, "cdn_url" varchar not null, "original_filename" varchar, "mime_type" varchar not null, "file_size" integer not null default '0', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("catalog_id") references "catalogs"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "goods_receipt_items";
CREATE TABLE "goods_receipt_items" ("id" varchar not null, "tenant_id" varchar not null, "goods_receipt_id" varchar not null, "purchase_order_item_id" varchar not null, "product_id" varchar not null, "product_variant_id" varchar, "batch_id" varchar, "quantity_received" integer not null, "unit_cost" integer not null default '0', "created_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("goods_receipt_id") references "goods_receipts"("id") on delete cascade, foreign key("purchase_order_item_id") references "purchase_order_items"("id") on delete restrict, foreign key("product_id") references "products"("id") on delete restrict, primary key ("id"));


DROP TABLE IF EXISTS "goods_receipts";
CREATE TABLE "goods_receipts" ("id" varchar not null, "tenant_id" varchar not null, "purchase_order_id" varchar not null, "warehouse_id" varchar, "receipt_number" varchar not null, "status" varchar not null default 'completed', "received_by" varchar, "received_at" datetime, "notes" text, "created_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("purchase_order_id") references "purchase_orders"("id") on delete cascade, foreign key("warehouse_id") references "warehouses"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "inbox_notifications";
CREATE TABLE "inbox_notifications" ("id" varchar not null, "tenant_id" varchar not null, "user_id" varchar not null, "event" varchar not null, "title" varchar not null, "body" text not null, "context" text, "fingerprint" varchar not null, "read_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("user_id") references "users"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "inventory_alerts";
CREATE TABLE "inventory_alerts" ("id" varchar not null, "tenant_id" varchar not null, "warehouse_id" varchar, "product_id" varchar not null, "batch_id" varchar, "alert_type" varchar not null, "status" varchar not null default 'active', "quantity_on_hand" integer, "threshold_value" integer, "expires_at" date, "message" text, "acknowledged_at" datetime, "acknowledged_by" varchar, "resolved_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("warehouse_id") references "warehouses"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete cascade, foreign key("batch_id") references "batches"("id") on delete set null, foreign key("acknowledged_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "inventory_count_items";
CREATE TABLE "inventory_count_items" ("id" varchar not null, "tenant_id" varchar not null, "inventory_count_id" varchar not null, "product_id" varchar not null, "product_variant_id" varchar, "counted_quantity" integer not null, "system_quantity" integer, "created_at" datetime, "updated_at" datetime, "sale_unit_id" varchar, "entered_quantity" integer, "unit_name" varchar, "unit_volume_ml" integer, "remainder_ml" integer, "unit_cost" integer, "line_value" integer, "variance_reason" varchar, "notes" varchar, foreign key("product_variant_id") references product_variants("id") on delete set null on update no action, foreign key("product_id") references products("id") on delete restrict on update no action, foreign key("inventory_count_id") references inventory_counts("id") on delete cascade on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("sale_unit_id") references "product_sale_units"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "inventory_counts";
CREATE TABLE "inventory_counts" ("id" varchar not null, "tenant_id" varchar not null, "count_number" varchar not null, "warehouse_id" varchar not null, "status" varchar not null default ('draft'), "notes" text, "performed_by" varchar, "confirmed_by" varchar, "confirmed_at" datetime, "completed_at" datetime, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "count_type" varchar not null default ('full'), "counted_at" date, "zone" varchar, "category_id" varchar, "lock_movements" tinyint(1) not null default '0', "approved_by" varchar, "started_at" datetime, "submitted_at" datetime, "reviewed_at" datetime, "cancelled_at" datetime, "cancelled_by" varchar, foreign key("confirmed_by") references users("id") on delete set null on update no action, foreign key("performed_by") references users("id") on delete set null on update no action, foreign key("warehouse_id") references warehouses("id") on delete restrict on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("category_id") references "categories"("id") on delete set null, foreign key("approved_by") references "users"("id") on delete set null, foreign key("cancelled_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "inventory_movements";
CREATE TABLE "inventory_movements" ("id" varchar not null, "tenant_id" varchar not null, "warehouse_id" varchar not null, "product_id" varchar not null, "product_variant_id" varchar, "batch_id" varchar, "serial_number_id" varchar, "movement_type" varchar not null, "quantity" integer not null, "unit_cost" integer, "reference_type" varchar, "reference_id" varchar, "source_warehouse_id" varchar, "destination_warehouse_id" varchar, "performed_by" varchar, "notes" text, "occurred_at" datetime not null, "created_at" datetime not null default CURRENT_TIMESTAMP, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("warehouse_id") references "warehouses"("id") on delete restrict, foreign key("product_id") references "products"("id") on delete restrict, foreign key("product_variant_id") references "product_variants"("id") on delete set null, foreign key("batch_id") references "batches"("id") on delete set null, foreign key("serial_number_id") references "serial_numbers"("id") on delete set null, foreign key("source_warehouse_id") references "warehouses"("id") on delete set null, foreign key("destination_warehouse_id") references "warehouses"("id") on delete set null, foreign key("performed_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "inventory_verification_findings";
CREATE TABLE "inventory_verification_findings" ("id" varchar not null, "tenant_id" varchar not null, "run_id" varchar not null, "product_id" varchar not null, "check_type" varchar not null, "code" varchar not null, "severity" varchar not null default 'warning', "status" varchar not null default 'open', "title" varchar not null, "message" text, "expected_value" varchar, "actual_value" varchar, "note" text, "action_taken" varchar, "resolved_by" varchar, "resolved_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("run_id") references "inventory_verification_runs"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete cascade, foreign key("resolved_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "inventory_verification_plans";
CREATE TABLE "inventory_verification_plans" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "warehouse_id" varchar not null, "category_id" varchar, "inventory_class" varchar, "frequency" varchar not null default 'weekly', "responsible_id" varchar, "next_run_at" date, "notes" text, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("warehouse_id") references "warehouses"("id") on delete cascade, foreign key("category_id") references "categories"("id") on delete set null, foreign key("responsible_id") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "inventory_verification_runs";
CREATE TABLE "inventory_verification_runs" ("id" varchar not null, "tenant_id" varchar not null, "plan_id" varchar, "reference" varchar not null, "warehouse_id" varchar not null, "status" varchar not null default 'analysis', "performed_by" varchar, "analyzed_at" datetime, "summary" text, "validated_by" varchar, "validated_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("plan_id") references "inventory_verification_plans"("id") on delete set null, foreign key("warehouse_id") references "warehouses"("id") on delete cascade, foreign key("performed_by") references "users"("id") on delete set null, foreign key("validated_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "login_attempts";
CREATE TABLE "login_attempts" ("id" integer primary key autoincrement not null, "email" varchar not null, "ip_address" varchar, "successful" tinyint(1) not null default '0', "attempted_at" datetime not null default CURRENT_TIMESTAMP);


DROP TABLE IF EXISTS "merchant_qr_codes";
CREATE TABLE "merchant_qr_codes" ("id" varchar not null, "tenant_id" varchar not null, "company_id" varchar not null, "store_id" varchar, "table_id" varchar, "label" varchar not null, "type" varchar not null, "scan" varchar not null, "service" varchar not null, "payload" text not null, "scan_value" text not null, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("company_id") references "companies"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete set null, foreign key("table_id") references "pos_tables"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "migrations";
CREATE TABLE "migrations" ("id" integer primary key autoincrement not null, "migration" varchar not null, "batch" integer not null);

INSERT INTO "migrations" ("id", "migration", "batch") VALUES (1, '2026_09_01_000000_create_users_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (2, '2026_09_01_000001_create_tenants_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (3, '2026_09_01_000002_create_companies_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (4, '2026_09_01_000003_create_branches_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (5, '2026_09_01_000004_create_stores_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (6, '2026_09_01_000005_create_catalogs_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (7, '2026_09_01_000006_create_categories_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (8, '2026_09_01_000007_create_products_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (9, '2026_09_01_000008_create_store_products_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (10, '2026_09_01_000009_create_product_images_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (11, '2026_09_01_000010_add_tenant_id_to_users_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (12, '2026_09_01_000011_add_api_token_to_users_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (13, '2026_09_01_000012_create_warehouses_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (14, '2026_09_01_000013_create_devices_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (15, '2026_09_01_000014_create_permissions_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (16, '2026_09_01_000015_create_roles_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (17, '2026_09_01_000016_create_role_permissions_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (18, '2026_09_01_000018_create_user_roles_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (19, '2026_09_01_000019_add_imported_by_uuid_to_store_products', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (20, '2026_09_01_000020_create_customers_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (21, '2026_09_01_000021_create_suppliers_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (22, '2026_09_01_000022_create_sales_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (23, '2026_09_01_000023_create_purchases_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (24, '2026_09_01_000024_create_auth_tokens_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (25, '2026_09_01_000025_add_auth_security_fields_to_users_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (26, '2026_09_01_000026_create_phone_verification_codes_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (27, '2026_09_01_000027_create_login_attempts_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (28, '2026_09_01_000029_create_brands_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (29, '2026_09_01_000030_create_units_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (30, '2026_09_01_000031_create_taxes_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (31, '2026_09_01_000032_extend_products_for_phase9', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (32, '2026_09_01_000033_create_product_variants_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (33, '2026_09_01_000034_create_product_bundle_items_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (34, '2026_09_01_000035_create_barcodes_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (35, '2026_09_01_000036_create_prices_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (36, '2026_09_01_000037_create_batches_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (37, '2026_09_01_000038_create_serial_numbers_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (38, '2026_09_01_000039_create_inventory_movements_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (39, '2026_09_01_000040_create_stock_balances_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (40, '2026_09_01_000041_create_stock_transfers_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (41, '2026_09_01_000042_create_stock_transfer_items_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (42, '2026_09_01_000043_create_stock_adjustments_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (43, '2026_09_01_000044_extend_batches_for_phase12', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (44, '2026_09_01_000045_add_low_stock_threshold_to_products', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (45, '2026_09_01_000046_create_inventory_alerts_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (46, '2026_09_01_000047_extend_suppliers_for_phase13', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (47, '2026_09_01_000048_create_supplier_contacts_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (48, '2026_09_01_000049_create_supplier_payments_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (49, '2026_09_01_000050_create_supplier_transactions_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (50, '2026_09_01_000051_extend_purchases_for_phase13', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (51, '2026_09_01_000052_extend_customers_for_phase15', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (52, '2026_09_01_000053_create_customer_addresses_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (53, '2026_09_01_000054_create_customer_payments_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (54, '2026_09_01_000055_create_customer_transactions_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (55, '2026_09_01_000075_create_sale_returns_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (56, '2026_09_01_000076_create_sale_return_items_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (57, '2026_09_02_000002_create_sale_receipts_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (58, '2026_09_02_000003_create_sale_invoices_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (59, '2026_09_02_000004_extend_sales_for_phase29', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (60, '2026_09_02_000005_create_payment_transactions_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (61, '2026_09_02_000005_create_sale_refunds_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (62, '2026_09_02_000006_extend_payment_transactions_for_refunds', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (63, '2026_09_03_000001_extend_companies_for_identification', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (64, '2026_09_03_000002_create_currencies_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (65, '2026_09_03_000010_create_company_payment_methods_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (66, '2026_09_08_000001_extend_devices_for_terminal_pairing', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (67, '2026_09_08_000002_create_inventory_document_lines', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (68, '2026_09_08_000004_add_count_type_to_inventory_counts', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (69, '2026_09_08_000005_create_product_sale_units', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (70, '2026_09_09_000001_create_chart_of_accounts_and_fiscal_periods', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (71, '2026_09_13_000001_create_pos_reservations_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (72, '2026_09_13_000002_create_inventory_verifications_tables', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (73, '2026_09_13_000003_create_store_user_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (74, '2026_09_13_000004_add_locale_timezone_to_companies', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (75, '2026_09_13_000005_add_branch_establishments', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (76, '2026_09_13_000005_create_product_sale_units_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (77, '2026_09_13_000006_add_device_identity', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (78, '2026_09_13_000006_add_inventory_count_workflow_columns', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (79, '2026_09_13_000007_create_catalog_attributes_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (80, '2026_09_13_000008_create_product_supplier_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (81, '2026_09_13_000009_add_issue_unit_columns_to_stock_adjustment_items', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (82, '2026_09_13_000010_create_audit_logs_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (83, '2026_09_13_000011_add_confirmed_columns_to_stock_adjustments', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (84, '2026_09_13_000012_create_sync_events_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (85, '2026_09_13_000013_add_shift_close_and_variance_reason', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (86, '2026_09_13_000014_create_promotions_tables', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (87, '2026_09_13_000015_create_expense_categories_and_link_expenses', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (88, '2026_09_14_000001_repair_missing_sales_and_purchase_schema', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (89, '2026_09_14_000002_create_service_appointments', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (90, '2026_09_14_000003_create_sync_failures_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (91, '2026_09_14_000003_make_user_pins_unique', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (92, '2026_09_14_000004_create_desk_documents_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (93, '2026_09_16_000001_add_product_accompaniments', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (94, '2026_09_16_000002_add_purchase_cycle', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (95, '2026_09_16_000002_replace_booking_accompaniments_with_links', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (96, '2026_09_16_000010_create_pos_tables', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (97, '2026_09_16_000020_backfill_customer_codes', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (98, '2026_09_16_000021_add_color_description_to_expense_categories', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (99, '2026_09_20_210000_scope_catalogs_and_units_to_stores', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (100, '2026_09_20_220000_share_company_catalogs_across_stores', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (101, '2026_09_20_240000_drop_legacy_catalog_attribute_code_unique', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (102, '2026_09_20_250000_restore_tenant_unique_on_catalog_attributes', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (103, '2026_09_20_250000_scope_taxonomies_to_stores', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (104, '2026_09_20_260000_add_taxonomy_to_store_products', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (105, '2026_09_20_270000_add_attributes_to_store_products', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (106, '2026_10_05_000001_create_gallery_images_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (107, '2026_10_06_000001_create_realtime_outbox_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (108, '2026_10_06_000002_add_order_date_to_sales_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (109, '2026_10_06_000002_create_merchant_qr_codes_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (110, '2026_10_06_000003_create_platform_audit_logs_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (111, '2026_10_07_000001_add_profile_to_tenants_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (112, '2026_10_07_000002_create_crm_tables', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (113, '2026_10_07_000003_create_offline_transactions_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (114, '2026_10_07_000003_create_saas_billing_tables', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (115, '2026_10_07_120000_create_notification_center_tables', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (116, '2026_10_07_180000_add_performance_indexes', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (117, '2026_10_07_200000_create_platform_backup_tables', 1);

DROP TABLE IF EXISTS "notification_channel_settings";
CREATE TABLE "notification_channel_settings" ("id" varchar not null, "tenant_id" varchar not null, "channel" varchar not null, "enabled" tinyint(1) not null default '0', "config" text, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "notification_deliveries";
CREATE TABLE "notification_deliveries" ("id" varchar not null, "tenant_id" varchar not null, "user_id" varchar, "event" varchar not null, "channel" varchar not null, "status" varchar not null, "recipient" varchar, "title" varchar not null, "body" text not null, "fingerprint" varchar not null, "error" text, "sent_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("user_id") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "notification_preferences";
CREATE TABLE "notification_preferences" ("id" varchar not null, "tenant_id" varchar not null, "user_id" varchar, "scope_key" varchar not null, "event" varchar not null, "channels" text not null, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("user_id") references "users"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "offline_transactions";
CREATE TABLE "offline_transactions" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar, "client_uuid" varchar not null, "domain" varchar not null, "entity_type" varchar not null, "entity_id" varchar not null, "operation" varchar not null, "payload_hash" varchar not null, "payload" text not null, "base_version" varchar, "status" varchar not null, "result" text, "conflict_code" varchar, "error" text, "attempts" integer not null default '0', "synced_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "payment_transactions";
CREATE TABLE "payment_transactions" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar, "sale_id" varchar, "transaction_number" varchar not null, "payment_method" varchar not null, "amount" integer not null, "currency" varchar not null default 'FBU', "status" varchar not null default 'pending', "provider_type" varchar not null, "provider_reference" varchar, "idempotency_key" varchar, "customer_id" varchar, "cash_register_id" varchar, "processed_by" varchar, "metadata" text, "completed_at" datetime, "created_at" datetime, "updated_at" datetime, "transaction_type" varchar not null default 'payment', "sale_return_id" varchar, "original_transaction_id" varchar, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete set null, foreign key("sale_id") references "sales"("id") on delete set null, foreign key("customer_id") references "customers"("id") on delete set null, foreign key("processed_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "permissions";
CREATE TABLE "permissions" ("id" varchar not null, "name" varchar not null, "slug" varchar not null, "group" varchar not null, "created_at" datetime not null default CURRENT_TIMESTAMP, primary key ("id"));


DROP TABLE IF EXISTS "phone_verification_codes";
CREATE TABLE "phone_verification_codes" ("id" varchar not null, "user_id" varchar not null, "phone" varchar not null, "code_hash" varchar not null, "expires_at" datetime not null, "verified_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("user_id") references "users"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "platform_audit_logs";
CREATE TABLE "platform_audit_logs" ("id" varchar not null, "actor_id" varchar, "tenant_id" varchar, "action" varchar not null, "payload" text, "ip_address" varchar, "created_at" datetime not null default CURRENT_TIMESTAMP, foreign key("actor_id") references "users"("id") on delete set null, foreign key("tenant_id") references "tenants"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "pos_reservations";
CREATE TABLE "pos_reservations" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "customer_id" varchar, "reference" varchar not null, "guest_name" varchar not null, "phone" varchar, "party_size" integer not null, "reserved_at" datetime not null, "table_label" varchar, "status" varchar not null default ('pending'), "notes" text, "created_by" varchar, "created_at" datetime, "updated_at" datetime, "table_id" varchar, foreign key("created_by") references users("id") on delete set null on update no action, foreign key("customer_id") references customers("id") on delete set null on update no action, foreign key("store_id") references stores("id") on delete cascade on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("table_id") references "pos_tables"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "pos_table_events";
CREATE TABLE "pos_table_events" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "table_id" varchar not null, "sale_id" varchar, "user_id" varchar, "type" varchar not null, "from_table_id" varchar, "to_table_id" varchar, "payload" text, "notes" text, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete cascade, foreign key("table_id") references "pos_tables"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete set null, foreign key("user_id") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "pos_table_zones";
CREATE TABLE "pos_table_zones" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "name" varchar not null, "description" text, "sort_order" integer not null default '0', "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "pos_tables";
CREATE TABLE "pos_tables" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "zone_id" varchar, "name" varchar not null, "code" varchar not null, "capacity" integer not null default '2', "description" text, "status" varchar not null default 'available', "is_active" tinyint(1) not null default '1', "current_sale_id" varchar, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete cascade, foreign key("zone_id") references "pos_table_zones"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "prices";
CREATE TABLE "prices" ("id" varchar not null, "tenant_id" varchar not null, "priceable_type" varchar not null, "priceable_id" varchar not null, "price_type" varchar not null default 'base', "amount" integer not null, "currency_code" varchar not null default 'USD', "store_id" varchar, "min_quantity" integer not null default '1', "valid_from" datetime, "valid_until" datetime, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "product_accompaniment_links";
CREATE TABLE "product_accompaniment_links" ("id" varchar not null, "tenant_id" varchar not null, "product_id" varchar not null, "accompaniment_product_id" varchar not null, "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete cascade, foreign key("accompaniment_product_id") references "products"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "product_bundle_items";
CREATE TABLE "product_bundle_items" ("id" varchar not null, "tenant_id" varchar not null, "bundle_product_id" varchar not null, "component_product_id" varchar not null, "component_variant_id" varchar, "quantity" numeric not null default '1', "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("bundle_product_id") references "products"("id") on delete cascade, foreign key("component_product_id") references "products"("id") on delete cascade, foreign key("component_variant_id") references "product_variants"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "product_images";
CREATE TABLE "product_images" ("id" varchar not null, "tenant_id" varchar not null, "product_id" varchar not null, "storage_path" varchar not null, "cdn_url" varchar not null, "original_filename" varchar, "mime_type" varchar not null, "file_size" integer not null default '0', "sort_order" integer not null default '0', "is_primary" tinyint(1) not null default '0', "alt_text" varchar, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "product_sale_units";
CREATE TABLE "product_sale_units" ("id" varchar not null, "tenant_id" varchar not null, "product_id" varchar not null, "name" varchar not null, "code" varchar not null, "volume_ml" integer not null, "price" integer not null default '0', "is_base" tinyint(1) not null default '0', "sort_order" integer not null default '0', "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "product_supplier";
CREATE TABLE "product_supplier" ("product_id" varchar not null, "supplier_id" varchar not null, "supplier_sku" varchar, "cost_price" integer, "created_at" datetime, "updated_at" datetime, foreign key("product_id") references "products"("id") on delete cascade, foreign key("supplier_id") references "suppliers"("id") on delete cascade, primary key ("product_id", "supplier_id"));


DROP TABLE IF EXISTS "product_variants";
CREATE TABLE "product_variants" ("id" varchar not null, "tenant_id" varchar not null, "product_id" varchar not null, "sku" varchar not null, "name" varchar, "size" varchar, "color" varchar, "color_hex" varchar, "base_price" integer not null default '0', "cost_price" integer not null default '0', "sort_order" integer not null default '0', "is_active" tinyint(1) not null default '1', "attributes" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "products";
CREATE TABLE "products" ("id" varchar not null, "tenant_id" varchar not null, "catalog_id" varchar not null, "category_id" varchar, "sku" varchar not null, "name" varchar not null, "description" text, "barcode" varchar, "unit" varchar not null default ('piece'), "base_price" integer not null default ('0'), "cost_price" integer not null default ('0'), "is_active" tinyint(1) not null default ('1'), "metadata" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "product_type" varchar not null default 'simple', "brand_id" varchar, "unit_id" varchar, "tax_id" varchar, "is_serialized" tinyint(1) not null default '0', "track_batch" tinyint(1) not null default '0', "track_expiration" tinyint(1) not null default '0', "expiration_days" integer, "low_stock_threshold" integer, "bottle_volume_ml" integer, "inventory_class" varchar, "count_frequency" varchar, "last_counted_at" date, "next_count_at" date, "accompaniment_enabled" tinyint(1) not null default '0', foreign key("category_id") references categories("id") on delete set null on update no action, foreign key("catalog_id") references catalogs("id") on delete cascade on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("brand_id") references "brands"("id") on delete set null, foreign key("unit_id") references "units"("id") on delete set null, foreign key("tax_id") references "taxes"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "promotion_customers";
CREATE TABLE "promotion_customers" ("id" varchar not null, "promotion_id" varchar not null, "customer_id" varchar not null, "created_at" datetime, "updated_at" datetime, foreign key("promotion_id") references "promotions"("id") on delete cascade, foreign key("customer_id") references "customers"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "promotion_items";
CREATE TABLE "promotion_items" ("id" varchar not null, "promotion_id" varchar not null, "product_id" varchar, "product_variant_id" varchar, "role" varchar not null, "quantity" integer not null default '1', "created_at" datetime, "updated_at" datetime, foreign key("promotion_id") references "promotions"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete cascade, foreign key("product_variant_id") references "product_variants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "promotions";
CREATE TABLE "promotions" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar, "category_id" varchar, "name" varchar not null, "code" varchar, "type" varchar not null, "description" text, "starts_at" datetime, "ends_at" datetime, "min_quantity" integer not null default '1', "max_uses" integer, "uses_count" integer not null default '0', "priority" integer not null default '0', "discount_percent" numeric, "discount_amount" integer, "buy_quantity" integer, "get_quantity" integer, "bundle_price" integer, "schedule" text, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete set null, foreign key("category_id") references "categories"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "purchase_invoices";
CREATE TABLE "purchase_invoices" ("id" varchar not null, "tenant_id" varchar not null, "purchase_order_id" varchar, "goods_receipt_id" varchar, "supplier_id" varchar not null, "supplier_transaction_id" varchar, "invoice_number" varchar not null, "supplier_invoice_number" varchar, "status" varchar not null default 'posted', "subtotal" integer not null default '0', "tax_total" integer not null default '0', "total" integer not null default '0', "paid_amount" integer not null default '0', "due_date" date, "invoiced_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("purchase_order_id") references "purchase_orders"("id") on delete set null, foreign key("goods_receipt_id") references "goods_receipts"("id") on delete set null, foreign key("supplier_id") references "suppliers"("id") on delete restrict, primary key ("id"));


DROP TABLE IF EXISTS "purchase_order_items";
CREATE TABLE "purchase_order_items" ("id" varchar not null, "tenant_id" varchar not null, "purchase_order_id" varchar not null, "product_id" varchar not null, "product_variant_id" varchar, "quantity_ordered" integer not null, "quantity_received" integer not null default '0', "unit_cost" integer not null default '0', "tax_rate" numeric not null default '0', "line_total" integer not null default '0', "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("purchase_order_id") references "purchase_orders"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete restrict, primary key ("id"));


DROP TABLE IF EXISTS "purchase_orders";
CREATE TABLE "purchase_orders" ("id" varchar not null, "tenant_id" varchar not null, "branch_id" varchar, "supplier_id" varchar, "warehouse_id" varchar, "order_number" varchar not null, "reference" varchar, "status" varchar not null default 'draft', "subtotal" integer not null default '0', "tax_total" integer not null default '0', "total" integer not null default '0', "due_date" date, "notes" text, "ordered_at" datetime, "expected_at" datetime, "submitted_at" datetime, "approved_at" datetime, "completed_at" datetime, "created_by" varchar, "approved_by" varchar, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "purchase_requisition_id" varchar, "purchase_proforma_id" varchar, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("supplier_id") references "suppliers"("id") on delete set null, foreign key("warehouse_id") references "warehouses"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "purchase_payments";
CREATE TABLE "purchase_payments" ("id" varchar not null, "tenant_id" varchar not null, "purchase_invoice_id" varchar not null, "supplier_payment_id" varchar, "payment_number" varchar not null, "amount" integer not null, "payment_method" varchar, "reference" varchar, "notes" text, "paid_at" datetime, "recorded_by" varchar, "created_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("purchase_invoice_id") references "purchase_invoices"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "purchase_proforma_items";
CREATE TABLE "purchase_proforma_items" ("id" varchar not null, "tenant_id" varchar not null, "purchase_proforma_id" varchar not null, "product_id" varchar not null, "product_variant_id" varchar, "quantity" integer not null default '1', "unit_cost" integer not null default '0', "tax_rate" numeric not null default '0', "line_total" integer not null default '0', "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("purchase_proforma_id") references "purchase_proformas"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete restrict, primary key ("id"));


DROP TABLE IF EXISTS "purchase_proformas";
CREATE TABLE "purchase_proformas" ("id" varchar not null, "tenant_id" varchar not null, "branch_id" varchar, "warehouse_id" varchar, "supplier_id" varchar not null, "purchase_requisition_id" varchar, "number" varchar not null, "status" varchar not null default 'draft', "payment_terms" varchar, "delivery_terms" varchar, "expires_at" date, "notes" text, "rejection_comment" text, "subtotal" integer not null default '0', "tax_total" integer not null default '0', "total" integer not null default '0', "sent_at" datetime, "reviewed_at" datetime, "approved_at" datetime, "rejected_at" datetime, "converted_at" datetime, "created_by" varchar, "sent_by" varchar, "reviewed_by" varchar, "approved_by" varchar, "rejected_by" varchar, "converted_purchase_order_id" varchar, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("warehouse_id") references "warehouses"("id") on delete set null, foreign key("supplier_id") references "suppliers"("id") on delete restrict, foreign key("purchase_requisition_id") references "purchase_requisitions"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "purchase_requisition_items";
CREATE TABLE "purchase_requisition_items" ("id" varchar not null, "tenant_id" varchar not null, "purchase_requisition_id" varchar not null, "product_id" varchar not null, "product_variant_id" varchar, "quantity" integer not null default '1', "unit_cost" integer not null default '0', "tax_rate" numeric not null default '0', "line_total" integer not null default '0', "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("purchase_requisition_id") references "purchase_requisitions"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete restrict, primary key ("id"));


DROP TABLE IF EXISTS "purchase_requisitions";
CREATE TABLE "purchase_requisitions" ("id" varchar not null, "tenant_id" varchar not null, "branch_id" varchar, "warehouse_id" varchar, "supplier_id" varchar, "number" varchar not null, "status" varchar not null default 'draft', "priority" varchar not null default 'normal', "department" varchar, "needed_at" date, "reason" varchar, "notes" text, "rejection_comment" text, "subtotal" integer not null default '0', "tax_total" integer not null default '0', "total" integer not null default '0', "submitted_at" datetime, "approved_at" datetime, "rejected_at" datetime, "converted_at" datetime, "created_by" varchar, "submitted_by" varchar, "approved_by" varchar, "rejected_by" varchar, "converted_proforma_id" varchar, "converted_purchase_order_id" varchar, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("warehouse_id") references "warehouses"("id") on delete set null, foreign key("supplier_id") references "suppliers"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "purchases";
CREATE TABLE "purchases" ("id" varchar not null, "tenant_id" varchar not null, "supplier_id" varchar, "warehouse_id" varchar, "reference" varchar not null, "status" varchar not null default 'draft', "total" integer not null default '0', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "due_date" date, "notes" text, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("supplier_id") references "suppliers"("id") on delete set null, foreign key("warehouse_id") references "warehouses"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "push_subscriptions";
CREATE TABLE "push_subscriptions" ("id" varchar not null, "tenant_id" varchar not null, "user_id" varchar not null, "token" varchar not null, "platform" varchar not null, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("user_id") references "users"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "realtime_outbox";
CREATE TABLE "realtime_outbox" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar, "user_id" varchar, "event_name" varchar not null, "entity_type" varchar, "entity_id" varchar, "status" varchar, "payload" text not null, "occurred_at" datetime not null, "broadcast_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "role_permissions";
CREATE TABLE "role_permissions" ("role_id" varchar not null, "permission_id" varchar not null, foreign key("role_id") references "roles"("id") on delete cascade, foreign key("permission_id") references "permissions"("id") on delete cascade, primary key ("role_id", "permission_id"));


DROP TABLE IF EXISTS "roles";
CREATE TABLE "roles" ("id" varchar not null, "tenant_id" varchar, "name" varchar not null, "slug" varchar not null, "is_system" tinyint(1) not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "saas_invoices";
CREATE TABLE "saas_invoices" ("id" varchar not null, "tenant_id" varchar not null, "subscription_id" varchar not null, "number" varchar not null, "kind" varchar not null, "status" varchar not null default 'open', "plan_code" varchar not null, "billing_cycle" varchar not null, "amount" integer not null default '0', "currency_code" varchar not null default 'USD', "period_starts_on" date, "period_ends_on" date, "issued_on" date not null, "due_on" date not null, "paid_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("subscription_id") references "saas_subscriptions"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "saas_payments";
CREATE TABLE "saas_payments" ("id" varchar not null, "tenant_id" varchar not null, "invoice_id" varchar not null, "amount" integer not null default '0', "currency_code" varchar not null default 'USD', "method" varchar not null default 'manual', "reference" varchar, "status" varchar not null default 'pending', "paid_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("invoice_id") references "saas_invoices"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "saas_plans";
CREATE TABLE "saas_plans" ("id" varchar not null, "code" varchar not null, "name" varchar not null, "rank" integer not null, "monthly_price" integer not null default '0', "yearly_price" integer not null default '0', "currency_code" varchar not null default 'USD', "trial_days" integer not null default '14', "grace_days" integer not null default '7', "limits" text not null, "is_public" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, primary key ("id"));


DROP TABLE IF EXISTS "saas_subscription_events";
CREATE TABLE "saas_subscription_events" ("id" varchar not null, "tenant_id" varchar not null, "subscription_id" varchar not null, "type" varchar not null, "payload" text, "actor_id" varchar, "created_at" datetime not null default CURRENT_TIMESTAMP, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("subscription_id") references "saas_subscriptions"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "saas_subscriptions";
CREATE TABLE "saas_subscriptions" ("id" varchar not null, "tenant_id" varchar not null, "plan_code" varchar not null, "status" varchar not null default 'trial', "billing_cycle" varchar not null default 'yearly', "trial_ends_on" date, "period_starts_on" date, "period_ends_on" date, "grace_ends_on" date, "pending_plan_code" varchar, "pending_billing_cycle" varchar, "suspended_at" datetime, "cancelled_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "sale_discounts";
CREATE TABLE "sale_discounts" ("id" varchar not null, "tenant_id" varchar not null, "sale_id" varchar not null, "sale_item_id" varchar, "promotion_id" varchar, "discount_type" varchar not null, "source" varchar not null, "label" varchar, "amount" integer not null, "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete cascade, foreign key("promotion_id") references "promotions"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "sale_installments";
CREATE TABLE "sale_installments" ("id" varchar not null, "tenant_id" varchar not null, "sale_id" varchar not null, "installment_number" integer not null, "amount" integer not null, "paid_amount" integer not null default '0', "due_date" date not null, "status" varchar not null default 'pending', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "sale_invoices";
CREATE TABLE "sale_invoices" ("id" varchar not null, "tenant_id" varchar not null, "sale_id" varchar not null, "invoice_number" varchar not null, "status" varchar not null default 'issued', "format" varchar not null default 'a4', "issued_by" varchar, "issued_at" datetime not null, "cancelled_by" varchar, "cancelled_at" datetime, "storage_path" varchar, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete cascade, foreign key("issued_by") references "users"("id") on delete set null, foreign key("cancelled_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "sale_items";
CREATE TABLE "sale_items" ("id" varchar not null, "tenant_id" varchar not null, "sale_id" varchar not null, "product_id" varchar, "product_variant_id" varchar, "product_name" varchar not null, "product_sku" varchar, "quantity" integer not null, "sale_unit_id" varchar, "sale_unit_name" varchar, "volume_ml" integer, "unit_price" integer not null default '0', "price_type" varchar not null default 'retail', "catalog_price" integer not null default '0', "tax_rate" numeric not null default '0', "line_subtotal" integer not null default '0', "line_tax" integer not null default '0', "line_total" integer not null default '0', "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, "is_accompaniment" tinyint(1) not null default '0', foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "sale_payments";
CREATE TABLE "sale_payments" ("id" varchar not null, "tenant_id" varchar not null, "sale_id" varchar not null, "payment_transaction_id" varchar, "payment_method" varchar not null, "amount" integer not null, "currency" varchar not null default 'FBU', "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "sale_receipts";
CREATE TABLE "sale_receipts" ("id" varchar not null, "tenant_id" varchar not null, "sale_id" varchar not null, "receipt_number" varchar not null, "format" varchar not null default 'thermal_80', "printed_by" varchar, "device_id" varchar, "printed_at" datetime not null, "reprint_count" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete cascade, foreign key("printed_by") references "users"("id") on delete set null, foreign key("device_id") references "devices"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "sale_refunds";
CREATE TABLE "sale_refunds" ("id" varchar not null, "tenant_id" varchar not null, "sale_return_id" varchar not null, "sale_id" varchar not null, "store_id" varchar not null, "refund_number" varchar not null, "refund_method" varchar not null, "amount" integer not null, "currency" varchar not null default 'USD', "status" varchar not null default 'completed', "payment_transaction_id" varchar, "customer_transaction_id" varchar, "cash_register_id" varchar, "original_payment_transaction_id" varchar, "processed_by" varchar, "metadata" text, "completed_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("sale_return_id") references "sale_returns"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete cascade, foreign key("payment_transaction_id") references "payment_transactions"("id") on delete set null, foreign key("customer_transaction_id") references "customer_transactions"("id") on delete set null, foreign key("cash_register_id") references "cash_registers"("id") on delete set null, foreign key("original_payment_transaction_id") references "payment_transactions"("id") on delete set null, foreign key("processed_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "sale_return_items";
CREATE TABLE "sale_return_items" ("id" varchar not null, "tenant_id" varchar not null, "sale_return_id" varchar not null, "sale_item_id" varchar not null, "product_id" varchar, "product_variant_id" varchar, "product_name" varchar not null, "product_sku" varchar, "quantity_returned" integer not null, "unit_price" integer not null, "tax_rate" numeric not null default '0', "line_subtotal" integer not null default '0', "line_tax" integer not null default '0', "line_total" integer not null default '0', "batch_id" varchar, "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("sale_return_id") references "sale_returns"("id") on delete cascade, foreign key("sale_item_id") references "sale_items"("id") on delete restrict, foreign key("product_id") references "products"("id") on delete restrict, foreign key("product_variant_id") references "product_variants"("id") on delete set null, foreign key("batch_id") references "batches"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "sale_returns";
CREATE TABLE "sale_returns" ("id" varchar not null, "tenant_id" varchar not null, "sale_id" varchar not null, "store_id" varchar not null, "warehouse_id" varchar not null, "customer_id" varchar, "return_number" varchar not null, "status" varchar not null default 'completed', "reason" varchar not null, "refund_method" varchar not null default 'none', "subtotal" integer not null default '0', "tax_total" integer not null default '0', "discount_total" integer not null default '0', "total" integer not null default '0', "currency" varchar not null default 'USD', "processed_by" varchar, "approved_by" varchar, "idempotency_key" varchar, "approved_at" datetime, "completed_at" datetime, "notes" text, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete restrict, foreign key("store_id") references "stores"("id") on delete restrict, foreign key("warehouse_id") references "warehouses"("id") on delete restrict, foreign key("customer_id") references "customers"("id") on delete set null, foreign key("processed_by") references "users"("id") on delete set null, foreign key("approved_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "sale_taxes";
CREATE TABLE "sale_taxes" ("id" varchar not null, "tenant_id" varchar not null, "sale_id" varchar not null, "sale_item_id" varchar, "tax_id" varchar, "tax_name" varchar, "tax_rate" numeric not null default '0', "taxable_amount" integer not null default '0', "tax_amount" integer not null default '0', "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "sales";
CREATE TABLE "sales" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "customer_id" varchar, "reference" varchar not null, "status" varchar not null default ('draft'), "total" integer not null default ('0'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "paid_amount" integer not null default ('0'), "due_date" date, "payment_status" varchar not null default ('paid'), "warehouse_id" varchar, "cash_register_id" varchar, "cashier_shift_id" varchar, "device_id" varchar, "processed_by" varchar, "subtotal" integer not null default ('0'), "tax_total" integer not null default ('0'), "discount_total" integer not null default ('0'), "fees_total" integer not null default ('0'), "currency" varchar not null default ('FBU'), "payment_transaction_number" varchar, "idempotency_key" varchar, "completed_at" datetime, "notes" text, "table_id" varchar, "merged_into_id" varchar, "order_date" date, foreign key("customer_id") references customers("id") on delete set null on update no action, foreign key("store_id") references stores("id") on delete cascade on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("table_id") references "pos_tables"("id") on delete set null, foreign key("merged_into_id") references "sales"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "serial_numbers";
CREATE TABLE "serial_numbers" ("id" varchar not null, "tenant_id" varchar not null, "product_id" varchar not null, "product_variant_id" varchar, "batch_id" varchar, "warehouse_id" varchar, "serial_number" varchar not null, "status" varchar not null default 'available', "metadata" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete cascade, foreign key("product_variant_id") references "product_variants"("id") on delete set null, foreign key("batch_id") references "batches"("id") on delete set null, foreign key("warehouse_id") references "warehouses"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "service_appointments";
CREATE TABLE "service_appointments" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar, "service_offering_id" varchar not null, "customer_name" varchar not null, "employee_id" varchar, "scheduled_at" datetime not null, "status" varchar not null default 'booked', "completed_at" datetime, "completed_by" varchar, "completion_notes" text, "paid_at" datetime, "payment_method" varchar, "paid_amount" integer, "sale_id" varchar, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete set null, foreign key("service_offering_id") references "service_offerings"("id") on delete restrict, foreign key("employee_id") references "users"("id") on delete set null, foreign key("completed_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "service_offerings";
CREATE TABLE "service_offerings" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "category" varchar not null, "duration_minutes" integer not null default '60', "price" integer not null default '0', "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "stock_adjustment_items";
CREATE TABLE "stock_adjustment_items" ("id" varchar not null, "tenant_id" varchar not null, "stock_adjustment_id" varchar not null, "product_id" varchar not null, "product_variant_id" varchar, "batch_id" varchar, "quantity" integer not null, "unit_cost" integer, "notes" varchar, "created_at" datetime, "updated_at" datetime, "sale_unit_id" varchar, "entered_quantity" integer, "unit_name" varchar, foreign key("batch_id") references batches("id") on delete set null on update no action, foreign key("product_variant_id") references product_variants("id") on delete set null on update no action, foreign key("product_id") references products("id") on delete restrict on update no action, foreign key("stock_adjustment_id") references stock_adjustments("id") on delete cascade on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("sale_unit_id") references "product_sale_units"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "stock_adjustments";
CREATE TABLE "stock_adjustments" ("id" varchar not null, "tenant_id" varchar not null, "adjustment_number" varchar not null, "warehouse_id" varchar not null, "movement_type" varchar not null, "status" varchar not null default ('draft'), "reason" text, "performed_by" varchar, "approved_by" varchar, "completed_at" datetime, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "confirmed_by" varchar, "confirmed_at" datetime, foreign key("approved_by") references users("id") on delete set null on update no action, foreign key("performed_by") references users("id") on delete set null on update no action, foreign key("warehouse_id") references warehouses("id") on delete restrict on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("confirmed_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "stock_balances";
CREATE TABLE "stock_balances" ("id" varchar not null, "tenant_id" varchar not null, "warehouse_id" varchar not null, "product_id" varchar not null, "product_variant_id" varchar, "batch_id" varchar, "quantity_on_hand" integer not null default '0', "quantity_reserved" integer not null default '0', "last_movement_id" varchar, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("warehouse_id") references "warehouses"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete cascade, foreign key("product_variant_id") references "product_variants"("id") on delete set null, foreign key("batch_id") references "batches"("id") on delete set null, foreign key("last_movement_id") references "inventory_movements"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "stock_transfer_items";
CREATE TABLE "stock_transfer_items" ("id" varchar not null, "tenant_id" varchar not null, "stock_transfer_id" varchar not null, "product_id" varchar not null, "product_variant_id" varchar, "batch_id" varchar, "quantity_requested" integer not null, "quantity_shipped" integer not null default '0', "quantity_received" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("stock_transfer_id") references "stock_transfers"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete restrict, foreign key("product_variant_id") references "product_variants"("id") on delete set null, foreign key("batch_id") references "batches"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "stock_transfers";
CREATE TABLE "stock_transfers" ("id" varchar not null, "tenant_id" varchar not null, "transfer_number" varchar not null, "source_warehouse_id" varchar not null, "destination_warehouse_id" varchar not null, "status" varchar not null default 'draft', "requested_by" varchar, "approved_by" varchar, "notes" text, "shipped_at" datetime, "received_at" datetime, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("source_warehouse_id") references "warehouses"("id") on delete restrict, foreign key("destination_warehouse_id") references "warehouses"("id") on delete restrict, foreign key("requested_by") references "users"("id") on delete set null, foreign key("approved_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "store_products";
CREATE TABLE "store_products" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "product_id" varchar not null, "is_available" tinyint(1) not null default ('1'), "price_override" integer, "imported_at" datetime not null default (CURRENT_TIMESTAMP), "created_at" datetime, "updated_at" datetime, "imported_by" varchar, "category_id" varchar, "brand_id" varchar, "unit_id" varchar, "attributes" text, foreign key("imported_by") references users("id") on delete set null on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("store_id") references stores("id") on delete cascade on update no action, foreign key("product_id") references products("id") on delete cascade on update no action, foreign key("category_id") references "categories"("id") on delete set null, foreign key("brand_id") references "brands"("id") on delete set null, foreign key("unit_id") references "units"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "store_user";
CREATE TABLE "store_user" ("user_id" varchar not null, "store_id" varchar not null, "created_at" datetime, "updated_at" datetime, foreign key("user_id") references "users"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete cascade, primary key ("user_id", "store_id"));


DROP TABLE IF EXISTS "stores";
CREATE TABLE "stores" ("id" varchar not null, "tenant_id" varchar not null, "branch_id" varchar not null, "name" varchar not null, "code" varchar not null, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "kind" varchar not null default 'store', foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("branch_id") references "branches"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "supplier_contacts";
CREATE TABLE "supplier_contacts" ("id" varchar not null, "tenant_id" varchar not null, "supplier_id" varchar not null, "name" varchar not null, "title" varchar, "email" varchar, "phone" varchar, "is_primary" tinyint(1) not null default '0', "notes" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("supplier_id") references "suppliers"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "supplier_payments";
CREATE TABLE "supplier_payments" ("id" varchar not null, "tenant_id" varchar not null, "supplier_id" varchar not null, "payment_number" varchar not null, "amount" integer not null, "payment_method" varchar not null default 'bank_transfer', "reference" varchar, "notes" text, "status" varchar not null default 'completed', "paid_at" datetime not null, "recorded_by" varchar, "allocations" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("supplier_id") references "suppliers"("id") on delete cascade, foreign key("recorded_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "supplier_transactions";
CREATE TABLE "supplier_transactions" ("id" varchar not null, "tenant_id" varchar not null, "supplier_id" varchar not null, "purchase_id" varchar, "supplier_payment_id" varchar, "transaction_type" varchar not null, "reference" varchar, "amount" integer not null, "paid_amount" integer not null default '0', "due_date" date, "description" text, "recorded_by" varchar, "occurred_at" datetime not null, "created_at" datetime not null default CURRENT_TIMESTAMP, "purchase_order_id" varchar, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("supplier_id") references "suppliers"("id") on delete cascade, foreign key("purchase_id") references "purchases"("id") on delete set null, foreign key("supplier_payment_id") references "supplier_payments"("id") on delete set null, foreign key("recorded_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "suppliers";
CREATE TABLE "suppliers" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "code" varchar not null, "email" varchar, "phone" varchar, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "legal_name" varchar, "tax_id" varchar, "address" text, "payment_terms_days" integer not null default '30', "credit_limit" integer, "currency_code" varchar not null default 'USD', "notes" text, "metadata" text, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "sync_events";
CREATE TABLE "sync_events" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "device_id" varchar, "sequence" integer not null, "event_type" varchar not null, "entity_type" varchar not null, "entity_id" varchar not null, "payload" text not null, "occurred_at" datetime not null, "created_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete cascade, foreign key("device_id") references "devices"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "sync_failures";
CREATE TABLE "sync_failures" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar, "entity_type" varchar not null, "entity_id" varchar not null, "error" varchar not null, "occurred_at" datetime not null, "resolved_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "taxes";
CREATE TABLE "taxes" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "code" varchar not null, "rate" numeric not null default '0', "is_inclusive" tinyint(1) not null default '0', "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "tenants";
CREATE TABLE "tenants" ("id" varchar not null, "name" varchar not null, "slug" varchar not null, "status" varchar not null default 'active', "settings" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "legal_name" varchar, "trade_name" varchar, "logo_url" varchar, "address" text, "phone" varchar, "email" varchar, "website" varchar, "country_code" varchar not null default 'BI', "currency_code" varchar not null default 'FBU', "timezone" varchar not null default 'Africa/Bujumbura', "locale" varchar not null default 'fr', "tax_regime" varchar, "tax_id" varchar, "registration_number" varchar, "subscription" text, primary key ("id"));


DROP TABLE IF EXISTS "units";
CREATE TABLE "units" ("id" varchar not null, "tenant_id" varchar not null, "code" varchar not null, "name" varchar not null, "symbol" varchar, "is_fractional" tinyint(1) not null default ('0'), "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "store_id" varchar, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("store_id") references "stores"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "user_roles";
CREATE TABLE "user_roles" ("id" varchar not null, "user_id" varchar not null, "role_id" varchar not null, "branch_id" varchar, "store_id" varchar, "created_at" datetime, "updated_at" datetime, foreign key("user_id") references "users"("id") on delete cascade, foreign key("role_id") references "roles"("id") on delete cascade, foreign key("branch_id") references "branches"("id") on delete set null, foreign key("store_id") references "stores"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "users";
CREATE TABLE "users" ("id" varchar not null, "name" varchar not null, "email" varchar not null, "email_verified_at" datetime, "password" varchar not null, "phone" varchar, "pin" varchar, "is_active" tinyint(1) not null default ('1'), "remember_token" varchar, "created_at" datetime, "updated_at" datetime, "tenant_id" varchar, "api_token" varchar, "two_factor_secret" text, "two_factor_confirmed_at" datetime, "two_factor_recovery_codes" text, "phone_verified_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "warehouses";
CREATE TABLE "warehouses" ("id" varchar not null, "tenant_id" varchar not null, "branch_id" varchar not null, "name" varchar not null, "code" varchar not null, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("branch_id") references "branches"("id") on delete cascade, primary key ("id"));


COMMIT;
PRAGMA foreign_keys=ON;
