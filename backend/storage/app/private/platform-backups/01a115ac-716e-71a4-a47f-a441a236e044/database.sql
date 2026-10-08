-- ITARA-POS logical database backup
-- driver: sqlite
-- created: 2026-10-07T09:23:05+00:00

PRAGMA foreign_keys=OFF;
BEGIN;

DROP TABLE IF EXISTS "accounting_entries";
CREATE TABLE "accounting_entries" ("id" varchar not null, "tenant_id" varchar not null, "entry_type" varchar not null, "reference_type" varchar, "reference_id" varchar, "debit" integer not null default '0', "credit" integer not null default '0', "account_code" varchar not null, "description" text, "recorded_by" varchar, "occurred_at" datetime, "created_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("recorded_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "audit_logs";
CREATE TABLE "audit_logs" ("id" varchar not null, "tenant_id" varchar not null, "user_id" varchar, "action" varchar not null, "entity_type" varchar not null, "entity_id" varchar, "payload" text, "ip_address" varchar, "created_at" datetime not null default CURRENT_TIMESTAMP, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("user_id") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "auth_tokens";
CREATE TABLE "auth_tokens" ("id" varchar not null, "user_id" varchar not null, "device_name" varchar, "access_token_hash" varchar not null, "refresh_token_hash" varchar not null, "ip_address" varchar, "user_agent" text, "last_used_at" datetime, "access_expires_at" datetime not null, "refresh_expires_at" datetime not null, "revoked_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("user_id") references "users"("id") on delete cascade, primary key ("id"));

INSERT INTO "auth_tokens" ("id", "user_id", "device_name", "access_token_hash", "refresh_token_hash", "ip_address", "user_agent", "last_used_at", "access_expires_at", "refresh_expires_at", "revoked_at", "created_at", "updated_at") VALUES ('01a115ac-713b-7386-bf0d-0ca5f93de554', '01a115ac-7134-7081-9535-609952557aea', NULL, 'f2a780e025de7ff9a3cd55d059e458e7041976f59c89489b7c983251bb868fc6', '019f9d1c359d949100fdaee8c9316bb6e07db6c7ffd691542a760858b6655cc4', NULL, NULL, '2026-10-07 09:23:05', '2026-10-07 10:23:05', '2026-11-06 09:23:05', NULL, '2026-10-07 09:23:05', '2026-10-07 09:23:05');

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

INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6fe3-719e-97ca-7f51ab86f7df', 'View dashboard', 'dashboard.view', 'dashboard', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6fe4-703c-97ea-bf4503ec51dd', 'View companies', 'organization.companies.view', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6fe5-7258-9829-74275d7017f3', 'Manage companies', 'organization.companies.manage', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6fe6-734b-adac-4a79d964d819', 'View branches', 'organization.branches.view', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6fe8-7005-9ed2-c74236d9c494', 'Manage branches', 'organization.branches.manage', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6fef-71ae-87e0-e268e289fb1d', 'View stores', 'organization.stores.view', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6ff0-729f-a7d1-e2269cc8f9a2', 'Manage stores', 'organization.stores.manage', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6ff1-7030-902b-59cb84547381', 'View warehouses', 'organization.warehouses.view', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6ff2-73b5-927c-9499d3d858c7', 'Manage warehouses', 'organization.warehouses.manage', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6ff2-73b5-927c-9499d4a2c688', 'View devices', 'organization.devices.view', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6ff3-73db-be6b-9d7f0b967040', 'Manage devices', 'organization.devices.manage', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6ff4-7284-97d7-6c38980f451c', 'View currencies', 'organization.currencies.view', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6ff5-7090-b9b9-9b6af14d3b5b', 'Manage currencies', 'organization.currencies.manage', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6ff6-72c6-b6a5-7116ac8491af', 'View payment methods', 'organization.payment_methods.view', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6ff7-713c-b9d9-63294b46b083', 'Manage payment methods', 'organization.payment_methods.manage', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6ff7-713c-b9d9-63294b94a98f', 'View catalogs', 'catalog.catalogs.view', 'catalog', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6ff8-706a-99b1-ff2c0cd26d32', 'Manage catalogs', 'catalog.catalogs.manage', 'catalog', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6ff9-71d0-85d7-4f2e419a0511', 'View categories', 'catalog.categories.view', 'catalog', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6ffa-7116-a7d5-3772ad244dac', 'Manage categories', 'catalog.categories.manage', 'catalog', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6ffc-7384-a861-106ddf3113fc', 'View products', 'catalog.products.view', 'catalog', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-6ffe-72b2-b49c-a338784d0367', 'Manage products', 'catalog.products.manage', 'catalog', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7000-734d-ac21-3021ec80d11e', 'View barcodes', 'catalog.barcodes.view', 'catalog', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7001-71de-9fa3-d6fdcc3869cc', 'Manage barcodes', 'catalog.barcodes.manage', 'catalog', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7002-73a2-9d64-1870094ee242', 'View sales', 'sales.view', 'sales', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7003-701e-82dc-2ec8be6efd50', 'Create sales', 'sales.create', 'sales', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7004-7104-83f9-9ebe10dc2557', 'Create sale', 'sale.create', 'sales', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7005-7291-b3cd-b0c77dee992a', 'Create payment', 'payments.create', 'sales', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7006-72c9-a0a8-d4b2c88cde85', 'Create payment', 'payment.create', 'sales', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7008-72aa-807c-839ab098d6a3', 'Print receipt', 'receipts.print', 'sales', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7009-7245-a69a-7e25b42de7af', 'Print receipt', 'receipt.print', 'sales', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-700c-72a4-962b-258915d94692', 'Void sales', 'sales.void', 'sales', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7010-7099-bc95-67c89fb516b2', 'Refund sales', 'sales.refund', 'sales', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7011-7334-bbcf-84e4420d0c32', 'Refund sale', 'sale.refund', 'sales', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7012-72ac-b402-23a3d6d3207a', 'Process sale returns', 'sales.return', 'sales', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7014-72e9-9458-295d334844c3', 'Merge pending sales', 'sales.merge', 'sales', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7015-7218-8262-191d3b08e9e7', 'Apply discounts', 'sales.discount.apply', 'sales', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7016-7396-b5d0-cf8d39542df2', 'View promotions', 'promotions.view', 'promotions', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7017-73ee-b515-229fe5bb583d', 'Manage promotions', 'promotions.manage', 'promotions', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7019-7264-88df-5301d8ac07ce', 'View cash registers', 'registers.view', 'registers', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-701b-7135-afd6-e4c543d00d96', 'Manage cash registers', 'registers.manage', 'registers', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-701c-7099-843b-52be9d23c34e', 'Open register session', 'registers.session.open', 'registers', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-701f-7091-82b9-3ab9d168a919', 'Close register session', 'registers.session.close', 'registers', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7021-706b-bd13-139e4fe88ed4', 'Record cash movements', 'registers.movement.record', 'registers', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7022-71b2-9466-4424e03aab62', 'View cashier shifts', 'shifts.view', 'shifts', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7024-7201-9754-a55e53ea6652', 'Manage cashier shifts', 'shifts.manage', 'shifts', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7025-724c-9f29-2deef2185170', 'Open cashier shift', 'shifts.open', 'shifts', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7026-73c1-ba30-e89b5b7480a7', 'Close cashier shift', 'shifts.close', 'shifts', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7028-714b-b15c-2acc8261ffd2', 'Record shift cash movements', 'shifts.movement.record', 'shifts', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7029-702f-91ef-b70e275d6314', 'View POS tables', 'pos.tables.view', 'pos', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-702b-7171-a8bf-2b8823481940', 'Manage POS tables', 'pos.tables.manage', 'pos', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-702d-706f-9f57-bb127018f4b8', 'Open table orders', 'pos.tables.open', 'pos', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-702e-71a2-ac3b-2f8cb1ba94c6', 'Transfer table orders', 'pos.tables.transfer', 'pos', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7031-7017-a6f1-2bc501de66ab', 'Merge table orders', 'pos.tables.merge', 'pos', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7033-7282-a8e2-4e43e68d4977', 'Reserve POS tables', 'pos.tables.reserve', 'pos', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7033-7282-a8e2-4e43e6e24184', 'View POS table statistics', 'pos.tables.stats', 'pos', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7034-7160-a2cb-920af1f5a665', 'View inventory', 'inventory.view', 'inventory', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7034-7160-a2cb-920af225fffd', 'Manage inventory', 'inventory.manage', 'inventory', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7035-70aa-aa25-9e1bc9d7ecc0', 'Adjust stock', 'inventory.adjust', 'inventory', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7036-710f-ac55-9792b0466b9c', 'Adjust stock', 'stock.adjust', 'inventory', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7038-73b0-a5db-7e9b952fb786', 'Transfer stock', 'inventory.transfer', 'inventory', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7039-7105-a790-748cb0991ed9', 'Create inventory count', 'inventory.count.create', 'inventory', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-703b-7167-b53c-9f9f1d0a8d44', 'Enter inventory count quantities', 'inventory.count.enter', 'inventory', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-703d-71ff-87e7-97c9aa3b6b91', 'Review inventory count', 'inventory.count.review', 'inventory', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-703f-7038-80e5-a984f59f1f4b', 'Approve inventory count and post adjustments', 'inventory.count.approve', 'inventory', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7041-729f-9145-cdc4b55fdbbb', 'Configure cycle count rules', 'inventory.cycle.configure', 'inventory', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7043-7115-8eba-016d38197df5', 'View expenses', 'expenses.view', 'expenses', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7044-7312-8e9a-de9235b4a531', 'Manage expenses', 'expenses.manage', 'expenses', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7044-7312-8e9a-de92361be0ad', 'Create expense', 'expenses.create', 'expenses', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7045-73c8-ba68-cdaf784e5b62', 'Submit expense', 'expenses.submit', 'expenses', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7047-7282-b3b2-3127fdb8a69b', 'Approve expense', 'expenses.approve', 'expenses', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7048-70ca-aa6f-84c11ce664c1', 'Pay expense', 'expenses.pay', 'expenses', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7049-7119-80c3-ae01a3fadb43', 'Cancel expense', 'expenses.cancel', 'expenses', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-704a-718d-aecb-1ef545cf97bf', 'Manage expense categories', 'expenses.categories', 'expenses', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-704c-70fd-8ae0-2e8c79040024', 'Manage recurring expenses', 'expenses.recurring', 'expenses', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-704f-7177-be81-449da62f60fc', 'View expense reports', 'expenses.reports', 'expenses', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7053-70df-909a-d12d009563eb', 'Export expense reports', 'expenses.export', 'expenses', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7054-734e-9054-487ae7de7924', 'Manage expense budgets', 'expenses.budgets', 'expenses', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7056-7278-a1b3-c72d24b464a5', 'View purchases', 'purchases.view', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7058-720a-9c13-4e5ecf4f5dae', 'Manage purchases', 'purchases.manage', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7058-720a-9c13-4e5ed0077200', 'Receive goods', 'purchases.receive', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7059-72f8-86b4-1d74bbd88353', 'Create requisition', 'purchases.requisition.create', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-705a-73c3-815c-80382f010a61', 'Approve requisition', 'purchases.requisition.approve', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-705a-73c3-815c-80382f819e27', 'Create proforma', 'purchases.proforma.create', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-705b-72b3-a17f-4f88d28b8225', 'Approve proforma', 'purchases.proforma.approve', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-705c-73d2-9bda-4896bded61ab', 'Create purchase order', 'purchases.order.create', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-705d-72d5-94d1-d1a3ea915477', 'Approve purchase order', 'purchases.order.approve', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-705e-72ec-8518-1e31f6accf75', 'Create supplier invoice', 'purchases.invoice.create', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-705f-7250-ad93-75d57fd3c303', 'Approve supplier invoice', 'purchases.invoice.approve', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7060-732c-a456-24cf24fca19a', 'Make supplier payment', 'purchases.payment.create', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7061-72a1-9b08-820efe1b9bc7', 'Approve supplier payment', 'purchases.payment.approve', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7064-72bc-b069-2789cf7726c4', 'Create purchase return', 'purchases.return.create', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7065-71df-94b8-7d08e2be6922', 'Approve purchase return', 'purchases.return.approve', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7066-70bc-879b-7d2e9dbb445c', 'Export purchase reports', 'purchases.export', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7067-72fd-9956-b3cc02d697c2', 'Delete purchase documents', 'purchases.delete', 'purchases', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7069-71a8-b127-c3820b7da2ce', 'View customers', 'customers.view', 'customers', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-706a-7269-8869-e215b3cb2d4c', 'Manage customers', 'customers.manage', 'customers', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-706c-7006-bc23-dcd1ccef7d76', 'View suppliers', 'suppliers.view', 'suppliers', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-706d-7009-96b5-6a1e6bef0a7e', 'Manage suppliers', 'suppliers.manage', 'suppliers', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7072-7215-b084-c1c941036273', 'View users', 'users.view', 'admin', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7074-70ec-a807-2c27895d12ba', 'Manage users', 'users.manage', 'admin', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7075-72fd-a9f9-3389f99a4bf3', 'View roles', 'roles.view', 'admin', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7076-712a-a29d-22a15e18ecb4', 'Manage roles', 'roles.manage', 'admin', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7077-70f5-a1db-89870334baa8', 'View reports', 'reports.view', 'reports', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7078-7187-aa52-b64f9cc637a6', 'Export reports', 'reports.export', 'reports', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7079-7264-b1f9-11d910e2bfde', 'View accounting', 'accounting.view', 'accounting', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-707a-7389-9610-55b52feb3846', 'Manage accounting', 'accounting.manage', 'accounting', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-707c-7068-8c74-60d388b5baea', 'View audit logs', 'audit.view', 'audit', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-707e-70f1-a4fa-e759b71376f5', 'View settings', 'settings.view', 'settings', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-707f-71d6-b66a-dfc2a245ae4e', 'Manage settings', 'settings.manage', 'settings', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7081-71b9-b40b-fe0d371f0756', 'View restaurant', 'restaurant.view', 'restaurant', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7084-70ba-8c2e-582df3e0901b', 'Manage restaurant', 'restaurant.manage', 'restaurant', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7085-73bf-89ce-6a1d2861095c', 'View hotel', 'hotel.view', 'hotel', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7086-703a-a7a1-3f146203b6ac', 'Manage hotel', 'hotel.manage', 'hotel', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7088-7046-894e-708064d77e28', 'View CRM', 'crm.view', 'crm', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-708a-7327-a2a4-ec8609bed143', 'Manage CRM', 'crm.manage', 'crm', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-708b-7368-a7ab-2632291f9e64', 'View HR', 'hr.view', 'hr', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-708d-7268-a1e7-c91d2f551d09', 'Manage HR', 'hr.manage', 'hr', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-708e-71c4-893b-6eb3061ea432', 'View projects', 'projects.view', 'projects', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7093-72fb-a5b8-40d30043b71f', 'Manage projects', 'projects.manage', 'projects', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7096-7055-b78d-ba02a02cb6b2', 'View documents', 'documents.view', 'documents', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7097-7114-81cb-0ee507c368a8', 'Manage documents', 'documents.manage', 'documents', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7098-72a6-9f62-913448225d2a', 'View fleet', 'fleet.view', 'fleet', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7099-73ff-a3be-3d5b8e7f27cc', 'Manage fleet', 'fleet.manage', 'fleet', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-709a-71d7-8e93-75a17f9372d9', 'View maintenance', 'maintenance.view', 'maintenance', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-709b-71a3-8912-38c4a646bf4a', 'Manage maintenance', 'maintenance.manage', 'maintenance', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-709c-72bd-96a3-c234e524f2b5', 'View manufacturing', 'manufacturing.view', 'manufacturing', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-709d-7089-a426-aa64e94755c0', 'Manage manufacturing', 'manufacturing.manage', 'manufacturing', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-709d-7089-a426-aa64e9acb373', 'View e-commerce', 'ecommerce.view', 'ecommerce', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-709e-71ab-80a7-2dd969699435', 'Manage e-commerce', 'ecommerce.manage', 'ecommerce', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-709e-71ab-80a7-2dd969dcb88b', 'View the notification center', 'notifications.view', 'notifications', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-709f-73e2-8ad2-57987fbb679b', 'Manage notification channels', 'notifications.manage', 'notifications', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70a0-7116-9d91-c1d1597f8e8d', 'Create companies', 'organization.companies.create', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70a1-7034-9ea7-07361729f741', 'Update companies', 'organization.companies.update', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70a2-7261-aed3-4fb4985f05bc', 'Delete companies', 'organization.companies.delete', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70a4-73c9-b8c9-5dfc395dfd96', 'Create branches', 'organization.branches.create', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70a6-7259-907f-2ad22b9358ae', 'Update branches', 'organization.branches.update', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70a7-70e2-a3eb-a47f28894abb', 'Delete branches', 'organization.branches.delete', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70a7-70e2-a3eb-a47f28cbb5c2', 'Create stores', 'organization.stores.create', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70a8-7117-8f43-608140e3cd4b', 'Update stores', 'organization.stores.update', 'organization', '2026-10-07 09:23:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70a9-735f-845c-7a6e87830898', 'Delete stores', 'organization.stores.delete', 'organization', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70aa-71b5-abec-6878eacd7f85', 'Create warehouses', 'organization.warehouses.create', 'organization', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ab-723a-80f2-3070636ba633', 'Update warehouses', 'organization.warehouses.update', 'organization', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ab-723a-80f2-3070641d3774', 'Delete warehouses', 'organization.warehouses.delete', 'organization', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ac-7137-a000-cc084ed96d3e', 'Create devices', 'organization.devices.create', 'organization', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ad-73e7-96b7-50cc74ccdace', 'Update devices', 'organization.devices.update', 'organization', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ad-73e7-96b7-50cc750ec117', 'Delete devices', 'organization.devices.delete', 'organization', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ae-710f-bd09-1dfbf859e5a4', 'Create currencies', 'organization.currencies.create', 'organization', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70af-738c-a608-fcb361260abc', 'Update currencies', 'organization.currencies.update', 'organization', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70b1-70df-a816-f19bf7d0d4f0', 'Delete currencies', 'organization.currencies.delete', 'organization', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70b3-723a-ad9f-cbbbaa835666', 'Create payment methods', 'organization.payment_methods.create', 'organization', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70b4-7336-854e-0ad8ba5d686a', 'Update payment methods', 'organization.payment_methods.update', 'organization', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70b7-727b-a510-f4c4e6f024ed', 'Delete payment methods', 'organization.payment_methods.delete', 'organization', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70b8-7203-aa3b-2b459263b7bf', 'Create catalogs', 'catalog.catalogs.create', 'catalog', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70b9-7086-ab2f-1d56c2ba05d5', 'Update catalogs', 'catalog.catalogs.update', 'catalog', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ba-70ae-af63-a1e8f9ee7a52', 'Delete catalogs', 'catalog.catalogs.delete', 'catalog', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70bb-7107-a4c6-ef8b0fb2135f', 'Create categories', 'catalog.categories.create', 'catalog', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70bc-7345-afca-f4950e0eb6fc', 'Update categories', 'catalog.categories.update', 'catalog', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70be-7063-84b5-2ed198d69702', 'Delete categories', 'catalog.categories.delete', 'catalog', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70c0-72ce-852b-31e4846d5ae2', 'Create products', 'catalog.products.create', 'catalog', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70c0-72ce-852b-31e485635340', 'Update products', 'catalog.products.update', 'catalog', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70c1-720e-a203-adbb93862333', 'Delete products', 'catalog.products.delete', 'catalog', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70c2-7227-b09e-dd406aee3457', 'Create barcodes', 'catalog.barcodes.create', 'catalog', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70c3-715c-b91f-b2754c6a6f51', 'Update barcodes', 'catalog.barcodes.update', 'catalog', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70c5-72f6-afcc-4191560abf62', 'Delete barcodes', 'catalog.barcodes.delete', 'catalog', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70c7-7200-bdda-7d8b50af224d', 'Create promotions', 'promotions.create', 'promotions', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70c8-7134-99e9-443fa713d17e', 'Update promotions', 'promotions.update', 'promotions', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70c9-733d-b030-5375eed2c4fe', 'Delete promotions', 'promotions.delete', 'promotions', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ca-7324-b9f2-c86c533b3c84', 'Create cash registers', 'registers.create', 'registers', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ca-7324-b9f2-c86c5391ec25', 'Update cash registers', 'registers.update', 'registers', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70cb-71c1-a7c9-87561625f024', 'Delete cash registers', 'registers.delete', 'registers', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70cd-7045-9086-2f3cd7b47b8e', 'Create cashier shifts', 'shifts.create', 'shifts', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ce-7272-afa9-7a449c36bc30', 'Update cashier shifts', 'shifts.update', 'shifts', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70cf-70b9-a5af-6b5c76786a6b', 'Delete cashier shifts', 'shifts.delete', 'shifts', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70d0-7088-a1cc-0fddf63c24f8', 'Create POS tables', 'pos.tables.create', 'pos', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70d0-7088-a1cc-0fddf68d613e', 'Update POS tables', 'pos.tables.update', 'pos', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70d1-71ee-8e6f-15ced224a107', 'Delete POS tables', 'pos.tables.delete', 'pos', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70d1-71ee-8e6f-15ced23469b9', 'Create inventory', 'inventory.create', 'inventory', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70d3-73ac-aea0-7a390198b4b6', 'Update inventory', 'inventory.update', 'inventory', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70d4-7367-82cc-7efccd8b3e49', 'Delete inventory', 'inventory.delete', 'inventory', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70d6-7248-9002-c47572b99190', 'Update expenses', 'expenses.update', 'expenses', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70d8-7012-959a-3c34e41b3cfe', 'Delete expenses', 'expenses.delete', 'expenses', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70d9-716f-9917-7f7019f4fd98', 'Create purchases', 'purchases.create', 'purchases', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70d9-716f-9917-7f701aefdbde', 'Update purchases', 'purchases.update', 'purchases', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70da-726d-9628-6dbea8338a28', 'Create customers', 'customers.create', 'customers', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70db-7369-82de-42edef43edc6', 'Update customers', 'customers.update', 'customers', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70db-7369-82de-42edefcaaa62', 'Delete customers', 'customers.delete', 'customers', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70dc-73bf-816e-33a8f7e0135c', 'Create suppliers', 'suppliers.create', 'suppliers', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70dd-7094-8a14-1459f333b510', 'Update suppliers', 'suppliers.update', 'suppliers', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70dd-7094-8a14-1459f353bc81', 'Delete suppliers', 'suppliers.delete', 'suppliers', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70de-73ba-970b-6e8c3dd79e54', 'Create users', 'users.create', 'admin', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70df-73e6-8ba5-17d5c2c89137', 'Update users', 'users.update', 'admin', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70e0-7395-ba56-4ecce83e217c', 'Delete users', 'users.delete', 'admin', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70e1-72a9-aae7-2d31df9f1475', 'Create roles', 'roles.create', 'admin', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70e1-72a9-aae7-2d31dfa74c34', 'Update roles', 'roles.update', 'admin', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70e2-72a2-a150-8a5d191b8e40', 'Delete roles', 'roles.delete', 'admin', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70e3-71d8-b8a7-f0c244dfbca1', 'Create accounting', 'accounting.create', 'accounting', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70e4-7373-9eec-b51fa5740c15', 'Update accounting', 'accounting.update', 'accounting', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70e6-716c-bf02-d8f5d29cfd7b', 'Delete accounting', 'accounting.delete', 'accounting', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ea-7201-aea1-60c0d09995f5', 'Create settings', 'settings.create', 'settings', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ea-7201-aea1-60c0d1375a59', 'Update settings', 'settings.update', 'settings', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70eb-733d-8fa5-69dae43c9a3a', 'Delete settings', 'settings.delete', 'settings', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70eb-733d-8fa5-69dae4907319', 'Create restaurant', 'restaurant.create', 'restaurant', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ec-7221-a310-5287c80cba84', 'Update restaurant', 'restaurant.update', 'restaurant', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ec-7221-a310-5287c82773c8', 'Delete restaurant', 'restaurant.delete', 'restaurant', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ed-7399-95c0-89871f4af20a', 'Create hotel', 'hotel.create', 'hotel', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ee-727c-aab2-37372d6bff62', 'Update hotel', 'hotel.update', 'hotel', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ef-70ec-81cd-75136224c589', 'Delete hotel', 'hotel.delete', 'hotel', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70f0-7341-b470-ae3d96f98238', 'Create CRM', 'crm.create', 'crm', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70f0-7341-b470-ae3d974768ab', 'Update CRM', 'crm.update', 'crm', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70f1-7251-b39f-bf6a4d73b10c', 'Delete CRM', 'crm.delete', 'crm', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70f2-723d-95c7-bbeccadcc32b', 'Create HR', 'hr.create', 'hr', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70f2-723d-95c7-bbeccb59cbc5', 'Update HR', 'hr.update', 'hr', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70f3-718c-ae1a-d314552ffe05', 'Delete HR', 'hr.delete', 'hr', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70f4-72b1-a332-480343c96e6d', 'Create projects', 'projects.create', 'projects', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70f4-72b1-a332-480344976634', 'Update projects', 'projects.update', 'projects', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70f5-7103-932d-38c72598faca', 'Delete projects', 'projects.delete', 'projects', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70f6-7121-adc5-235b2cff22e3', 'Create documents', 'documents.create', 'documents', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70f8-7391-929a-740d97d9f621', 'Update documents', 'documents.update', 'documents', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70f9-720b-a4cb-ec60b55777af', 'Delete documents', 'documents.delete', 'documents', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70fa-722e-9f65-5ba725bab7de', 'Create fleet', 'fleet.create', 'fleet', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70fb-7271-aed7-6f016a624359', 'Update fleet', 'fleet.update', 'fleet', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70fc-70da-a187-0384b7e36f5a', 'Delete fleet', 'fleet.delete', 'fleet', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70fc-70da-a187-0384b8531dad', 'Create maintenance', 'maintenance.create', 'maintenance', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70fd-72e4-956b-0e2728a0e1fa', 'Update maintenance', 'maintenance.update', 'maintenance', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70fd-72e4-956b-0e27296d351d', 'Delete maintenance', 'maintenance.delete', 'maintenance', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70fe-73f1-a3d5-5a476b7e8491', 'Create manufacturing', 'manufacturing.create', 'manufacturing', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70fe-73f1-a3d5-5a476c17c505', 'Update manufacturing', 'manufacturing.update', 'manufacturing', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-70ff-732b-bc03-5ba7481b3496', 'Delete manufacturing', 'manufacturing.delete', 'manufacturing', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7100-736c-a6f1-45af29351d9b', 'Create e-commerce', 'ecommerce.create', 'ecommerce', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7100-736c-a6f1-45af2a05bbad', 'Update e-commerce', 'ecommerce.update', 'ecommerce', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7101-7165-b2bc-04dbdfde8eb1', 'Delete e-commerce', 'ecommerce.delete', 'ecommerce', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7102-724a-97e0-328b1ca3dc2c', 'Create notification channels', 'notifications.create', 'notifications', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7102-724a-97e0-328b1d379edb', 'Update notification channels', 'notifications.update', 'notifications', '2026-10-07 09:23:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a115ac-7103-7218-bb01-0d30a4d92ba9', 'Delete notification channels', 'notifications.delete', 'notifications', '2026-10-07 09:23:05');

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

INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6fe3-719e-97ca-7f51ab86f7df');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6fe4-703c-97ea-bf4503ec51dd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6fe5-7258-9829-74275d7017f3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6fe6-734b-adac-4a79d964d819');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6fe8-7005-9ed2-c74236d9c494');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6fef-71ae-87e0-e268e289fb1d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6ff0-729f-a7d1-e2269cc8f9a2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6ff1-7030-902b-59cb84547381');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6ff2-73b5-927c-9499d3d858c7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6ff2-73b5-927c-9499d4a2c688');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6ff3-73db-be6b-9d7f0b967040');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6ff4-7284-97d7-6c38980f451c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6ff5-7090-b9b9-9b6af14d3b5b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6ff6-72c6-b6a5-7116ac8491af');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6ff7-713c-b9d9-63294b46b083');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6ff7-713c-b9d9-63294b94a98f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6ff8-706a-99b1-ff2c0cd26d32');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6ff9-71d0-85d7-4f2e419a0511');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6ffa-7116-a7d5-3772ad244dac');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6ffc-7384-a861-106ddf3113fc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-6ffe-72b2-b49c-a338784d0367');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7000-734d-ac21-3021ec80d11e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7001-71de-9fa3-d6fdcc3869cc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7002-73a2-9d64-1870094ee242');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7003-701e-82dc-2ec8be6efd50');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7004-7104-83f9-9ebe10dc2557');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7005-7291-b3cd-b0c77dee992a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7006-72c9-a0a8-d4b2c88cde85');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7008-72aa-807c-839ab098d6a3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7009-7245-a69a-7e25b42de7af');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-700c-72a4-962b-258915d94692');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7010-7099-bc95-67c89fb516b2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7011-7334-bbcf-84e4420d0c32');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7012-72ac-b402-23a3d6d3207a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7014-72e9-9458-295d334844c3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7015-7218-8262-191d3b08e9e7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7016-7396-b5d0-cf8d39542df2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7017-73ee-b515-229fe5bb583d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7019-7264-88df-5301d8ac07ce');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-701b-7135-afd6-e4c543d00d96');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-701c-7099-843b-52be9d23c34e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-701f-7091-82b9-3ab9d168a919');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7021-706b-bd13-139e4fe88ed4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7022-71b2-9466-4424e03aab62');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7024-7201-9754-a55e53ea6652');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7025-724c-9f29-2deef2185170');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7026-73c1-ba30-e89b5b7480a7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7028-714b-b15c-2acc8261ffd2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7029-702f-91ef-b70e275d6314');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-702b-7171-a8bf-2b8823481940');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-702d-706f-9f57-bb127018f4b8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-702e-71a2-ac3b-2f8cb1ba94c6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7031-7017-a6f1-2bc501de66ab');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7033-7282-a8e2-4e43e68d4977');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7033-7282-a8e2-4e43e6e24184');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7034-7160-a2cb-920af1f5a665');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7034-7160-a2cb-920af225fffd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7035-70aa-aa25-9e1bc9d7ecc0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7036-710f-ac55-9792b0466b9c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7038-73b0-a5db-7e9b952fb786');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7039-7105-a790-748cb0991ed9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-703b-7167-b53c-9f9f1d0a8d44');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-703d-71ff-87e7-97c9aa3b6b91');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-703f-7038-80e5-a984f59f1f4b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7041-729f-9145-cdc4b55fdbbb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7043-7115-8eba-016d38197df5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7044-7312-8e9a-de9235b4a531');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7044-7312-8e9a-de92361be0ad');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7045-73c8-ba68-cdaf784e5b62');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7047-7282-b3b2-3127fdb8a69b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7048-70ca-aa6f-84c11ce664c1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7049-7119-80c3-ae01a3fadb43');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-704a-718d-aecb-1ef545cf97bf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-704c-70fd-8ae0-2e8c79040024');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-704f-7177-be81-449da62f60fc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7053-70df-909a-d12d009563eb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7054-734e-9054-487ae7de7924');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7056-7278-a1b3-c72d24b464a5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7058-720a-9c13-4e5ecf4f5dae');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7058-720a-9c13-4e5ed0077200');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7059-72f8-86b4-1d74bbd88353');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-705a-73c3-815c-80382f010a61');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-705a-73c3-815c-80382f819e27');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-705b-72b3-a17f-4f88d28b8225');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-705c-73d2-9bda-4896bded61ab');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-705d-72d5-94d1-d1a3ea915477');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-705e-72ec-8518-1e31f6accf75');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-705f-7250-ad93-75d57fd3c303');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7060-732c-a456-24cf24fca19a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7061-72a1-9b08-820efe1b9bc7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7064-72bc-b069-2789cf7726c4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7065-71df-94b8-7d08e2be6922');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7066-70bc-879b-7d2e9dbb445c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7067-72fd-9956-b3cc02d697c2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7069-71a8-b127-c3820b7da2ce');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-706a-7269-8869-e215b3cb2d4c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-706c-7006-bc23-dcd1ccef7d76');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-706d-7009-96b5-6a1e6bef0a7e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7072-7215-b084-c1c941036273');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7074-70ec-a807-2c27895d12ba');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7075-72fd-a9f9-3389f99a4bf3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7076-712a-a29d-22a15e18ecb4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7077-70f5-a1db-89870334baa8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7078-7187-aa52-b64f9cc637a6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7079-7264-b1f9-11d910e2bfde');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-707a-7389-9610-55b52feb3846');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-707c-7068-8c74-60d388b5baea');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-707e-70f1-a4fa-e759b71376f5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-707f-71d6-b66a-dfc2a245ae4e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7081-71b9-b40b-fe0d371f0756');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7084-70ba-8c2e-582df3e0901b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7085-73bf-89ce-6a1d2861095c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7086-703a-a7a1-3f146203b6ac');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7088-7046-894e-708064d77e28');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-708a-7327-a2a4-ec8609bed143');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-708b-7368-a7ab-2632291f9e64');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-708d-7268-a1e7-c91d2f551d09');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-708e-71c4-893b-6eb3061ea432');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7093-72fb-a5b8-40d30043b71f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7096-7055-b78d-ba02a02cb6b2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7097-7114-81cb-0ee507c368a8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7098-72a6-9f62-913448225d2a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7099-73ff-a3be-3d5b8e7f27cc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-709a-71d7-8e93-75a17f9372d9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-709b-71a3-8912-38c4a646bf4a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-709c-72bd-96a3-c234e524f2b5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-709d-7089-a426-aa64e94755c0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-709d-7089-a426-aa64e9acb373');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-709e-71ab-80a7-2dd969699435');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-709e-71ab-80a7-2dd969dcb88b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-709f-73e2-8ad2-57987fbb679b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70a0-7116-9d91-c1d1597f8e8d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70a1-7034-9ea7-07361729f741');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70a2-7261-aed3-4fb4985f05bc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70a4-73c9-b8c9-5dfc395dfd96');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70a6-7259-907f-2ad22b9358ae');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70a7-70e2-a3eb-a47f28894abb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70a7-70e2-a3eb-a47f28cbb5c2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70a8-7117-8f43-608140e3cd4b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70a9-735f-845c-7a6e87830898');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70aa-71b5-abec-6878eacd7f85');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ab-723a-80f2-3070636ba633');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ab-723a-80f2-3070641d3774');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ac-7137-a000-cc084ed96d3e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ad-73e7-96b7-50cc74ccdace');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ad-73e7-96b7-50cc750ec117');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ae-710f-bd09-1dfbf859e5a4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70af-738c-a608-fcb361260abc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70b1-70df-a816-f19bf7d0d4f0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70b3-723a-ad9f-cbbbaa835666');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70b4-7336-854e-0ad8ba5d686a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70b7-727b-a510-f4c4e6f024ed');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70b8-7203-aa3b-2b459263b7bf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70b9-7086-ab2f-1d56c2ba05d5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ba-70ae-af63-a1e8f9ee7a52');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70bb-7107-a4c6-ef8b0fb2135f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70bc-7345-afca-f4950e0eb6fc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70be-7063-84b5-2ed198d69702');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70c0-72ce-852b-31e4846d5ae2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70c0-72ce-852b-31e485635340');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70c1-720e-a203-adbb93862333');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70c2-7227-b09e-dd406aee3457');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70c3-715c-b91f-b2754c6a6f51');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70c5-72f6-afcc-4191560abf62');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70c7-7200-bdda-7d8b50af224d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70c8-7134-99e9-443fa713d17e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70c9-733d-b030-5375eed2c4fe');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ca-7324-b9f2-c86c533b3c84');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ca-7324-b9f2-c86c5391ec25');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70cb-71c1-a7c9-87561625f024');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70cd-7045-9086-2f3cd7b47b8e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ce-7272-afa9-7a449c36bc30');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70cf-70b9-a5af-6b5c76786a6b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70d0-7088-a1cc-0fddf63c24f8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70d0-7088-a1cc-0fddf68d613e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70d1-71ee-8e6f-15ced224a107');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70d1-71ee-8e6f-15ced23469b9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70d3-73ac-aea0-7a390198b4b6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70d4-7367-82cc-7efccd8b3e49');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70d6-7248-9002-c47572b99190');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70d8-7012-959a-3c34e41b3cfe');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70d9-716f-9917-7f7019f4fd98');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70d9-716f-9917-7f701aefdbde');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70da-726d-9628-6dbea8338a28');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70db-7369-82de-42edef43edc6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70db-7369-82de-42edefcaaa62');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70dc-73bf-816e-33a8f7e0135c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70dd-7094-8a14-1459f333b510');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70dd-7094-8a14-1459f353bc81');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70de-73ba-970b-6e8c3dd79e54');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70df-73e6-8ba5-17d5c2c89137');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70e0-7395-ba56-4ecce83e217c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70e1-72a9-aae7-2d31df9f1475');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70e1-72a9-aae7-2d31dfa74c34');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70e2-72a2-a150-8a5d191b8e40');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70e3-71d8-b8a7-f0c244dfbca1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70e4-7373-9eec-b51fa5740c15');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70e6-716c-bf02-d8f5d29cfd7b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ea-7201-aea1-60c0d09995f5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ea-7201-aea1-60c0d1375a59');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70eb-733d-8fa5-69dae43c9a3a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70eb-733d-8fa5-69dae4907319');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ec-7221-a310-5287c80cba84');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ec-7221-a310-5287c82773c8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ed-7399-95c0-89871f4af20a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ee-727c-aab2-37372d6bff62');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ef-70ec-81cd-75136224c589');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70f0-7341-b470-ae3d96f98238');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70f0-7341-b470-ae3d974768ab');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70f1-7251-b39f-bf6a4d73b10c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70f2-723d-95c7-bbeccadcc32b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70f2-723d-95c7-bbeccb59cbc5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70f3-718c-ae1a-d314552ffe05');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70f4-72b1-a332-480343c96e6d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70f4-72b1-a332-480344976634');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70f5-7103-932d-38c72598faca');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70f6-7121-adc5-235b2cff22e3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70f8-7391-929a-740d97d9f621');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70f9-720b-a4cb-ec60b55777af');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70fa-722e-9f65-5ba725bab7de');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70fb-7271-aed7-6f016a624359');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70fc-70da-a187-0384b7e36f5a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70fc-70da-a187-0384b8531dad');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70fd-72e4-956b-0e2728a0e1fa');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70fd-72e4-956b-0e27296d351d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70fe-73f1-a3d5-5a476b7e8491');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70fe-73f1-a3d5-5a476c17c505');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-70ff-732b-bc03-5ba7481b3496');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7100-736c-a6f1-45af29351d9b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7100-736c-a6f1-45af2a05bbad');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7101-7165-b2bc-04dbdfde8eb1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7102-724a-97e0-328b1ca3dc2c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7102-724a-97e0-328b1d379edb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', '01a115ac-7103-7218-bb01-0d30a4d92ba9');

