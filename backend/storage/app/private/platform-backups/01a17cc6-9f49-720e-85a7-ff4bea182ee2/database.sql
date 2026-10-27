-- ITARA-POS logical database backup
-- driver: sqlite
-- created: 2026-10-27T09:52:34+00:00

PRAGMA foreign_keys=OFF;
BEGIN;

DROP TABLE IF EXISTS "accounting_entries";
CREATE TABLE "accounting_entries" ("id" varchar not null, "tenant_id" varchar not null, "entry_type" varchar not null, "reference_type" varchar, "reference_id" varchar, "debit" integer not null default '0', "credit" integer not null default '0', "account_code" varchar not null, "description" text, "recorded_by" varchar, "occurred_at" datetime, "created_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("recorded_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "audit_logs";
CREATE TABLE "audit_logs" ("id" varchar not null, "tenant_id" varchar not null, "user_id" varchar, "action" varchar not null, "entity_type" varchar not null, "entity_id" varchar, "payload" text, "ip_address" varchar, "created_at" datetime not null default CURRENT_TIMESTAMP, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("user_id") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "auth_tokens";
CREATE TABLE "auth_tokens" ("id" varchar not null, "user_id" varchar not null, "device_name" varchar, "access_token_hash" varchar not null, "refresh_token_hash" varchar not null, "ip_address" varchar, "user_agent" text, "last_used_at" datetime, "access_expires_at" datetime not null, "refresh_expires_at" datetime not null, "revoked_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("user_id") references "users"("id") on delete cascade, primary key ("id"));

INSERT INTO "auth_tokens" ("id", "user_id", "device_name", "access_token_hash", "refresh_token_hash", "ip_address", "user_agent", "last_used_at", "access_expires_at", "refresh_expires_at", "revoked_at", "created_at", "updated_at") VALUES ('01a17cc6-9f38-7312-a220-13bd2d50b03e', '01a17cc6-9f35-7387-9d27-fca48114c8eb', NULL, 'dac1c4eca4cb29645180191ab1cfc39afcdbbdd16e0a9f9e72a555153b2e154d', 'a31d85fa3783940914c705be47fc7030110d4207ca9eb869b3601921867921c6', NULL, NULL, '2026-10-27 09:52:34', '2026-10-27 10:52:34', '2026-11-26 09:52:34', NULL, '2026-10-27 09:52:34', '2026-10-27 09:52:34');

DROP TABLE IF EXISTS "barcodes";
CREATE TABLE "barcodes" ("id" varchar not null, "tenant_id" varchar not null, "barcodeable_type" varchar not null, "barcodeable_id" varchar not null, "barcode" varchar not null, "type" varchar not null default 'internal', "is_primary" tinyint(1) not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "batches";
CREATE TABLE "batches" ("id" varchar not null, "tenant_id" varchar not null, "product_id" varchar not null, "batch_number" varchar not null, "manufactured_at" date, "expires_at" date, "supplier_id" varchar, "metadata" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "unit_cost" integer, "received_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete cascade, foreign key("supplier_id") references "suppliers"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "branch_expenses";
CREATE TABLE "branch_expenses" ("id" varchar not null, "tenant_id" varchar not null, "branch_id" varchar not null, "store_id" varchar, "category" varchar not null default 'other', "description" varchar not null, "amount" integer not null, "currency_code" varchar not null default 'FBU', "occurred_on" date not null, "notes" text, "created_at" datetime, "updated_at" datetime, "expense_category_id" varchar, "cash_register_session_id" varchar, "user_id" varchar, "recorded_by" varchar, "reference" varchar, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("branch_id") references "branches"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "branches";
CREATE TABLE "branches" ("id" varchar not null, "tenant_id" varchar not null, "company_id" varchar not null, "name" varchar not null, "code" varchar not null, "address" text, "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "settings" text, "location_id" varchar, foreign key("company_id") references companies("id") on delete cascade on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("location_id") references "locations"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "brands";
CREATE TABLE "brands" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "slug" varchar not null, "description" text, "logo_url" varchar, "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "store_id" varchar, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("store_id") references "stores"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "business_documents";
CREATE TABLE "business_documents" ("id" varchar not null, "tenant_id" varchar not null, "party_id" varchar, "location_id" varchar, "kind" varchar not null, "number" varchar, "status" varchar not null default 'draft', "source_type" varchar, "source_id" varchar, "payload" text, "issued_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("party_id") references "parties"("id") on delete set null, foreign key("location_id") references "locations"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "cash_movements";
CREATE TABLE "cash_movements" ("id" varchar not null, "tenant_id" varchar not null, "cash_register_id" varchar not null, "cash_register_session_id" varchar, "cashier_shift_id" varchar, "movement_type" varchar not null, "amount" integer not null, "reference_type" varchar, "reference_id" varchar, "reference" varchar, "description" varchar, "performed_by" varchar, "occurred_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("cash_register_id") references "cash_registers"("id") on delete cascade, foreign key("cash_register_session_id") references "cash_register_sessions"("id") on delete set null, foreign key("performed_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "cash_register_sessions";
CREATE TABLE "cash_register_sessions" ("id" varchar not null, "tenant_id" varchar not null, "cash_register_id" varchar not null, "opened_by" varchar, "closed_by" varchar, "status" varchar not null default 'open', "opening_balance" integer not null default '0', "sales_total" integer not null default '0', "cash_in_total" integer not null default '0', "cash_out_total" integer not null default '0', "expenses_total" integer not null default '0', "expected_cash" integer not null default '0', "actual_cash" integer, "variance" integer, "opening_notes" text, "closing_notes" text, "opened_at" datetime, "closed_at" datetime, "created_at" datetime, "updated_at" datetime, "variance_reason" text, "counted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("cash_register_id") references "cash_registers"("id") on delete cascade, foreign key("opened_by") references "users"("id") on delete set null, foreign key("closed_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "cash_registers";
CREATE TABLE "cash_registers" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "device_id" varchar, "name" varchar not null, "code" varchar not null, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete cascade, foreign key("device_id") references "devices"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "cashier_shifts";
CREATE TABLE "cashier_shifts" ("id" varchar not null, "tenant_id" varchar not null, "cashier_id" varchar, "cash_register_id" varchar not null, "cash_register_session_id" varchar, "status" varchar not null default ('open'), "opening_balance" integer not null default ('0'), "expected_cash" integer not null default ('0'), "opening_notes" text, "opened_at" datetime, "created_at" datetime, "updated_at" datetime, "sales_total" integer not null default ('0'), "refunds_total" integer not null default ('0'), "discounts_total" integer not null default ('0'), "cash_in_total" integer not null default ('0'), "cash_out_total" integer not null default ('0'), "expenses_total" integer not null default ('0'), "actual_cash" integer, "variance" integer, "variance_reason" text, "closing_notes" text, "closed_at" datetime, "client_uuid" varchar, "branch_id" varchar, "device_id" varchar, foreign key("cash_register_session_id") references cash_register_sessions("id") on delete set null on update no action, foreign key("cash_register_id") references cash_registers("id") on delete cascade on update no action, foreign key("cashier_id") references users("id") on delete set null on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("branch_id") references "branches"("id") on delete set null, foreign key("device_id") references "devices"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "catalog_attributes";
CREATE TABLE "catalog_attributes" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "code" varchar not null, "values" text not null, "sort_order" integer not null default ('0'), "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "store_id" varchar, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("store_id") references "stores"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "catalogs";
CREATE TABLE "catalogs" ("id" varchar not null, "tenant_id" varchar not null, "company_id" varchar not null, "name" varchar not null, "description" text, "is_default" tinyint(1) not null default ('0'), "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "store_id" varchar, foreign key("company_id") references companies("id") on delete cascade on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("store_id") references "stores"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "categories";
CREATE TABLE "categories" ("id" varchar not null, "tenant_id" varchar not null, "catalog_id" varchar not null, "parent_id" varchar, "name" varchar not null, "slug" varchar not null, "sort_order" integer not null default ('0'), "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "store_id" varchar, foreign key("parent_id") references categories("id") on delete set null on update no action, foreign key("catalog_id") references catalogs("id") on delete cascade on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("store_id") references "stores"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "companies";
CREATE TABLE "companies" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "legal_name" varchar, "tax_id" varchar, "currency_code" varchar not null default ('FBU'), "address" text, "settings" text, "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "trade_name" varchar, "legal_form" varchar, "registration_number" varchar, "phone" varchar, "email" varchar, "website" varchar, "logo_url" varchar, "locale" varchar not null default ('fr'), "timezone" varchar not null default ('Africa/Bujumbura'), "party_id" varchar, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("party_id") references "parties"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "company_payment_methods";
CREATE TABLE "company_payment_methods" ("id" varchar not null, "tenant_id" varchar not null, "company_id" varchar not null, "code" varchar not null, "label" varchar not null, "label_fr" varchar, "is_enabled" tinyint(1) not null default '1', "available_on_pos" tinyint(1) not null default '1', "sort_order" integer not null default '0', "config" text, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("company_id") references "companies"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "crm_accounts";
CREATE TABLE "crm_accounts" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "legal_name" varchar, "email" varchar, "phone" varchar, "website" varchar, "tax_id" varchar, "industry" varchar, "address" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "party_id" varchar, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("party_id") references "parties"("id") on delete set null, primary key ("id"));


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


DROP TABLE IF EXISTS "currency_exchange_rates";
CREATE TABLE "currency_exchange_rates" ("id" varchar not null, "tenant_id" varchar not null, "currency_id" varchar not null, "currency_code" varchar not null, "rate" numeric not null, "previous_rate" numeric, "base_currency_code" varchar not null, "effective_at" datetime not null, "changed_by" varchar, "source" varchar not null default 'manual', "note" varchar, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("currency_id") references "currencies"("id") on delete cascade, foreign key("changed_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "customer_addresses";
CREATE TABLE "customer_addresses" ("id" varchar not null, "tenant_id" varchar not null, "customer_id" varchar not null, "label" varchar not null default 'default', "line1" varchar not null, "line2" varchar, "city" varchar, "state" varchar, "postal_code" varchar, "country_code" varchar not null default 'BI', "is_primary" tinyint(1) not null default '0', "is_billing" tinyint(1) not null default '0', "is_shipping" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("customer_id") references "customers"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "customer_payments";
CREATE TABLE "customer_payments" ("id" varchar not null, "tenant_id" varchar not null, "customer_id" varchar not null, "payment_number" varchar not null, "amount" integer not null, "payment_method" varchar not null default 'cash', "reference" varchar, "notes" text, "status" varchar not null default 'completed', "paid_at" datetime not null, "recorded_by" varchar, "allocations" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("customer_id") references "customers"("id") on delete cascade, foreign key("recorded_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "customer_transactions";
CREATE TABLE "customer_transactions" ("id" varchar not null, "tenant_id" varchar not null, "customer_id" varchar not null, "sale_id" varchar, "customer_payment_id" varchar, "transaction_type" varchar not null, "reference" varchar, "amount" integer not null, "paid_amount" integer not null default '0', "due_date" date, "loyalty_points_delta" integer not null default '0', "description" text, "recorded_by" varchar, "occurred_at" datetime not null, "created_at" datetime not null default CURRENT_TIMESTAMP, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("customer_id") references "customers"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete set null, foreign key("customer_payment_id") references "customer_payments"("id") on delete set null, foreign key("recorded_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "customers";
CREATE TABLE "customers" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "email" varchar, "phone" varchar, "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "code" varchar, "company_name" varchar, "tax_id" varchar, "date_of_birth" date, "gender" varchar, "credit_limit" integer, "payment_terms_days" integer not null default ('0'), "loyalty_points" integer not null default ('0'), "loyalty_tier" varchar not null default ('standard'), "notes" text, "metadata" text, "crm_role" varchar not null default ('client'), "job_title" varchar, "crm_account_id" varchar, "party_id" varchar, foreign key("crm_account_id") references crm_accounts("id") on delete set null on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("party_id") references "parties"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "desk_documents";
CREATE TABLE "desk_documents" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "code" varchar not null, "kind" varchar not null, "parent_code" varchar, "status" varchar, "payload" text not null, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "device_warehouse";
CREATE TABLE "device_warehouse" ("device_id" varchar not null, "warehouse_id" varchar not null, foreign key("device_id") references "devices"("id") on delete cascade, foreign key("warehouse_id") references "warehouses"("id") on delete cascade, primary key ("device_id", "warehouse_id"));


DROP TABLE IF EXISTS "devices";
CREATE TABLE "devices" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "name" varchar not null, "device_type" varchar not null, "identifier" varchar not null, "is_active" tinyint(1) not null default ('1'), "last_sync_at" datetime, "created_at" datetime, "updated_at" datetime, "category" varchar not null default ('pos'), "pos_role" varchar not null default ('standalone'), "master_device_id" varchar, "master_host" varchar, "platform" varchar, "app_version" varchar, "connection_type" varchar, "ip_address" varchar, "port" integer, "description" text, "registration_status" varchar not null default ('pending'), "sync_token" varchar, "token_generated_at" datetime, "registered_at" datetime, "code" varchar, "user_id" varchar, "branch_id" varchar, "local_server" varchar, "status" varchar not null default 'pending', "revoked_at" datetime, foreign key("store_id") references stores("id") on delete cascade on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("user_id") references "users"("id") on delete set null, foreign key("branch_id") references "branches"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "employees";
CREATE TABLE "employees" ("id" varchar not null, "tenant_id" varchar not null, "party_id" varchar not null, "user_id" varchar, "code" varchar, "job_title" varchar, "department" varchar, "hired_on" date, "terminated_on" date, "metadata" text, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("party_id") references "parties"("id") on delete cascade, foreign key("user_id") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "expense_categories";
CREATE TABLE "expense_categories" ("id" varchar not null, "tenant_id" varchar not null, "code" varchar not null, "name" varchar not null, "is_active" tinyint(1) not null default '1', "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, "color" varchar not null default '#6366F1', "description" varchar, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "gallery_images";
CREATE TABLE "gallery_images" ("id" varchar not null, "tenant_id" varchar not null, "catalog_id" varchar, "storage_path" varchar not null, "cdn_url" varchar not null, "original_filename" varchar, "mime_type" varchar not null, "file_size" integer not null default ('0'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "product_id" varchar, foreign key("catalog_id") references catalogs("id") on delete set null on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("product_id") references "products"("id") on delete set null, primary key ("id"));


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


DROP TABLE IF EXISTS "locations";
CREATE TABLE "locations" ("id" varchar not null, "tenant_id" varchar not null, "parent_id" varchar, "type" varchar not null, "name" varchar not null, "code" varchar, "address" text, "geo" text, "metadata" text, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("parent_id") references "locations"("id") on delete set null, primary key ("id"));


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
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (56, '2026_09_02_000002_create_sale_receipts_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (57, '2026_09_02_000003_create_sale_invoices_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (58, '2026_09_02_000004_extend_sales_for_phase29', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (59, '2026_09_02_000005_create_payment_transactions_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (60, '2026_09_02_000005_create_sale_refunds_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (61, '2026_09_02_000006_extend_payment_transactions_for_refunds', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (62, '2026_09_03_000001_extend_companies_for_identification', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (63, '2026_09_03_000002_create_currencies_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (64, '2026_09_03_000010_create_company_payment_methods_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (65, '2026_09_08_000001_extend_devices_for_terminal_pairing', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (66, '2026_09_08_000002_create_inventory_document_lines', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (67, '2026_09_08_000004_add_count_type_to_inventory_counts', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (68, '2026_09_08_000005_create_product_sale_units', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (69, '2026_09_09_000001_create_chart_of_accounts_and_fiscal_periods', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (70, '2026_09_13_000001_create_pos_reservations_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (71, '2026_09_13_000002_create_inventory_verifications_tables', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (72, '2026_09_13_000003_create_store_user_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (73, '2026_09_13_000004_add_locale_timezone_to_companies', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (74, '2026_09_13_000005_add_branch_establishments', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (75, '2026_09_13_000005_create_product_sale_units_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (76, '2026_09_13_000006_add_device_identity', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (77, '2026_09_13_000006_add_inventory_count_workflow_columns', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (78, '2026_09_13_000007_create_catalog_attributes_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (79, '2026_09_13_000008_create_product_supplier_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (80, '2026_09_13_000009_add_issue_unit_columns_to_stock_adjustment_items', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (81, '2026_09_13_000010_create_audit_logs_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (82, '2026_09_13_000011_add_confirmed_columns_to_stock_adjustments', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (83, '2026_09_13_000012_create_sync_events_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (84, '2026_09_13_000013_add_shift_close_and_variance_reason', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (85, '2026_09_13_000014_create_promotions_tables', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (86, '2026_09_13_000015_create_expense_categories_and_link_expenses', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (87, '2026_09_14_000001_repair_missing_sales_and_purchase_schema', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (88, '2026_09_14_000001_z_create_sale_return_items_table', 1);
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
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (115, '2026_10_07_000100_add_cash_count_columns_to_sessions', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (116, '2026_10_07_120000_create_notification_center_tables', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (117, '2026_10_07_180000_add_performance_indexes', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (118, '2026_10_07_200000_create_platform_backup_tables', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (119, '2026_10_07_210000_create_business_core_tables', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (120, '2026_10_07_210000_create_currency_exchange_rates_and_fx_payment_columns', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (121, '2026_10_07_210000_create_numbering_tables', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (122, '2026_10_07_210000_create_tax_engine_tables', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (123, '2026_10_07_220000_create_transactions_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (124, '2026_10_07_230000_add_cashier_shift_context_links', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (125, '2026_10_07_230000_add_idempotency_keys_for_transactions', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (126, '2026_10_11_000003_add_service_mode_to_sales_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (127, '2026_10_12_000001_add_product_id_to_gallery_images', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (128, '2026_10_13_000001_create_password_reset_tokens_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (129, '2026_10_19_000001_add_is_main_to_stores_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (130, '2026_10_23_120000_create_qr_ordering_tables', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (131, '2026_10_27_120000_add_tenant_id_to_platform_backups', 1);

DROP TABLE IF EXISTS "notification_channel_settings";
CREATE TABLE "notification_channel_settings" ("id" varchar not null, "tenant_id" varchar not null, "channel" varchar not null, "enabled" tinyint(1) not null default '0', "config" text, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "notification_deliveries";
CREATE TABLE "notification_deliveries" ("id" varchar not null, "tenant_id" varchar not null, "user_id" varchar, "event" varchar not null, "channel" varchar not null, "status" varchar not null, "recipient" varchar, "title" varchar not null, "body" text not null, "fingerprint" varchar not null, "error" text, "sent_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("user_id") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "notification_preferences";
CREATE TABLE "notification_preferences" ("id" varchar not null, "tenant_id" varchar not null, "user_id" varchar, "scope_key" varchar not null, "event" varchar not null, "channels" text not null, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("user_id") references "users"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "numbering_rules";
CREATE TABLE "numbering_rules" ("id" varchar not null, "tenant_id" varchar not null, "branch_id" varchar, "scope_key" varchar not null, "document_type" varchar not null, "prefix" varchar not null, "pattern" varchar not null default '{prefix}-{year}-{sequence}', "padding" integer not null default '6', "reset_policy" varchar not null default 'yearly', "starting_number" integer not null default '1', "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("branch_id") references "branches"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "numbering_sequences";
CREATE TABLE "numbering_sequences" ("id" varchar not null, "tenant_id" varchar not null, "branch_id" varchar, "scope_key" varchar not null, "document_type" varchar not null, "period_key" varchar not null default '', "last_value" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("branch_id") references "branches"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "offline_transactions";
CREATE TABLE "offline_transactions" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar, "client_uuid" varchar not null, "domain" varchar not null, "entity_type" varchar not null, "entity_id" varchar not null, "operation" varchar not null, "payload_hash" varchar not null, "payload" text not null, "base_version" varchar, "status" varchar not null, "result" text, "conflict_code" varchar, "error" text, "attempts" integer not null default '0', "synced_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "parties";
CREATE TABLE "parties" ("id" varchar not null, "tenant_id" varchar not null, "kind" varchar not null default 'person', "display_name" varchar not null, "legal_name" varchar, "code" varchar, "email" varchar, "phone" varchar, "tax_id" varchar, "address" text, "notes" text, "metadata" text, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "party_contexts";
CREATE TABLE "party_contexts" ("id" varchar not null, "tenant_id" varchar not null, "party_id" varchar not null, "context" varchar not null, "label" varchar, "metadata" text, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("party_id") references "parties"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "password_reset_tokens";
CREATE TABLE "password_reset_tokens" ("email" varchar not null, "token" varchar not null, "created_at" datetime, primary key ("email"));


DROP TABLE IF EXISTS "payment_transactions";
CREATE TABLE "payment_transactions" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar, "sale_id" varchar, "transaction_number" varchar not null, "payment_method" varchar not null, "amount" integer not null, "currency" varchar not null default 'FBU', "status" varchar not null default 'pending', "provider_type" varchar not null, "provider_reference" varchar, "idempotency_key" varchar, "customer_id" varchar, "cash_register_id" varchar, "processed_by" varchar, "metadata" text, "completed_at" datetime, "created_at" datetime, "updated_at" datetime, "transaction_type" varchar not null default 'payment', "sale_return_id" varchar, "original_transaction_id" varchar, "amount_in_sale_currency" integer, "exchange_rate" numeric, "sale_currency" varchar, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete set null, foreign key("sale_id") references "sales"("id") on delete set null, foreign key("customer_id") references "customers"("id") on delete set null, foreign key("processed_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "permissions";
CREATE TABLE "permissions" ("id" varchar not null, "name" varchar not null, "slug" varchar not null, "group" varchar not null, "created_at" datetime not null default CURRENT_TIMESTAMP, primary key ("id"));

INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e2c-7135-a655-903ee806682c', 'View dashboard', 'dashboard.view', 'dashboard', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e2c-7135-a655-903ee8833aaf', 'View companies', 'organization.companies.view', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e2d-732a-a009-ecbc5d52116b', 'Manage companies', 'organization.companies.manage', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e2d-732a-a009-ecbc5dba66c6', 'View branches', 'organization.branches.view', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e2d-732a-a009-ecbc5e6d0233', 'Manage branches', 'organization.branches.manage', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e2e-7063-861c-b2f176134295', 'View stores', 'organization.stores.view', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e2e-7063-861c-b2f17624b2c9', 'Manage stores', 'organization.stores.manage', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e2e-7063-861c-b2f176b2b6cf', 'View warehouses', 'organization.warehouses.view', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e2e-7063-861c-b2f17795992f', 'Manage warehouses', 'organization.warehouses.manage', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e2f-70bf-9265-c7242641fc16', 'View devices', 'organization.devices.view', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e2f-70bf-9265-c72426b5ed82', 'Manage devices', 'organization.devices.manage', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e30-7244-bd1d-283d2762ba51', 'View currencies', 'organization.currencies.view', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e30-7244-bd1d-283d27d463ef', 'Manage currencies', 'organization.currencies.manage', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e30-7244-bd1d-283d28c23c98', 'View payment methods', 'organization.payment_methods.view', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e31-710c-be29-b932f10bd518', 'Manage payment methods', 'organization.payment_methods.manage', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e31-710c-be29-b932f18b68c1', 'View catalogs', 'catalog.catalogs.view', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e31-710c-be29-b932f2268a5b', 'Manage catalogs', 'catalog.catalogs.manage', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e31-710c-be29-b932f24c8e80', 'View categories', 'catalog.categories.view', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e32-7212-bf01-4af64372aef7', 'Manage categories', 'catalog.categories.manage', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e32-7212-bf01-4af64419192b', 'View products', 'catalog.products.view', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e32-7212-bf01-4af64493eedb', 'Manage products', 'catalog.products.manage', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e33-70de-ab1f-6403cb035b35', 'View barcodes', 'catalog.barcodes.view', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e33-70de-ab1f-6403cb3db255', 'Manage barcodes', 'catalog.barcodes.manage', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e33-70de-ab1f-6403cc2269ca', 'View sales', 'sales.view', 'sales', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e34-7163-9777-8c16d571ea1c', 'Create sales', 'sales.create', 'sales', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e34-7163-9777-8c16d5cd1b02', 'Create sale', 'sale.create', 'sales', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e34-7163-9777-8c16d64928e6', 'Create payment', 'payments.create', 'sales', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e35-71fa-9c18-5ae4c9c6d3dc', 'Create payment', 'payment.create', 'sales', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e35-71fa-9c18-5ae4c9d4054e', 'Print receipt', 'receipts.print', 'sales', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e35-71fa-9c18-5ae4ca552d06', 'Print receipt', 'receipt.print', 'sales', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e36-70a9-8cfc-67573eeef463', 'Void sales', 'sales.void', 'sales', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e36-70a9-8cfc-67573f43a1cf', 'Refund sales', 'sales.refund', 'sales', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e36-70a9-8cfc-675740346175', 'Refund sale', 'sale.refund', 'sales', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e36-70a9-8cfc-675740dd5b3f', 'Process sale returns', 'sales.return', 'sales', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e37-71dd-bb6c-7b4ea1420613', 'Merge pending sales', 'sales.merge', 'sales', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e37-71dd-bb6c-7b4ea16d95e3', 'Apply discounts', 'sales.discount.apply', 'sales', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e37-71dd-bb6c-7b4ea1d12370', 'View promotions', 'promotions.view', 'promotions', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e37-71dd-bb6c-7b4ea22bdc05', 'Manage promotions', 'promotions.manage', 'promotions', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e38-70fb-b72b-25e29b00c299', 'View cash registers', 'registers.view', 'registers', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e38-70fb-b72b-25e29bc332f7', 'Manage cash registers', 'registers.manage', 'registers', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e38-70fb-b72b-25e29bf3d78d', 'Open register session', 'registers.session.open', 'registers', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e39-70cc-bbbd-35a76cc5d648', 'Close register session', 'registers.session.close', 'registers', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e39-70cc-bbbd-35a76db0d71a', 'Record cash movements', 'registers.movement.record', 'registers', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e39-70cc-bbbd-35a76dc567f0', 'View cashier shifts', 'shifts.view', 'shifts', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e39-70cc-bbbd-35a76eac40af', 'Manage cashier shifts', 'shifts.manage', 'shifts', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3a-707c-adc6-0cb87a357bda', 'Open cashier shift', 'shifts.open', 'shifts', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3a-707c-adc6-0cb87a7a0b92', 'Close cashier shift', 'shifts.close', 'shifts', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3a-707c-adc6-0cb87b3d0b57', 'Record shift cash movements', 'shifts.movement.record', 'shifts', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3b-70ad-8367-442a82d446e6', 'View POS tables', 'pos.tables.view', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3b-70ad-8367-442a83b1b6ad', 'Manage POS tables', 'pos.tables.manage', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3b-70ad-8367-442a84564885', 'Open table orders', 'pos.tables.open', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3b-70ad-8367-442a84e0d11c', 'Transfer table orders', 'pos.tables.transfer', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3c-707e-b6c5-e5c4dd79021c', 'Merge table orders', 'pos.tables.merge', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3c-707e-b6c5-e5c4ddbe1f93', 'Reserve POS tables', 'pos.tables.reserve', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3c-707e-b6c5-e5c4de8a14c7', 'View POS table statistics', 'pos.tables.stats', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3d-7331-84a4-8488051a8b47', 'View inventory', 'inventory.view', 'inventory', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3d-7331-84a4-8488057c441d', 'Manage inventory', 'inventory.manage', 'inventory', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3d-7331-84a4-8488062190a7', 'Adjust stock', 'inventory.adjust', 'inventory', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3e-725a-9779-5b8e3d0c67e1', 'Adjust stock', 'stock.adjust', 'inventory', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3e-725a-9779-5b8e3d4819e2', 'Transfer stock', 'inventory.transfer', 'inventory', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3e-725a-9779-5b8e3db1b769', 'Create inventory count', 'inventory.count.create', 'inventory', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3f-7007-869b-6369ebe50513', 'Enter inventory count quantities', 'inventory.count.enter', 'inventory', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e3f-7007-869b-6369ecd8168e', 'Review inventory count', 'inventory.count.review', 'inventory', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e40-71ed-96d4-f3ef6297cd79', 'Approve inventory count and post adjustments', 'inventory.count.approve', 'inventory', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e40-71ed-96d4-f3ef63279e90', 'Configure cycle count rules', 'inventory.cycle.configure', 'inventory', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e40-71ed-96d4-f3ef640402be', 'View expenses', 'expenses.view', 'expenses', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e41-71e4-8e78-a5f6f3b21287', 'Manage expenses', 'expenses.manage', 'expenses', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e41-71e4-8e78-a5f6f400162b', 'Create expense', 'expenses.create', 'expenses', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e41-71e4-8e78-a5f6f429449c', 'Submit expense', 'expenses.submit', 'expenses', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e41-71e4-8e78-a5f6f513778d', 'Approve expense', 'expenses.approve', 'expenses', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e42-710f-bfd2-ede1c20a41e5', 'Pay expense', 'expenses.pay', 'expenses', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e42-710f-bfd2-ede1c2e726e4', 'Cancel expense', 'expenses.cancel', 'expenses', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e42-710f-bfd2-ede1c2fe464b', 'Manage expense categories', 'expenses.categories', 'expenses', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e43-7224-9709-2a82610177ab', 'Manage recurring expenses', 'expenses.recurring', 'expenses', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e43-7224-9709-2a826197e462', 'View expense reports', 'expenses.reports', 'expenses', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e43-7224-9709-2a82621dc946', 'Export expense reports', 'expenses.export', 'expenses', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e43-7224-9709-2a82626510e0', 'Manage expense budgets', 'expenses.budgets', 'expenses', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e44-7154-a0c0-a5de048831cb', 'View purchases', 'purchases.view', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e44-7154-a0c0-a5de055995a2', 'Manage purchases', 'purchases.manage', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e44-7154-a0c0-a5de05ed4e94', 'Receive goods', 'purchases.receive', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e45-71db-8a2b-96e4ca5fd38f', 'Create requisition', 'purchases.requisition.create', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e45-71db-8a2b-96e4cb1944cb', 'Approve requisition', 'purchases.requisition.approve', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e45-71db-8a2b-96e4cb9e27f5', 'Create proforma', 'purchases.proforma.create', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e46-7289-a2af-cddbeb5bfc56', 'Approve proforma', 'purchases.proforma.approve', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e46-7289-a2af-cddbebff85b7', 'Create purchase order', 'purchases.order.create', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e46-7289-a2af-cddbec801de2', 'Approve purchase order', 'purchases.order.approve', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e46-7289-a2af-cddbec981e21', 'Create supplier invoice', 'purchases.invoice.create', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e47-7354-9ac5-be105b6075bd', 'Approve supplier invoice', 'purchases.invoice.approve', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e47-7354-9ac5-be105b75e0e4', 'Make supplier payment', 'purchases.payment.create', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e47-7354-9ac5-be105beb7c2f', 'Approve supplier payment', 'purchases.payment.approve', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e48-7253-b173-3d235680e77e', 'Create purchase return', 'purchases.return.create', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e48-7253-b173-3d23573793b9', 'Approve purchase return', 'purchases.return.approve', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e48-7253-b173-3d235831bf69', 'Export purchase reports', 'purchases.export', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e48-7253-b173-3d2358ffce9f', 'Delete purchase documents', 'purchases.delete', 'purchases', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e49-733c-9609-3551c0b97b6d', 'View customers', 'customers.view', 'customers', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e49-733c-9609-3551c1aaeffe', 'Manage customers', 'customers.manage', 'customers', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e49-733c-9609-3551c1b91581', 'View suppliers', 'suppliers.view', 'suppliers', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4a-7344-b127-621b53f36ea0', 'Manage suppliers', 'suppliers.manage', 'suppliers', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4a-7344-b127-621b54129639', 'View users', 'users.view', 'admin', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4a-7344-b127-621b54f5ee8e', 'Manage users', 'users.manage', 'admin', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4b-73f2-86f6-4a727d05e6c6', 'View roles', 'roles.view', 'admin', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4b-73f2-86f6-4a727da0b653', 'Manage roles', 'roles.manage', 'admin', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4b-73f2-86f6-4a727da475bf', 'View reports', 'reports.view', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4b-73f2-86f6-4a727dce2b57', 'Export reports', 'reports.export', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4c-70b3-8e36-e900ff3e9930', 'View accounting', 'accounting.view', 'accounting', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4c-70b3-8e36-e900fffa2306', 'Manage accounting', 'accounting.manage', 'accounting', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4c-70b3-8e36-e900fffa30be', 'View transactions', 'transactions.view', 'transactions', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4d-72bf-8404-3658599c7e64', 'Manage transactions', 'transactions.manage', 'transactions', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4d-72bf-8404-36585a0b30a6', 'View audit logs', 'audit.view', 'audit', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4d-72bf-8404-36585a1b6618', 'View settings', 'settings.view', 'settings', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4d-72bf-8404-36585a8dc3f9', 'Manage settings', 'settings.manage', 'settings', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4e-7192-864b-ac617cbec2c8', 'View restaurant', 'restaurant.view', 'restaurant', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4e-7192-864b-ac617d3a0673', 'Manage restaurant', 'restaurant.manage', 'restaurant', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4f-7250-8c46-ca420709d014', 'View hotel', 'hotel.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4f-7250-8c46-ca4207c02e9d', 'Manage hotel', 'hotel.manage', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e4f-7250-8c46-ca4207cc64e2', 'View hotel dashboard', 'hotel.dashboard.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e50-7379-9243-24f1d4a90e02', 'View front desk', 'hotel.front_desk.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e50-7379-9243-24f1d5713e41', 'Check in at the front desk', 'hotel.front_desk.check_in', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e50-7379-9243-24f1d5d5a11b', 'View room configuration', 'hotel.referential.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e51-713a-aef0-ac1f23e927ba', 'Create room configuration', 'hotel.referential.create', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e51-713a-aef0-ac1f24d0abc2', 'Update room configuration', 'hotel.referential.update', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e51-713a-aef0-ac1f2583a6cf', 'Delete room configuration', 'hotel.referential.delete', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e52-7221-bb62-a9f09db7e378', 'View amenities', 'hotel.amenities.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e52-7221-bb62-a9f09e1064d5', 'Create amenities', 'hotel.amenities.create', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e52-7221-bb62-a9f09ed0343c', 'Update amenities', 'hotel.amenities.update', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e52-7221-bb62-a9f09f04cfa3', 'Delete amenities', 'hotel.amenities.delete', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e53-73b6-ae70-c3ca1377ee40', 'View room types', 'hotel.room_types.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e53-73b6-ae70-c3ca13d082b0', 'Create room types', 'hotel.room_types.create', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e53-73b6-ae70-c3ca13d14b40', 'Update room types', 'hotel.room_types.update', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e54-70df-b690-2fcc622b294f', 'Delete room types', 'hotel.room_types.delete', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e54-70df-b690-2fcc6254e804', 'View buildings', 'hotel.buildings.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e54-70df-b690-2fcc633437d6', 'Create buildings', 'hotel.buildings.create', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e55-73dd-834c-ec48c6b237aa', 'Update buildings', 'hotel.buildings.update', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e55-73dd-834c-ec48c7798660', 'Delete buildings', 'hotel.buildings.delete', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e55-73dd-834c-ec48c78fe3fd', 'View wings', 'hotel.wings.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e55-73dd-834c-ec48c8078828', 'Create wings', 'hotel.wings.create', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e56-70e5-8266-2d2805872198', 'Update wings', 'hotel.wings.update', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e56-70e5-8266-2d28061735c3', 'Delete wings', 'hotel.wings.delete', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e56-70e5-8266-2d28063a24fb', 'View floors', 'hotel.floors.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e57-7110-9893-2710e47699e5', 'Create floors', 'hotel.floors.create', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e57-7110-9893-2710e4bb9615', 'Update floors', 'hotel.floors.update', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e57-7110-9893-2710e55f5919', 'Delete floors', 'hotel.floors.delete', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e57-7110-9893-2710e5d97077', 'View rooms', 'hotel.rooms.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e58-7294-b1b2-2e3f64625b1c', 'Create rooms', 'hotel.rooms.create', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e58-7294-b1b2-2e3f64eba83b', 'Update rooms', 'hotel.rooms.update', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e58-7294-b1b2-2e3f65accf0b', 'Delete rooms', 'hotel.rooms.delete', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e59-72ee-9ffe-7a3592ea8b12', 'Update room status', 'hotel.rooms.update_status', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e59-72ee-9ffe-7a3593793a66', 'View hotel reservations', 'hotel.reservations.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e59-72ee-9ffe-7a3593c1784a', 'Create hotel reservations', 'hotel.reservations.create', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e59-72ee-9ffe-7a3593d44618', 'Update hotel reservations', 'hotel.reservations.update', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5a-7008-87bd-3035950f908b', 'Confirm hotel reservations', 'hotel.reservations.confirm', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5a-7008-87bd-3035951cf130', 'Cancel hotel reservations', 'hotel.reservations.cancel', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5a-7008-87bd-303595897be3', 'Mark reservation no-show', 'hotel.reservations.no_show', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5b-721b-af21-f1efbdf4d9cc', 'Collect reservation deposit', 'hotel.reservations.collect_deposit', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5b-721b-af21-f1efbe86ff72', 'Export hotel reservations', 'hotel.reservations.export', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5b-721b-af21-f1efbf501511', 'Notify reservation guests', 'hotel.reservations.notify', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5c-7107-9c00-adfa0d198ee7', 'View stays', 'hotel.stays.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5c-7107-9c00-adfa0dd344e0', 'Check in a stay', 'hotel.stays.check_in', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5c-7107-9c00-adfa0e79edb6', 'Record a stay arrival', 'hotel.stays.arrival', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5d-72f4-861a-130a6ddbe1cc', 'Change stay room', 'hotel.stays.change_room', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5d-72f4-861a-130a6e24ea76', 'Add a stay charge', 'hotel.stays.add_charge', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5d-72f4-861a-130a6ed0e8e3', 'Take a stay payment', 'hotel.stays.pay', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5e-7398-b59a-009db9d00fd5', 'Collect stay deposit', 'hotel.stays.collect_deposit', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5e-7398-b59a-009dba8a7c26', 'Refund stay deposit', 'hotel.stays.refund_deposit', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5e-7398-b59a-009dba944302', 'Check out a stay', 'hotel.stays.check_out', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5f-7021-a21f-9d06b40c739f', 'Sign a stay', 'hotel.stays.sign', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5f-7021-a21f-9d06b43092af', 'Export stays', 'hotel.stays.export', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e5f-7021-a21f-9d06b47a3256', 'View guest invoices', 'hotel.invoices.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e60-7278-822f-c704ecbf370e', 'Export guest invoices', 'hotel.invoices.export', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e60-7278-822f-c704ed46173a', 'Print guest invoices', 'hotel.invoices.print', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e60-7278-822f-c704ee0f013d', 'View hotel guests', 'hotel.guests.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e60-7278-822f-c704ef0113cb', 'Create hotel guests', 'hotel.guests.create', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e61-7049-ba8e-00a873626d3c', 'Update hotel guests', 'hotel.guests.update', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e61-7049-ba8e-00a873a66f93', 'Sign a guest record', 'hotel.guests.sign', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e61-7049-ba8e-00a873c841ca', 'Export hotel guests', 'hotel.guests.export', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e62-731e-885b-78dbcaf4d925', 'View housekeeping', 'hotel.housekeeping.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e62-731e-885b-78dbcaffa8d0', 'Update room condition', 'hotel.housekeeping.update_condition', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e62-731e-885b-78dbcb2460cd', 'Create housekeeping task', 'hotel.housekeeping.create_task', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e63-73b2-ad6d-e86abbb5e160', 'Update housekeeping task', 'hotel.housekeeping.update_task', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e63-73b2-ad6d-e86abc00929e', 'View hotel calendar', 'hotel.calendar.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e63-73b2-ad6d-e86abce9ecf1', 'Create calendar events', 'hotel.calendar.create', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e63-73b2-ad6d-e86abd9581f5', 'Update calendar events', 'hotel.calendar.update', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e64-70d5-8bd3-386c1419d28a', 'Delete calendar events', 'hotel.calendar.delete', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e64-70d5-8bd3-386c1512c087', 'View concierge', 'hotel.concierge.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e64-70d5-8bd3-386c160e8c74', 'Create concierge requests', 'hotel.concierge.create', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e65-7197-bad9-5725b7028f2d', 'Update concierge status', 'hotel.concierge.update_status', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e65-7197-bad9-5725b7b74a35', 'Assign concierge requests', 'hotel.concierge.assign', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e65-7197-bad9-5725b86e666d', 'View hotel reviews', 'hotel.reviews.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e66-72c6-8c4c-9caa216dbc97', 'Respond to hotel reviews', 'hotel.reviews.respond', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e66-72c6-8c4c-9caa21e79d1e', 'Update review status', 'hotel.reviews.update_status', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e66-72c6-8c4c-9caa229b0968', 'Export hotel reviews', 'hotel.reviews.export', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e66-72c6-8c4c-9caa2312dafb', 'View hotel reports', 'hotel.reports.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e67-7108-8772-7c1d81446584', 'Export hotel reports', 'hotel.reports.export', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e67-7108-8772-7c1d822da275', 'View hotel configuration', 'hotel.config.view', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e67-7108-8772-7c1d82df9766', 'Update hotel configuration', 'hotel.config.update', 'hotel', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e68-72cc-874a-247c1a663fe6', 'View analytics', 'analytics.view', 'dashboard', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e68-72cc-874a-247c1ab21ee0', 'View condensed reports', 'reports.condensed.view', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e68-72cc-874a-247c1b6c6292', 'Export condensed reports', 'reports.condensed.export', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e68-72cc-874a-247c1b9bb498', 'View daily reports', 'reports.daily.view', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e69-71ce-8948-9b4c8d33e12b', 'Export daily reports', 'reports.daily.export', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e69-71ce-8948-9b4c8d6202c1', 'View financial reports', 'reports.financial.view', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e69-71ce-8948-9b4c8e35c9cf', 'Export financial reports', 'reports.financial.export', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6a-70ab-8905-c7db22aba631', 'View forecasting reports', 'reports.forecasting.view', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6a-70ab-8905-c7db2317826e', 'Export forecasting reports', 'reports.forecasting.export', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6a-70ab-8905-c7db23f68220', 'View inventory reports', 'reports.inventory_reports.view', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6a-70ab-8905-c7db24ecf8fd', 'Export inventory reports', 'reports.inventory_reports.export', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6b-714e-85ac-367e31dbd5bf', 'View performance reports', 'reports.performance.view', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6b-714e-85ac-367e3283f547', 'Export performance reports', 'reports.performance.export', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6b-714e-85ac-367e3382ed0e', 'View sales reports', 'reports.sales_reports.view', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6c-70ce-b8d7-f31918c6aece', 'Export sales reports', 'reports.sales_reports.export', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6c-70ce-b8d7-f319197d59d5', 'Export revenue reports', 'reports.revenue.export', 'reports', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6c-70ce-b8d7-f3191a42aa00', 'Approve devices', 'organization.devices.approve', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6c-70ce-b8d7-f3191b343863', 'Block devices', 'organization.devices.block', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6d-7211-81af-da78368a0953', 'View sync', 'sync.view', 'sync', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6d-7211-81af-da78375709ee', 'Configure sync', 'sync.configure', 'sync', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6d-7211-81af-da7837d7f685', 'Force sync', 'sync.force', 'sync', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6e-7023-ada0-caec0bbb482e', 'View reservations', 'reservations.view', 'reservations', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6e-7023-ada0-caec0c8b1866', 'Manage reservations', 'reservations.manage', 'reservations', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6f-70ee-ad39-809561749b85', 'Access the point of sale', 'pos.access', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e6f-70ee-ad39-809562297f97', 'Work as cashier', 'pos.cashier', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e70-730e-a000-2a45798125b1', 'Choose session stores', 'pos.session.choose_stores', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e70-730e-a000-2a457a2aa75b', 'Open a session for others', 'pos.session.open_for_others', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e70-730e-a000-2a457ae09346', 'Print session report', 'pos.session.print_report', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e71-70d3-8de6-d301bc74cd39', 'Require a cashier session', 'pos.session.required', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e71-70d3-8de6-d301bcb2d2fe', 'Edit POS orders', 'pos.orders.edit', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e72-72f9-9f8f-8a1d47df25bd', 'Delete POS orders', 'pos.orders.delete', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e74-7174-a193-d92d33a4a7cc', 'Update POS orders', 'pos.orders.update', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e77-71a9-9fa3-404d80ad0046', 'Override order tax', 'pos.orders.tax_override', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e79-7277-9591-e07a45266d07', 'Override order price', 'pos.orders.override_price', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e7a-73ae-a0f8-672a053075af', 'Create delivery orders', 'pos.orders.delivery', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e7b-706a-9aa9-f342d0c4a11c', 'Create dine-in orders', 'pos.orders.dine_in', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e7b-706a-9aa9-f342d0d217d5', 'Create takeaway orders', 'pos.orders.takeaway', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e7c-702c-a7a4-5b5abede63b4', 'Send order to kitchen', 'pos.orders.send_kitchen', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e7d-72ab-8ab0-01c8211b97a7', 'Void an order item', 'pos.orders.void_item', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e7d-72ab-8ab0-01c8217d78ed', 'Refund an order item', 'pos.orders.refund_item', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e7e-7126-9336-859d50229fb2', 'Set the order date', 'pos.orders.set_date', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e7f-7345-a8fa-040a445b22a3', 'Print order invoice', 'pos.orders.print_invoice', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e80-730c-a5e0-69d9da03b077', 'Print kitchen ticket', 'pos.orders.print_kitchen', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e80-730c-a5e0-69d9daa83fba', 'Print order summary', 'pos.orders.print_summary', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e81-72f0-8d51-dc90e5d1360f', 'Reprint invoice', 'pos.orders.reprint_invoice', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e82-72e8-9109-831d580ea8a7', 'Reprint kitchen ticket', 'pos.orders.reprint_kitchen', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e82-72e8-9109-831d58fb19dd', 'Reprint order summary', 'pos.orders.reprint_summary', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e83-722d-b312-9ae677659573', 'Reprint receipt', 'pos.orders.reprint_receipt', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e83-722d-b312-9ae678305ead', 'Hold an order directly', 'pos.orders.hold_direct', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e84-70bb-ba30-13de10816001', 'Add to cart', 'pos.cart.add', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e85-7066-93c8-b3da1013eb01', 'Modify the cart', 'pos.cart.modify', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e86-73e3-86fd-57ad204459e9', 'Remove from cart', 'pos.cart.remove', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e86-73e3-86fd-57ad20bd4fb4', 'Clear the cart', 'pos.cart.clear', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e87-73a3-8304-1ca97f03111c', 'Hold an order', 'pos.cart.hold', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e88-7303-b3e3-7a9653180772', 'Assign a server', 'pos.cart.assign_server', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e89-70fb-86fa-7eb3e29f8067', 'View POS payments', 'pos.payments.view', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e8a-7042-aa97-400025569711', 'Refund a POS payment', 'pos.payments.refund', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e8b-702b-a251-1f869b5f444f', 'Take a mixed payment', 'pos.payments.mixed', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e8c-7242-aa91-dacdb8e2873a', 'Take a cash payment', 'pos.payments.cash', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e8c-7242-aa91-dacdb9d549b3', 'Take a card payment', 'pos.payments.card', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e8d-7166-abbc-d996aff840b1', 'Take a mobile payment', 'pos.payments.mobile', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e8e-71b9-930c-42156f32581b', 'Take a check payment', 'pos.payments.check', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e8e-71b9-930c-42156f6a4869', 'Take a wallet payment', 'pos.payments.wallet', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e8f-7104-993a-325befbbeccf', 'Take a bank transfer', 'pos.payments.bank_transfer', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e90-7110-b317-d98f5628b810', 'Pay and close the order', 'pos.payments.close', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e90-7110-b317-d98f57004866', 'Pay on credit', 'pos.payments.credit', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e91-703e-857e-c3038a881b7d', 'Require a customer for credit', 'pos.payments.credit_customer', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e91-703e-857e-c3038b34d1f2', 'Take a single payment', 'pos.payments.unique', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e92-7214-a448-ae45d48d6398', 'View the kitchen display', 'pos.kitchen.view', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e92-7214-a448-ae45d586ce68', 'Manage the kitchen display', 'pos.kitchen.manage', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e93-73bf-8e91-4b733254741d', 'View other shift details', 'pos.shifts.details', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e93-73bf-8e91-4b73330318a6', 'View all shifts', 'pos.shifts.view_all', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e94-7130-9261-f02aaddaf550', 'Override a discount', 'pos.discounts.override', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e94-7130-9261-f02aae174e54', 'View tips', 'pos.tips.view', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e95-7382-9af6-7facf7a34354', 'Manage tips', 'pos.tips.manage', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e96-70b8-bd57-37beaf27bdb0', 'Apply a promotion', 'pos.promotions.apply', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e97-70f4-8b4e-92d6aed2a318', 'Apply a coupon', 'pos.promotions.coupon', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e97-70f4-8b4e-92d6afc11c49', 'Apply a house offer', 'pos.offers.house', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e98-71e3-a164-c36afeb1e722', 'Require a customer for house offers', 'pos.offers.require_customer', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e99-723f-8d92-1d888dcfe1f0', 'Access POS sync', 'pos.sync.access', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e9a-7111-8585-065784029df8', 'Close the store from POS', 'pos.sync.close_store', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e9a-7111-8585-065784aa1c4f', 'Run a full sync', 'pos.sync.full', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e9b-725c-aafe-360e02e60826', 'Upload POS data', 'pos.sync.upload', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e9c-71a1-9136-2cce9833409d', 'View the last sync date', 'pos.sync.last_date', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e9c-71a1-9136-2cce98f26c7c', 'Attach a customer to the sale', 'pos.customers.attach', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e9d-7175-b709-7a2fab6eda55', 'Search POS customers', 'pos.customers.search', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e9e-7270-bae6-a0593d0a19e9', 'Print an invoice', 'pos.print.invoice', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9e9f-7104-a871-80c08287f6f5', 'Print a stub', 'pos.print.stub', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ea0-7345-8c86-e661c7dbd6d0', 'Print a kitchen ticket', 'pos.print.kitchen', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ea1-71a1-88fe-6e74fac8dfcf', 'Print the receipt and the kitchen ticket only once', 'pos.print.once', 'pos', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ea2-720e-b31b-d930e4b120c0', 'View CRM', 'crm.view', 'crm', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ea3-7310-9132-ee6b53d9b563', 'Manage CRM', 'crm.manage', 'crm', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ea4-730f-82c7-11fe5aff2a21', 'View HR', 'hr.view', 'hr', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ea5-7315-bdfa-6e19472bbff9', 'Manage HR', 'hr.manage', 'hr', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ea5-7315-bdfa-6e19478a25db', 'View projects', 'projects.view', 'projects', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ea6-72bd-a00a-f25344741af2', 'Manage projects', 'projects.manage', 'projects', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ea7-71de-9ac7-fa34d8691b49', 'View documents', 'documents.view', 'documents', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ea8-71d8-aeb2-4a22222b02de', 'Manage documents', 'documents.manage', 'documents', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ea9-71ea-93a3-a9a612dacc3c', 'View fleet', 'fleet.view', 'fleet', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eaa-7371-8de3-d377bc1805df', 'Manage fleet', 'fleet.manage', 'fleet', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eab-73da-b91b-cee86edd2bd4', 'View maintenance', 'maintenance.view', 'maintenance', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eac-7193-b49c-8b3fdff9ffa6', 'Manage maintenance', 'maintenance.manage', 'maintenance', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eac-7193-b49c-8b3fe0a033d3', 'View manufacturing', 'manufacturing.view', 'manufacturing', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ead-7114-9a32-1e76071ca8de', 'Manage manufacturing', 'manufacturing.manage', 'manufacturing', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eae-716c-bb91-765104ef2b8c', 'View e-commerce', 'ecommerce.view', 'ecommerce', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eaf-7275-9a1c-b7e0301eb1a2', 'Manage e-commerce', 'ecommerce.manage', 'ecommerce', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb0-7153-a399-e96b736d3559', 'View the notification center', 'notifications.view', 'notifications', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb1-7396-b1c3-4be7f23bdf09', 'Manage notification channels', 'notifications.manage', 'notifications', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb2-7126-a94c-8a3190b8b772', 'Create companies', 'organization.companies.create', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb3-73d8-8a71-32730c05e18a', 'Update companies', 'organization.companies.update', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb4-71de-b4e1-26bf8921f1b0', 'Delete companies', 'organization.companies.delete', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb4-71de-b4e1-26bf89edf1bd', 'Create branches', 'organization.branches.create', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb5-736b-bd89-bd32406a7581', 'Update branches', 'organization.branches.update', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb5-736b-bd89-bd3240d4486a', 'Delete branches', 'organization.branches.delete', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb6-7187-a1a0-b5cbf6eff7dd', 'Create stores', 'organization.stores.create', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb6-7187-a1a0-b5cbf7c31be8', 'Update stores', 'organization.stores.update', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb7-729d-bbf7-bb2e03437535', 'Delete stores', 'organization.stores.delete', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb7-729d-bbf7-bb2e035b9b43', 'Create warehouses', 'organization.warehouses.create', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb7-729d-bbf7-bb2e038539aa', 'Update warehouses', 'organization.warehouses.update', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb8-7368-a70f-93910c918e37', 'Delete warehouses', 'organization.warehouses.delete', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb8-7368-a70f-93910d2a6cf2', 'Create devices', 'organization.devices.create', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb9-7028-8b18-a91970c99166', 'Update devices', 'organization.devices.update', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eb9-7028-8b18-a91971adb657', 'Delete devices', 'organization.devices.delete', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eba-7107-beee-595927a69a00', 'Create currencies', 'organization.currencies.create', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ebb-71b2-8e2b-f77e304b3b1b', 'Update currencies', 'organization.currencies.update', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ebb-71b2-8e2b-f77e312a72eb', 'Delete currencies', 'organization.currencies.delete', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ebc-7015-bd0a-56a174a2f508', 'Create payment methods', 'organization.payment_methods.create', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ebc-7015-bd0a-56a174ab9e87', 'Update payment methods', 'organization.payment_methods.update', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ebd-7280-9d96-a6ad980e5b79', 'Delete payment methods', 'organization.payment_methods.delete', 'organization', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ebd-7280-9d96-a6ad98618ffe', 'Create catalogs', 'catalog.catalogs.create', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ebe-71ef-be2b-1760185d8082', 'Update catalogs', 'catalog.catalogs.update', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ebe-71ef-be2b-176018cfca4d', 'Delete catalogs', 'catalog.catalogs.delete', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ebf-72a3-bc0d-5ab8eb0b5200', 'Create categories', 'catalog.categories.create', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ebf-72a3-bc0d-5ab8eb18b86c', 'Update categories', 'catalog.categories.update', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ec0-71bd-abcb-27e79a1d78ad', 'Delete categories', 'catalog.categories.delete', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ec5-71c2-8578-3285e38e67a6', 'Create products', 'catalog.products.create', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ec9-70c9-8f1f-5f9f6cbbfe22', 'Update products', 'catalog.products.update', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eca-71a4-8c52-c20aaf07ad9a', 'Delete products', 'catalog.products.delete', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ecb-728f-baf8-9d08f02f103d', 'Create barcodes', 'catalog.barcodes.create', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ecc-71e3-bf92-2661598139c1', 'Update barcodes', 'catalog.barcodes.update', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ecc-71e3-bf92-26615995ed61', 'Delete barcodes', 'catalog.barcodes.delete', 'catalog', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ecd-709b-b778-58990d0cda9a', 'Create promotions', 'promotions.create', 'promotions', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ece-7198-934f-a5198a0b4f48', 'Update promotions', 'promotions.update', 'promotions', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ecf-718c-b628-7a3c0804b60c', 'Delete promotions', 'promotions.delete', 'promotions', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ecf-718c-b628-7a3c08fd1f60', 'Create cash registers', 'registers.create', 'registers', '2026-10-27 09:52:33');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ed0-700d-bdfd-9da8da068a4c', 'Update cash registers', 'registers.update', 'registers', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ed1-7337-a0d4-24d7890efda4', 'Delete cash registers', 'registers.delete', 'registers', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ed1-7337-a0d4-24d78949e581', 'Create cashier shifts', 'shifts.create', 'shifts', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ed2-73fb-b0cf-5dfac2b4285c', 'Update cashier shifts', 'shifts.update', 'shifts', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ed3-7169-9f8a-07cc6e70b06e', 'Delete cashier shifts', 'shifts.delete', 'shifts', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ed3-7169-9f8a-07cc6f3b7bf0', 'Create POS tables', 'pos.tables.create', 'pos', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ed4-7129-a012-ba01d0391046', 'Update POS tables', 'pos.tables.update', 'pos', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ed5-7091-b8cf-48b1e1e4fa92', 'Delete POS tables', 'pos.tables.delete', 'pos', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ed5-7091-b8cf-48b1e205e6e7', 'Create inventory', 'inventory.create', 'inventory', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ed6-72a0-90eb-44d9549bb4f2', 'Update inventory', 'inventory.update', 'inventory', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ed7-705d-b5ec-1331d7662d79', 'Delete inventory', 'inventory.delete', 'inventory', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ed7-705d-b5ec-1331d79f1d44', 'Update expenses', 'expenses.update', 'expenses', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ed8-72a9-8b4d-f69d5941154b', 'Delete expenses', 'expenses.delete', 'expenses', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ed9-70c5-a110-c47797e58579', 'Create purchases', 'purchases.create', 'purchases', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eda-7068-9488-7df090331d76', 'Update purchases', 'purchases.update', 'purchases', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9edb-707b-b94c-7e76b607e833', 'Create customers', 'customers.create', 'customers', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9edb-707b-b94c-7e76b696b5fe', 'Update customers', 'customers.update', 'customers', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9edc-7113-a470-53d403ff2170', 'Delete customers', 'customers.delete', 'customers', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9edc-7113-a470-53d404028eda', 'Create suppliers', 'suppliers.create', 'suppliers', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9edd-7061-8528-60580dab72fc', 'Update suppliers', 'suppliers.update', 'suppliers', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ede-71bf-88f3-018b1ba405ae', 'Delete suppliers', 'suppliers.delete', 'suppliers', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ede-71bf-88f3-018b1bc19b59', 'Create users', 'users.create', 'admin', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9edf-7181-9a6d-63806c365fcc', 'Update users', 'users.update', 'admin', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ee0-71f2-ab74-b3d4e4ffcaef', 'Delete users', 'users.delete', 'admin', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ee1-7004-86a6-229e47cf4a80', 'Create roles', 'roles.create', 'admin', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ee1-7004-86a6-229e484e5060', 'Update roles', 'roles.update', 'admin', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ee2-734a-834d-d706f2aed453', 'Delete roles', 'roles.delete', 'admin', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ee3-700e-a7cb-1b4f13f2fd0a', 'Create accounting', 'accounting.create', 'accounting', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ee3-700e-a7cb-1b4f14a53132', 'Update accounting', 'accounting.update', 'accounting', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ee4-7379-8ea7-dd849a1ad2c3', 'Delete accounting', 'accounting.delete', 'accounting', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ee5-7045-9f4b-7fa022e273d3', 'Create transactions', 'transactions.create', 'transactions', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ee5-7045-9f4b-7fa023b43618', 'Update transactions', 'transactions.update', 'transactions', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ee6-722f-b5d2-0a46f6a42e68', 'Delete transactions', 'transactions.delete', 'transactions', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ee6-722f-b5d2-0a46f75c7ff6', 'Create settings', 'settings.create', 'settings', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ee7-73b2-9742-90af79d84e11', 'Update settings', 'settings.update', 'settings', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ee8-70a4-a0d9-273f51d45ba1', 'Delete settings', 'settings.delete', 'settings', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ee9-70a9-b3d8-4d3420e7d58d', 'Create restaurant', 'restaurant.create', 'restaurant', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ee9-70a9-b3d8-4d3421c21dbb', 'Update restaurant', 'restaurant.update', 'restaurant', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eea-720c-a81f-d6455e2110d6', 'Delete restaurant', 'restaurant.delete', 'restaurant', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eeb-708a-bbab-3630f7ccceea', 'Create hotel', 'hotel.create', 'hotel', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eec-728b-b129-f936cc2c73bf', 'Update hotel', 'hotel.update', 'hotel', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eed-70e7-84bb-ff86035c2fc7', 'Delete hotel', 'hotel.delete', 'hotel', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eee-7341-872d-e7e457344a09', 'Create reservations', 'reservations.create', 'reservations', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eef-72ae-bd99-9954cc915ca6', 'Update reservations', 'reservations.update', 'reservations', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eef-72ae-bd99-9954ccfdc6ee', 'Delete reservations', 'reservations.delete', 'reservations', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eef-72ae-bd99-9954cd8d9c4c', 'Create the kitchen display', 'pos.kitchen.create', 'pos', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef0-718f-b6fd-0c847011d720', 'Update the kitchen display', 'pos.kitchen.update', 'pos', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef0-718f-b6fd-0c8470b8f282', 'Delete the kitchen display', 'pos.kitchen.delete', 'pos', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef1-739a-8d25-16b7621eef6a', 'Create tips', 'pos.tips.create', 'pos', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef2-7341-beff-5c86d61a17a2', 'Update tips', 'pos.tips.update', 'pos', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef2-7341-beff-5c86d66bb51f', 'Delete tips', 'pos.tips.delete', 'pos', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef3-713c-9328-573052dbb03f', 'Create CRM', 'crm.create', 'crm', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef4-72ef-b7a3-0fb6aae024ae', 'Update CRM', 'crm.update', 'crm', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef4-72ef-b7a3-0fb6ab646bae', 'Delete CRM', 'crm.delete', 'crm', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef5-715f-bca3-edf485729bb0', 'Create HR', 'hr.create', 'hr', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef5-715f-bca3-edf4862033fb', 'Update HR', 'hr.update', 'hr', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef6-7292-ac2b-a579db89dea5', 'Delete HR', 'hr.delete', 'hr', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef6-7292-ac2b-a579dbea14d7', 'Create projects', 'projects.create', 'projects', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef7-7391-8298-6b2428276277', 'Update projects', 'projects.update', 'projects', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef7-7391-8298-6b2428edc510', 'Delete projects', 'projects.delete', 'projects', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef8-73a0-840b-cb181afcc06d', 'Create documents', 'documents.create', 'documents', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef8-73a0-840b-cb181b2f1a4b', 'Update documents', 'documents.update', 'documents', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef9-730f-baa8-fa5b84e93f31', 'Delete documents', 'documents.delete', 'documents', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9ef9-730f-baa8-fa5b85495ced', 'Create fleet', 'fleet.create', 'fleet', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9efa-722e-ab88-e46ab31c9e98', 'Update fleet', 'fleet.update', 'fleet', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9efa-722e-ab88-e46ab346cf08', 'Delete fleet', 'fleet.delete', 'fleet', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9efb-7346-b10e-4bb2e04ce25b', 'Create maintenance', 'maintenance.create', 'maintenance', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9efc-72f3-b69a-174f82519aaa', 'Update maintenance', 'maintenance.update', 'maintenance', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9efd-72ec-abcf-46d9df456096', 'Delete maintenance', 'maintenance.delete', 'maintenance', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9efe-72c5-8111-2a0e498a6145', 'Create manufacturing', 'manufacturing.create', 'manufacturing', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eff-71b4-9635-a457d4bc114a', 'Update manufacturing', 'manufacturing.update', 'manufacturing', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9eff-71b4-9635-a457d531e4ee', 'Delete manufacturing', 'manufacturing.delete', 'manufacturing', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9f00-727b-9b2f-2210f1c8172e', 'Create e-commerce', 'ecommerce.create', 'ecommerce', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9f01-7316-ade0-42485bde8fdf', 'Update e-commerce', 'ecommerce.update', 'ecommerce', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9f01-7316-ade0-42485bfdc08a', 'Delete e-commerce', 'ecommerce.delete', 'ecommerce', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9f02-71d8-bd87-c061ca1b7e79', 'Create notification channels', 'notifications.create', 'notifications', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9f02-71d8-bd87-c061cacd014f', 'Update notification channels', 'notifications.update', 'notifications', '2026-10-27 09:52:34');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc6-9f03-70f2-95f5-31005966f1c6', 'Delete notification channels', 'notifications.delete', 'notifications', '2026-10-27 09:52:34');

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
CREATE TABLE "products" ("id" varchar not null, "tenant_id" varchar not null, "catalog_id" varchar not null, "category_id" varchar, "sku" varchar not null, "name" varchar not null, "description" text, "barcode" varchar, "unit" varchar not null default ('piece'), "base_price" integer not null default ('0'), "cost_price" integer not null default ('0'), "is_active" tinyint(1) not null default ('1'), "metadata" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "product_type" varchar not null default ('simple'), "brand_id" varchar, "unit_id" varchar, "tax_id" varchar, "is_serialized" tinyint(1) not null default ('0'), "track_batch" tinyint(1) not null default ('0'), "track_expiration" tinyint(1) not null default ('0'), "expiration_days" integer, "low_stock_threshold" integer, "bottle_volume_ml" integer, "inventory_class" varchar, "count_frequency" varchar, "last_counted_at" date, "next_count_at" date, "accompaniment_enabled" tinyint(1) not null default ('0'), "tax_class_id" varchar, foreign key("tax_id") references taxes("id") on delete set null on update no action, foreign key("unit_id") references units("id") on delete set null on update no action, foreign key("brand_id") references brands("id") on delete set null on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("catalog_id") references catalogs("id") on delete cascade on update no action, foreign key("category_id") references categories("id") on delete set null on update no action, foreign key("tax_class_id") references "tax_classes"("id") on delete set null, primary key ("id"));


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


DROP TABLE IF EXISTS "qr_order_items";
CREATE TABLE "qr_order_items" ("id" varchar not null, "tenant_id" varchar not null, "qr_order_id" varchar not null, "product_id" varchar, "product_variant_id" varchar, "sale_unit_id" varchar, "name" varchar not null, "quantity" integer not null, "note" text, "options" text, "unit_price" integer not null default '0', "line_subtotal" integer not null default '0', "line_tax" integer not null default '0', "line_total" integer not null default '0', "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("qr_order_id") references "qr_orders"("id") on delete cascade, foreign key("product_id") references "products"("id") on delete set null, foreign key("product_variant_id") references "product_variants"("id") on delete set null, foreign key("sale_unit_id") references "product_sale_units"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "qr_orders";
CREATE TABLE "qr_orders" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "pos_table_id" varchar not null, "session_id" varchar not null, "sale_id" varchar, "source" varchar not null default 'qr_client', "status" varchar not null default 'submitted', "guest_locale" varchar not null default 'fr', "idempotency_key" varchar not null, "rejection_reason" text, "approved_by" varchar, "approved_at" datetime, "rejected_by" varchar, "rejected_at" datetime, "kitchen_ticket_code" varchar, "subtotal" integer not null default '0', "tax_total" integer not null default '0', "total" integer not null default '0', "currency" varchar not null default 'FBU', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete cascade, foreign key("pos_table_id") references "pos_tables"("id") on delete cascade, foreign key("session_id") references "qr_table_sessions"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete set null, foreign key("approved_by") references "users"("id") on delete set null, foreign key("rejected_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "qr_table_sessions";
CREATE TABLE "qr_table_sessions" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "pos_table_id" varchar not null, "sale_id" varchar, "status" varchar not null default 'open', "opened_at" datetime not null, "closed_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete cascade, foreign key("pos_table_id") references "pos_tables"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "realtime_outbox";
CREATE TABLE "realtime_outbox" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar, "user_id" varchar, "event_name" varchar not null, "entity_type" varchar, "entity_id" varchar, "status" varchar, "payload" text not null, "occurred_at" datetime not null, "broadcast_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "role_permissions";
CREATE TABLE "role_permissions" ("role_id" varchar not null, "permission_id" varchar not null, foreign key("role_id") references "roles"("id") on delete cascade, foreign key("permission_id") references "permissions"("id") on delete cascade, primary key ("role_id", "permission_id"));

INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e2c-7135-a655-903ee806682c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e2c-7135-a655-903ee8833aaf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e2d-732a-a009-ecbc5d52116b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e2d-732a-a009-ecbc5dba66c6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e2d-732a-a009-ecbc5e6d0233');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e2e-7063-861c-b2f176134295');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e2e-7063-861c-b2f17624b2c9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e2e-7063-861c-b2f176b2b6cf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e2e-7063-861c-b2f17795992f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e2f-70bf-9265-c7242641fc16');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e2f-70bf-9265-c72426b5ed82');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e30-7244-bd1d-283d2762ba51');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e30-7244-bd1d-283d27d463ef');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e30-7244-bd1d-283d28c23c98');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e31-710c-be29-b932f10bd518');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e31-710c-be29-b932f18b68c1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e31-710c-be29-b932f2268a5b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e31-710c-be29-b932f24c8e80');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e32-7212-bf01-4af64372aef7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e32-7212-bf01-4af64419192b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e32-7212-bf01-4af64493eedb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e33-70de-ab1f-6403cb035b35');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e33-70de-ab1f-6403cb3db255');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e33-70de-ab1f-6403cc2269ca');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e34-7163-9777-8c16d571ea1c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e34-7163-9777-8c16d5cd1b02');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e34-7163-9777-8c16d64928e6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e35-71fa-9c18-5ae4c9c6d3dc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e35-71fa-9c18-5ae4c9d4054e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e35-71fa-9c18-5ae4ca552d06');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e36-70a9-8cfc-67573eeef463');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e36-70a9-8cfc-67573f43a1cf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e36-70a9-8cfc-675740346175');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e36-70a9-8cfc-675740dd5b3f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e37-71dd-bb6c-7b4ea1420613');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e37-71dd-bb6c-7b4ea16d95e3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e37-71dd-bb6c-7b4ea1d12370');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e37-71dd-bb6c-7b4ea22bdc05');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e38-70fb-b72b-25e29b00c299');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e38-70fb-b72b-25e29bc332f7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e38-70fb-b72b-25e29bf3d78d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e39-70cc-bbbd-35a76cc5d648');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e39-70cc-bbbd-35a76db0d71a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e39-70cc-bbbd-35a76dc567f0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e39-70cc-bbbd-35a76eac40af');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3a-707c-adc6-0cb87a357bda');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3a-707c-adc6-0cb87a7a0b92');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3a-707c-adc6-0cb87b3d0b57');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3b-70ad-8367-442a82d446e6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3b-70ad-8367-442a83b1b6ad');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3b-70ad-8367-442a84564885');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3b-70ad-8367-442a84e0d11c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3c-707e-b6c5-e5c4dd79021c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3c-707e-b6c5-e5c4ddbe1f93');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3c-707e-b6c5-e5c4de8a14c7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3d-7331-84a4-8488051a8b47');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3d-7331-84a4-8488057c441d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3d-7331-84a4-8488062190a7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3e-725a-9779-5b8e3d0c67e1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3e-725a-9779-5b8e3d4819e2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3e-725a-9779-5b8e3db1b769');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3f-7007-869b-6369ebe50513');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e3f-7007-869b-6369ecd8168e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e40-71ed-96d4-f3ef6297cd79');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e40-71ed-96d4-f3ef63279e90');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e40-71ed-96d4-f3ef640402be');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e41-71e4-8e78-a5f6f3b21287');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e41-71e4-8e78-a5f6f400162b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e41-71e4-8e78-a5f6f429449c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e41-71e4-8e78-a5f6f513778d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e42-710f-bfd2-ede1c20a41e5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e42-710f-bfd2-ede1c2e726e4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e42-710f-bfd2-ede1c2fe464b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e43-7224-9709-2a82610177ab');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e43-7224-9709-2a826197e462');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e43-7224-9709-2a82621dc946');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e43-7224-9709-2a82626510e0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e44-7154-a0c0-a5de048831cb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e44-7154-a0c0-a5de055995a2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e44-7154-a0c0-a5de05ed4e94');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e45-71db-8a2b-96e4ca5fd38f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e45-71db-8a2b-96e4cb1944cb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e45-71db-8a2b-96e4cb9e27f5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e46-7289-a2af-cddbeb5bfc56');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e46-7289-a2af-cddbebff85b7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e46-7289-a2af-cddbec801de2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e46-7289-a2af-cddbec981e21');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e47-7354-9ac5-be105b6075bd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e47-7354-9ac5-be105b75e0e4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e47-7354-9ac5-be105beb7c2f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e48-7253-b173-3d235680e77e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e48-7253-b173-3d23573793b9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e48-7253-b173-3d235831bf69');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e48-7253-b173-3d2358ffce9f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e49-733c-9609-3551c0b97b6d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e49-733c-9609-3551c1aaeffe');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e49-733c-9609-3551c1b91581');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4a-7344-b127-621b53f36ea0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4a-7344-b127-621b54129639');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4a-7344-b127-621b54f5ee8e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4b-73f2-86f6-4a727d05e6c6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4b-73f2-86f6-4a727da0b653');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4b-73f2-86f6-4a727da475bf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4b-73f2-86f6-4a727dce2b57');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4c-70b3-8e36-e900ff3e9930');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4c-70b3-8e36-e900fffa2306');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4c-70b3-8e36-e900fffa30be');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4d-72bf-8404-3658599c7e64');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4d-72bf-8404-36585a0b30a6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4d-72bf-8404-36585a1b6618');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4d-72bf-8404-36585a8dc3f9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4e-7192-864b-ac617cbec2c8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4e-7192-864b-ac617d3a0673');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4f-7250-8c46-ca420709d014');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4f-7250-8c46-ca4207c02e9d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e4f-7250-8c46-ca4207cc64e2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e50-7379-9243-24f1d4a90e02');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e50-7379-9243-24f1d5713e41');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e50-7379-9243-24f1d5d5a11b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e51-713a-aef0-ac1f23e927ba');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e51-713a-aef0-ac1f24d0abc2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e51-713a-aef0-ac1f2583a6cf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e52-7221-bb62-a9f09db7e378');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e52-7221-bb62-a9f09e1064d5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e52-7221-bb62-a9f09ed0343c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e52-7221-bb62-a9f09f04cfa3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e53-73b6-ae70-c3ca1377ee40');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e53-73b6-ae70-c3ca13d082b0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e53-73b6-ae70-c3ca13d14b40');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e54-70df-b690-2fcc622b294f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e54-70df-b690-2fcc6254e804');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e54-70df-b690-2fcc633437d6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e55-73dd-834c-ec48c6b237aa');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e55-73dd-834c-ec48c7798660');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e55-73dd-834c-ec48c78fe3fd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e55-73dd-834c-ec48c8078828');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e56-70e5-8266-2d2805872198');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e56-70e5-8266-2d28061735c3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e56-70e5-8266-2d28063a24fb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e57-7110-9893-2710e47699e5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e57-7110-9893-2710e4bb9615');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e57-7110-9893-2710e55f5919');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e57-7110-9893-2710e5d97077');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e58-7294-b1b2-2e3f64625b1c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e58-7294-b1b2-2e3f64eba83b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e58-7294-b1b2-2e3f65accf0b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e59-72ee-9ffe-7a3592ea8b12');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e59-72ee-9ffe-7a3593793a66');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e59-72ee-9ffe-7a3593c1784a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e59-72ee-9ffe-7a3593d44618');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5a-7008-87bd-3035950f908b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5a-7008-87bd-3035951cf130');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5a-7008-87bd-303595897be3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5b-721b-af21-f1efbdf4d9cc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5b-721b-af21-f1efbe86ff72');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5b-721b-af21-f1efbf501511');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5c-7107-9c00-adfa0d198ee7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5c-7107-9c00-adfa0dd344e0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5c-7107-9c00-adfa0e79edb6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5d-72f4-861a-130a6ddbe1cc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5d-72f4-861a-130a6e24ea76');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5d-72f4-861a-130a6ed0e8e3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5e-7398-b59a-009db9d00fd5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5e-7398-b59a-009dba8a7c26');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5e-7398-b59a-009dba944302');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5f-7021-a21f-9d06b40c739f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5f-7021-a21f-9d06b43092af');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e5f-7021-a21f-9d06b47a3256');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e60-7278-822f-c704ecbf370e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e60-7278-822f-c704ed46173a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e60-7278-822f-c704ee0f013d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e60-7278-822f-c704ef0113cb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e61-7049-ba8e-00a873626d3c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e61-7049-ba8e-00a873a66f93');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e61-7049-ba8e-00a873c841ca');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e62-731e-885b-78dbcaf4d925');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e62-731e-885b-78dbcaffa8d0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e62-731e-885b-78dbcb2460cd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e63-73b2-ad6d-e86abbb5e160');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e63-73b2-ad6d-e86abc00929e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e63-73b2-ad6d-e86abce9ecf1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e63-73b2-ad6d-e86abd9581f5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e64-70d5-8bd3-386c1419d28a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e64-70d5-8bd3-386c1512c087');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e64-70d5-8bd3-386c160e8c74');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e65-7197-bad9-5725b7028f2d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e65-7197-bad9-5725b7b74a35');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e65-7197-bad9-5725b86e666d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e66-72c6-8c4c-9caa216dbc97');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e66-72c6-8c4c-9caa21e79d1e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e66-72c6-8c4c-9caa229b0968');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e66-72c6-8c4c-9caa2312dafb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e67-7108-8772-7c1d81446584');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e67-7108-8772-7c1d822da275');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e67-7108-8772-7c1d82df9766');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e68-72cc-874a-247c1a663fe6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e68-72cc-874a-247c1ab21ee0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e68-72cc-874a-247c1b6c6292');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e68-72cc-874a-247c1b9bb498');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e69-71ce-8948-9b4c8d33e12b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e69-71ce-8948-9b4c8d6202c1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e69-71ce-8948-9b4c8e35c9cf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6a-70ab-8905-c7db22aba631');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6a-70ab-8905-c7db2317826e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6a-70ab-8905-c7db23f68220');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6a-70ab-8905-c7db24ecf8fd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6b-714e-85ac-367e31dbd5bf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6b-714e-85ac-367e3283f547');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6b-714e-85ac-367e3382ed0e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6c-70ce-b8d7-f31918c6aece');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6c-70ce-b8d7-f319197d59d5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6c-70ce-b8d7-f3191a42aa00');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6c-70ce-b8d7-f3191b343863');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6d-7211-81af-da78368a0953');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6d-7211-81af-da78375709ee');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6d-7211-81af-da7837d7f685');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6e-7023-ada0-caec0bbb482e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6e-7023-ada0-caec0c8b1866');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6f-70ee-ad39-809561749b85');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e6f-70ee-ad39-809562297f97');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e70-730e-a000-2a45798125b1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e70-730e-a000-2a457a2aa75b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e70-730e-a000-2a457ae09346');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e71-70d3-8de6-d301bc74cd39');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e71-70d3-8de6-d301bcb2d2fe');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e72-72f9-9f8f-8a1d47df25bd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e74-7174-a193-d92d33a4a7cc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e77-71a9-9fa3-404d80ad0046');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e79-7277-9591-e07a45266d07');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e7a-73ae-a0f8-672a053075af');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e7b-706a-9aa9-f342d0c4a11c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e7b-706a-9aa9-f342d0d217d5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e7c-702c-a7a4-5b5abede63b4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e7d-72ab-8ab0-01c8211b97a7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e7d-72ab-8ab0-01c8217d78ed');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e7e-7126-9336-859d50229fb2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e7f-7345-a8fa-040a445b22a3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e80-730c-a5e0-69d9da03b077');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e80-730c-a5e0-69d9daa83fba');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e81-72f0-8d51-dc90e5d1360f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e82-72e8-9109-831d580ea8a7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e82-72e8-9109-831d58fb19dd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e83-722d-b312-9ae677659573');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e83-722d-b312-9ae678305ead');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e84-70bb-ba30-13de10816001');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e85-7066-93c8-b3da1013eb01');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e86-73e3-86fd-57ad204459e9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e86-73e3-86fd-57ad20bd4fb4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e87-73a3-8304-1ca97f03111c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e88-7303-b3e3-7a9653180772');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e89-70fb-86fa-7eb3e29f8067');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e8a-7042-aa97-400025569711');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e8b-702b-a251-1f869b5f444f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e8c-7242-aa91-dacdb8e2873a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e8c-7242-aa91-dacdb9d549b3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e8d-7166-abbc-d996aff840b1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e8e-71b9-930c-42156f32581b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e8e-71b9-930c-42156f6a4869');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e8f-7104-993a-325befbbeccf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e90-7110-b317-d98f5628b810');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e90-7110-b317-d98f57004866');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e91-703e-857e-c3038a881b7d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e91-703e-857e-c3038b34d1f2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e92-7214-a448-ae45d48d6398');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e92-7214-a448-ae45d586ce68');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e93-73bf-8e91-4b733254741d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e93-73bf-8e91-4b73330318a6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e94-7130-9261-f02aaddaf550');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e94-7130-9261-f02aae174e54');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e95-7382-9af6-7facf7a34354');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e96-70b8-bd57-37beaf27bdb0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e97-70f4-8b4e-92d6aed2a318');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e97-70f4-8b4e-92d6afc11c49');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e98-71e3-a164-c36afeb1e722');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e99-723f-8d92-1d888dcfe1f0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e9a-7111-8585-065784029df8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e9a-7111-8585-065784aa1c4f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e9b-725c-aafe-360e02e60826');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e9c-71a1-9136-2cce9833409d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e9c-71a1-9136-2cce98f26c7c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e9d-7175-b709-7a2fab6eda55');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e9e-7270-bae6-a0593d0a19e9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9e9f-7104-a871-80c08287f6f5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ea0-7345-8c86-e661c7dbd6d0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ea1-71a1-88fe-6e74fac8dfcf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ea2-720e-b31b-d930e4b120c0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ea3-7310-9132-ee6b53d9b563');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ea4-730f-82c7-11fe5aff2a21');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ea5-7315-bdfa-6e19472bbff9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ea5-7315-bdfa-6e19478a25db');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ea6-72bd-a00a-f25344741af2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ea7-71de-9ac7-fa34d8691b49');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ea8-71d8-aeb2-4a22222b02de');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ea9-71ea-93a3-a9a612dacc3c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eaa-7371-8de3-d377bc1805df');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eab-73da-b91b-cee86edd2bd4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eac-7193-b49c-8b3fdff9ffa6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eac-7193-b49c-8b3fe0a033d3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ead-7114-9a32-1e76071ca8de');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eae-716c-bb91-765104ef2b8c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eaf-7275-9a1c-b7e0301eb1a2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb0-7153-a399-e96b736d3559');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb1-7396-b1c3-4be7f23bdf09');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb2-7126-a94c-8a3190b8b772');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb3-73d8-8a71-32730c05e18a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb4-71de-b4e1-26bf8921f1b0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb4-71de-b4e1-26bf89edf1bd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb5-736b-bd89-bd32406a7581');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb5-736b-bd89-bd3240d4486a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb6-7187-a1a0-b5cbf6eff7dd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb6-7187-a1a0-b5cbf7c31be8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb7-729d-bbf7-bb2e03437535');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb7-729d-bbf7-bb2e035b9b43');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb7-729d-bbf7-bb2e038539aa');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb8-7368-a70f-93910c918e37');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb8-7368-a70f-93910d2a6cf2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb9-7028-8b18-a91970c99166');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eb9-7028-8b18-a91971adb657');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eba-7107-beee-595927a69a00');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ebb-71b2-8e2b-f77e304b3b1b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ebb-71b2-8e2b-f77e312a72eb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ebc-7015-bd0a-56a174a2f508');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ebc-7015-bd0a-56a174ab9e87');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ebd-7280-9d96-a6ad980e5b79');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ebd-7280-9d96-a6ad98618ffe');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ebe-71ef-be2b-1760185d8082');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ebe-71ef-be2b-176018cfca4d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ebf-72a3-bc0d-5ab8eb0b5200');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ebf-72a3-bc0d-5ab8eb18b86c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ec0-71bd-abcb-27e79a1d78ad');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ec5-71c2-8578-3285e38e67a6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ec9-70c9-8f1f-5f9f6cbbfe22');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eca-71a4-8c52-c20aaf07ad9a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ecb-728f-baf8-9d08f02f103d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ecc-71e3-bf92-2661598139c1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ecc-71e3-bf92-26615995ed61');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ecd-709b-b778-58990d0cda9a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ece-7198-934f-a5198a0b4f48');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ecf-718c-b628-7a3c0804b60c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ecf-718c-b628-7a3c08fd1f60');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ed0-700d-bdfd-9da8da068a4c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ed1-7337-a0d4-24d7890efda4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ed1-7337-a0d4-24d78949e581');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ed2-73fb-b0cf-5dfac2b4285c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ed3-7169-9f8a-07cc6e70b06e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ed3-7169-9f8a-07cc6f3b7bf0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ed4-7129-a012-ba01d0391046');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ed5-7091-b8cf-48b1e1e4fa92');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ed5-7091-b8cf-48b1e205e6e7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ed6-72a0-90eb-44d9549bb4f2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ed7-705d-b5ec-1331d7662d79');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ed7-705d-b5ec-1331d79f1d44');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ed8-72a9-8b4d-f69d5941154b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ed9-70c5-a110-c47797e58579');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eda-7068-9488-7df090331d76');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9edb-707b-b94c-7e76b607e833');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9edb-707b-b94c-7e76b696b5fe');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9edc-7113-a470-53d403ff2170');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9edc-7113-a470-53d404028eda');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9edd-7061-8528-60580dab72fc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ede-71bf-88f3-018b1ba405ae');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ede-71bf-88f3-018b1bc19b59');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9edf-7181-9a6d-63806c365fcc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ee0-71f2-ab74-b3d4e4ffcaef');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ee1-7004-86a6-229e47cf4a80');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ee1-7004-86a6-229e484e5060');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ee2-734a-834d-d706f2aed453');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ee3-700e-a7cb-1b4f13f2fd0a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ee3-700e-a7cb-1b4f14a53132');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ee4-7379-8ea7-dd849a1ad2c3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ee5-7045-9f4b-7fa022e273d3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ee5-7045-9f4b-7fa023b43618');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ee6-722f-b5d2-0a46f6a42e68');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ee6-722f-b5d2-0a46f75c7ff6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ee7-73b2-9742-90af79d84e11');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ee8-70a4-a0d9-273f51d45ba1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ee9-70a9-b3d8-4d3420e7d58d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ee9-70a9-b3d8-4d3421c21dbb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eea-720c-a81f-d6455e2110d6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eeb-708a-bbab-3630f7ccceea');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eec-728b-b129-f936cc2c73bf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eed-70e7-84bb-ff86035c2fc7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eee-7341-872d-e7e457344a09');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eef-72ae-bd99-9954cc915ca6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eef-72ae-bd99-9954ccfdc6ee');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eef-72ae-bd99-9954cd8d9c4c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef0-718f-b6fd-0c847011d720');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef0-718f-b6fd-0c8470b8f282');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef1-739a-8d25-16b7621eef6a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef2-7341-beff-5c86d61a17a2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef2-7341-beff-5c86d66bb51f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef3-713c-9328-573052dbb03f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef4-72ef-b7a3-0fb6aae024ae');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef4-72ef-b7a3-0fb6ab646bae');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef5-715f-bca3-edf485729bb0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef5-715f-bca3-edf4862033fb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef6-7292-ac2b-a579db89dea5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef6-7292-ac2b-a579dbea14d7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef7-7391-8298-6b2428276277');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef7-7391-8298-6b2428edc510');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef8-73a0-840b-cb181afcc06d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef8-73a0-840b-cb181b2f1a4b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef9-730f-baa8-fa5b84e93f31');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9ef9-730f-baa8-fa5b85495ced');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9efa-722e-ab88-e46ab31c9e98');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9efa-722e-ab88-e46ab346cf08');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9efb-7346-b10e-4bb2e04ce25b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9efc-72f3-b69a-174f82519aaa');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9efd-72ec-abcf-46d9df456096');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9efe-72c5-8111-2a0e498a6145');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eff-71b4-9635-a457d4bc114a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9eff-71b4-9635-a457d531e4ee');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9f00-727b-9b2f-2210f1c8172e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9f01-7316-ade0-42485bde8fdf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9f01-7316-ade0-42485bfdc08a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9f02-71d8-bd87-c061ca1b7e79');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9f02-71d8-bd87-c061cacd014f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', '01a17cc6-9f03-70f2-95f5-31005966f1c6');

DROP TABLE IF EXISTS "roles";
CREATE TABLE "roles" ("id" varchar not null, "tenant_id" varchar, "name" varchar not null, "slug" varchar not null, "is_system" tinyint(1) not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));

INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc6-9f05-7006-98ea-bc2892ea090a', NULL, 'Super Admin', 'super_admin', 1, '2026-10-27 09:52:34', '2026-10-27 09:52:34');

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
CREATE TABLE "sale_payments" ("id" varchar not null, "tenant_id" varchar not null, "sale_id" varchar not null, "payment_transaction_id" varchar, "payment_method" varchar not null, "amount" integer not null, "currency" varchar not null default 'FBU', "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, "amount_in_sale_currency" integer, "exchange_rate" numeric, "sale_currency" varchar, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "sale_receipts";
CREATE TABLE "sale_receipts" ("id" varchar not null, "tenant_id" varchar not null, "sale_id" varchar not null, "receipt_number" varchar not null, "format" varchar not null default 'thermal_80', "printed_by" varchar, "device_id" varchar, "printed_at" datetime not null, "reprint_count" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete cascade, foreign key("printed_by") references "users"("id") on delete set null, foreign key("device_id") references "devices"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "sale_refunds";
CREATE TABLE "sale_refunds" ("id" varchar not null, "tenant_id" varchar not null, "sale_return_id" varchar not null, "sale_id" varchar not null, "store_id" varchar not null, "refund_number" varchar not null, "refund_method" varchar not null, "amount" integer not null, "currency" varchar not null default 'USD', "status" varchar not null default 'completed', "payment_transaction_id" varchar, "customer_transaction_id" varchar, "cash_register_id" varchar, "original_payment_transaction_id" varchar, "processed_by" varchar, "metadata" text, "completed_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("sale_return_id") references "sale_returns"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete cascade, foreign key("payment_transaction_id") references "payment_transactions"("id") on delete set null, foreign key("customer_transaction_id") references "customer_transactions"("id") on delete set null, foreign key("original_payment_transaction_id") references "payment_transactions"("id") on delete set null, foreign key("processed_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "sale_return_items";
CREATE TABLE "sale_return_items" ("id" varchar not null, "tenant_id" varchar not null, "sale_return_id" varchar not null, "sale_item_id" varchar not null, "product_id" varchar, "product_variant_id" varchar, "product_name" varchar not null, "product_sku" varchar, "quantity_returned" integer not null, "unit_price" integer not null, "tax_rate" numeric not null default '0', "line_subtotal" integer not null default '0', "line_tax" integer not null default '0', "line_total" integer not null default '0', "batch_id" varchar, "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("sale_return_id") references "sale_returns"("id") on delete cascade, foreign key("sale_item_id") references "sale_items"("id") on delete restrict, foreign key("product_id") references "products"("id") on delete restrict, foreign key("product_variant_id") references "product_variants"("id") on delete set null, foreign key("batch_id") references "batches"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "sale_returns";
CREATE TABLE "sale_returns" ("id" varchar not null, "tenant_id" varchar not null, "sale_id" varchar not null, "store_id" varchar not null, "warehouse_id" varchar not null, "customer_id" varchar, "return_number" varchar not null, "status" varchar not null default 'completed', "reason" varchar not null, "refund_method" varchar not null default 'none', "subtotal" integer not null default '0', "tax_total" integer not null default '0', "discount_total" integer not null default '0', "total" integer not null default '0', "currency" varchar not null default 'USD', "processed_by" varchar, "approved_by" varchar, "idempotency_key" varchar, "approved_at" datetime, "completed_at" datetime, "notes" text, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete restrict, foreign key("store_id") references "stores"("id") on delete restrict, foreign key("warehouse_id") references "warehouses"("id") on delete restrict, foreign key("customer_id") references "customers"("id") on delete set null, foreign key("processed_by") references "users"("id") on delete set null, foreign key("approved_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "sale_taxes";
CREATE TABLE "sale_taxes" ("id" varchar not null, "tenant_id" varchar not null, "sale_id" varchar not null, "sale_item_id" varchar, "tax_id" varchar, "tax_name" varchar, "tax_rate" numeric not null default '0', "taxable_amount" integer not null default '0', "tax_amount" integer not null default '0', "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("sale_id") references "sales"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "sales";
CREATE TABLE "sales" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "customer_id" varchar, "reference" varchar not null, "status" varchar not null default ('draft'), "total" integer not null default ('0'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "paid_amount" integer not null default ('0'), "due_date" date, "payment_status" varchar not null default ('paid'), "warehouse_id" varchar, "cash_register_id" varchar, "cashier_shift_id" varchar, "device_id" varchar, "processed_by" varchar, "subtotal" integer not null default ('0'), "tax_total" integer not null default ('0'), "discount_total" integer not null default ('0'), "fees_total" integer not null default ('0'), "currency" varchar not null default ('FBU'), "payment_transaction_number" varchar, "idempotency_key" varchar, "completed_at" datetime, "notes" text, "table_id" varchar, "merged_into_id" varchar, "order_date" date, "service_mode" varchar, "delivery_address" varchar, "source" varchar not null default 'cashier', foreign key("customer_id") references customers("id") on delete set null on update no action, foreign key("store_id") references stores("id") on delete cascade on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("table_id") references "pos_tables"("id") on delete set null, foreign key("merged_into_id") references "sales"("id") on delete set null, primary key ("id"));


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
CREATE TABLE "stores" ("id" varchar not null, "tenant_id" varchar not null, "branch_id" varchar not null, "name" varchar not null, "code" varchar not null, "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "kind" varchar not null default ('store'), "location_id" varchar, "is_main" tinyint(1) not null default '0', "qr_approval_mode" varchar not null default 'manual', foreign key("branch_id") references branches("id") on delete cascade on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("location_id") references "locations"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "supplier_contacts";
CREATE TABLE "supplier_contacts" ("id" varchar not null, "tenant_id" varchar not null, "supplier_id" varchar not null, "name" varchar not null, "title" varchar, "email" varchar, "phone" varchar, "is_primary" tinyint(1) not null default '0', "notes" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("supplier_id") references "suppliers"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "supplier_payments";
CREATE TABLE "supplier_payments" ("id" varchar not null, "tenant_id" varchar not null, "supplier_id" varchar not null, "payment_number" varchar not null, "amount" integer not null, "payment_method" varchar not null default 'bank_transfer', "reference" varchar, "notes" text, "status" varchar not null default 'completed', "paid_at" datetime not null, "recorded_by" varchar, "allocations" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("supplier_id") references "suppliers"("id") on delete cascade, foreign key("recorded_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "supplier_transactions";
CREATE TABLE "supplier_transactions" ("id" varchar not null, "tenant_id" varchar not null, "supplier_id" varchar not null, "purchase_id" varchar, "supplier_payment_id" varchar, "transaction_type" varchar not null, "reference" varchar, "amount" integer not null, "paid_amount" integer not null default '0', "due_date" date, "description" text, "recorded_by" varchar, "occurred_at" datetime not null, "created_at" datetime not null default CURRENT_TIMESTAMP, "purchase_order_id" varchar, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("supplier_id") references "suppliers"("id") on delete cascade, foreign key("purchase_id") references "purchases"("id") on delete set null, foreign key("supplier_payment_id") references "supplier_payments"("id") on delete set null, foreign key("recorded_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "suppliers";
CREATE TABLE "suppliers" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "code" varchar not null, "email" varchar, "phone" varchar, "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "legal_name" varchar, "tax_id" varchar, "address" text, "payment_terms_days" integer not null default ('30'), "credit_limit" integer, "currency_code" varchar not null default ('USD'), "notes" text, "metadata" text, "party_id" varchar, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("party_id") references "parties"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "sync_events";
CREATE TABLE "sync_events" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "device_id" varchar, "sequence" integer not null, "event_type" varchar not null, "entity_type" varchar not null, "entity_id" varchar not null, "payload" text not null, "occurred_at" datetime not null, "created_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete cascade, foreign key("device_id") references "devices"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "sync_failures";
CREATE TABLE "sync_failures" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar, "entity_type" varchar not null, "entity_id" varchar not null, "error" varchar not null, "occurred_at" datetime not null, "resolved_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "table_qr_tokens";
CREATE TABLE "table_qr_tokens" ("id" varchar not null, "tenant_id" varchar not null, "store_id" varchar not null, "pos_table_id" varchar not null, "token" varchar not null, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("store_id") references "stores"("id") on delete cascade, foreign key("pos_table_id") references "pos_tables"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "tax_classes";
CREATE TABLE "tax_classes" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "code" varchar not null, "description" text, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "tax_group_tax";
CREATE TABLE "tax_group_tax" ("id" varchar not null, "tax_group_id" varchar not null, "tax_id" varchar not null, "sort_order" integer not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tax_group_id") references "tax_groups"("id") on delete cascade, foreign key("tax_id") references "taxes"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "tax_groups";
CREATE TABLE "tax_groups" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "code" varchar not null, "description" text, "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "tax_rules";
CREATE TABLE "tax_rules" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "tax_class_id" varchar, "tax_id" varchar, "tax_group_id" varchar, "country" varchar, "region" varchar, "priority" integer not null default '1', "is_active" tinyint(1) not null default '1', "description" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("tax_class_id") references "tax_classes"("id") on delete set null, foreign key("tax_id") references "taxes"("id") on delete set null, foreign key("tax_group_id") references "tax_groups"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "taxes";
CREATE TABLE "taxes" ("id" varchar not null, "tenant_id" varchar not null, "name" varchar not null, "code" varchar not null, "rate" numeric not null default '0', "is_inclusive" tinyint(1) not null default '0', "is_active" tinyint(1) not null default '1', "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "kind" varchar not null default 'vat', "type" varchar not null default 'percentage', "priority" integer not null default '1', "country" varchar, "region" varchar, "is_compound" tinyint(1) not null default '0', "description" text, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "tenants";
CREATE TABLE "tenants" ("id" varchar not null, "name" varchar not null, "slug" varchar not null, "status" varchar not null default 'active', "settings" text, "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "legal_name" varchar, "trade_name" varchar, "logo_url" varchar, "address" text, "phone" varchar, "email" varchar, "website" varchar, "country_code" varchar not null default 'BI', "currency_code" varchar not null default 'FBU', "timezone" varchar not null default 'Africa/Bujumbura', "locale" varchar not null default 'fr', "tax_regime" varchar, "tax_id" varchar, "registration_number" varchar, "subscription" text, primary key ("id"));


DROP TABLE IF EXISTS "transactions";
CREATE TABLE "transactions" ("id" varchar not null, "reference" varchar not null, "tenant_id" varchar not null, "party_id" varchar, "branch_id" varchar, "user_id" varchar, "type" varchar not null, "date" date not null, "status" varchar not null default 'pending', "amount" integer not null default '0', "currency" varchar not null default 'FBU', "payment_status" varchar not null default 'unpaid', "source_type" varchar, "source_id" varchar, "metadata" text, "created_at" datetime, "updated_at" datetime, "idempotency_key" varchar, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("party_id") references "parties"("id") on delete set null, foreign key("branch_id") references "branches"("id") on delete set null, foreign key("user_id") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "units";
CREATE TABLE "units" ("id" varchar not null, "tenant_id" varchar not null, "code" varchar not null, "name" varchar not null, "symbol" varchar, "is_fractional" tinyint(1) not null default ('0'), "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "store_id" varchar, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("store_id") references "stores"("id") on delete cascade, primary key ("id"));


DROP TABLE IF EXISTS "user_roles";
CREATE TABLE "user_roles" ("id" varchar not null, "user_id" varchar not null, "role_id" varchar not null, "branch_id" varchar, "store_id" varchar, "created_at" datetime, "updated_at" datetime, foreign key("user_id") references "users"("id") on delete cascade, foreign key("role_id") references "roles"("id") on delete cascade, foreign key("branch_id") references "branches"("id") on delete set null, foreign key("store_id") references "stores"("id") on delete set null, primary key ("id"));

INSERT INTO "user_roles" ("id", "user_id", "role_id", "branch_id", "store_id", "created_at", "updated_at") VALUES ('01a17cc6-9f36-71c9-bcf8-c16233826d94', '01a17cc6-9f35-7387-9d27-fca48114c8eb', '01a17cc6-9f05-7006-98ea-bc2892ea090a', NULL, NULL, '2026-10-27 09:52:34', '2026-10-27 09:52:34');

DROP TABLE IF EXISTS "users";
CREATE TABLE "users" ("id" varchar not null, "name" varchar not null, "email" varchar not null, "email_verified_at" datetime, "password" varchar not null, "phone" varchar, "pin" varchar, "is_active" tinyint(1) not null default ('1'), "remember_token" varchar, "created_at" datetime, "updated_at" datetime, "tenant_id" varchar, "api_token" varchar, "two_factor_secret" text, "two_factor_confirmed_at" datetime, "two_factor_recovery_codes" text, "phone_verified_at" datetime, "party_id" varchar, foreign key("tenant_id") references tenants("id") on delete set null on update no action, foreign key("party_id") references "parties"("id") on delete set null, primary key ("id"));

INSERT INTO "users" ("id", "name", "email", "email_verified_at", "password", "phone", "pin", "is_active", "remember_token", "created_at", "updated_at", "tenant_id", "api_token", "two_factor_secret", "two_factor_confirmed_at", "two_factor_recovery_codes", "phone_verified_at", "party_id") VALUES ('01a17cc6-9f35-7387-9d27-fca48114c8eb', 'Platform Backup', 'platform-backup@test.local', NULL, '$2y$04$JBX62ebcqX9/Mtfkk3Kh/Or0Ebz2Et70I7i.w8uQzSQc.MSAFc34i', NULL, NULL, 1, NULL, '2026-10-27 09:52:34', '2026-10-27 09:52:34', NULL, NULL, NULL, NULL, NULL, NULL, NULL);

DROP TABLE IF EXISTS "warehouses";
CREATE TABLE "warehouses" ("id" varchar not null, "tenant_id" varchar not null, "branch_id" varchar not null, "name" varchar not null, "code" varchar not null, "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "location_id" varchar, foreign key("branch_id") references branches("id") on delete cascade on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("location_id") references "locations"("id") on delete set null, primary key ("id"));


COMMIT;
PRAGMA foreign_keys=ON;