DROP TABLE IF EXISTS "roles";
CREATE TABLE "roles" ("id" varchar not null, "tenant_id" varchar, "name" varchar not null, "slug" varchar not null, "is_system" tinyint(1) not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));

INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a115ac-7106-738c-9123-a5d228a0f3d4', NULL, 'Super Admin', 'super_admin', 1, '2026-10-07 09:23:05', '2026-10-07 09:23:05');

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

INSERT INTO "user_roles" ("id", "user_id", "role_id", "branch_id", "store_id", "created_at", "updated_at") VALUES ('01a115ac-7136-72b8-af78-2af455aabb9a', '01a115ac-7134-7081-9535-609952557aea', '01a115ac-7106-738c-9123-a5d228a0f3d4', NULL, NULL, '2026-10-07 09:23:05', '2026-10-07 09:23:05');

DROP TABLE IF EXISTS "users";
CREATE TABLE "users" ("id" varchar not null, "name" varchar not null, "email" varchar not null, "email_verified_at" datetime, "password" varchar not null, "phone" varchar, "pin" varchar, "is_active" tinyint(1) not null default ('1'), "remember_token" varchar, "created_at" datetime, "updated_at" datetime, "tenant_id" varchar, "api_token" varchar, "two_factor_secret" text, "two_factor_confirmed_at" datetime, "two_factor_recovery_codes" text, "phone_verified_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete set null, primary key ("id"));

INSERT INTO "users" ("id", "name", "email", "email_verified_at", "password", "phone", "pin", "is_active", "remember_token", "created_at", "updated_at", "tenant_id", "api_token", "two_factor_secret", "two_factor_confirmed_at", "two_factor_recovery_codes", "phone_verified_at") VALUES ('01a115ac-7134-7081-9535-609952557aea', 'Platform Backup', 'platform-backup@test.local', NULL, '$2y$04$pl3EwaGrNVpqrJD8oohflumYuECYp5AZDFw5LMli/ykdvIUSld1OK', NULL, NULL, 1, NULL, '2026-10-07 09:23:05', '2026-10-07 09:23:05', NULL, NULL, NULL, NULL, NULL, NULL);

DROP TABLE IF EXISTS "warehouses";
CREATE TABLE "warehouses" ("id" varchar not null, "tenant_id" varchar not null, "branch_id" varchar not null, "name" varchar not null, "code" varchar not null, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("branch_id") references "branches"("id") on delete cascade, primary key ("id"));


COMMIT;
PRAGMA foreign_keys=ON;
