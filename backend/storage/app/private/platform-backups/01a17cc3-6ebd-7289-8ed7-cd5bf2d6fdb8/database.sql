-- ITARA-POS logical database backup
-- driver: sqlite
-- created: 2026-10-27T09:49:05+00:00

PRAGMA foreign_keys=OFF;
BEGIN;

DROP TABLE IF EXISTS "accounting_entries";
CREATE TABLE "accounting_entries" ("id" varchar not null, "tenant_id" varchar not null, "entry_type" varchar not null, "reference_type" varchar, "reference_id" varchar, "debit" integer not null default '0', "credit" integer not null default '0', "account_code" varchar not null, "description" text, "recorded_by" varchar, "occurred_at" datetime, "created_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("recorded_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "audit_logs";
CREATE TABLE "audit_logs" ("id" varchar not null, "tenant_id" varchar not null, "user_id" varchar, "action" varchar not null, "entity_type" varchar not null, "entity_id" varchar, "payload" text, "ip_address" varchar, "created_at" datetime not null default CURRENT_TIMESTAMP, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("user_id") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "auth_tokens";
CREATE TABLE "auth_tokens" ("id" varchar not null, "user_id" varchar not null, "device_name" varchar, "access_token_hash" varchar not null, "refresh_token_hash" varchar not null, "ip_address" varchar, "user_agent" text, "last_used_at" datetime, "access_expires_at" datetime not null, "refresh_expires_at" datetime not null, "revoked_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("user_id") references "users"("id") on delete cascade, primary key ("id"));

INSERT INTO "auth_tokens" ("id", "user_id", "device_name", "access_token_hash", "refresh_token_hash", "ip_address", "user_agent", "last_used_at", "access_expires_at", "refresh_expires_at", "revoked_at", "created_at", "updated_at") VALUES ('01a17cc3-6eb3-72a6-b813-b21a4491470f', '01a17cc3-6eb1-72e3-9f7b-b2a94f1e3d8b', NULL, '27bfde432f96f82805fd583de90732528a67cf85f41c5c7b30f834529a0cfb08', '90c7f643d57b3c75408a26eeb78b09244977a4dc9c815413ab7c9eac4558003c', NULL, NULL, '2026-10-27 09:49:05', '2026-10-27 10:49:05', '2026-11-26 09:49:05', NULL, '2026-10-27 09:49:05', '2026-10-27 09:49:05');

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

INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e1d-7033-9ace-c7d9bf3aac13', 'View dashboard', 'dashboard.view', 'dashboard', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e1d-7033-9ace-c7d9bf6e7751', 'View companies', 'organization.companies.view', 'organization', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e1e-73b2-8707-bc0d8f0b7332', 'Manage companies', 'organization.companies.manage', 'organization', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e1e-73b2-8707-bc0d8fe66817', 'View branches', 'organization.branches.view', 'organization', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e1e-73b2-8707-bc0d9015eb47', 'Manage branches', 'organization.branches.manage', 'organization', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e1e-73b2-8707-bc0d90a05ac7', 'View stores', 'organization.stores.view', 'organization', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e1f-71ef-a04e-0c8d7d7a50ee', 'Manage stores', 'organization.stores.manage', 'organization', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e1f-71ef-a04e-0c8d7dca236b', 'View warehouses', 'organization.warehouses.view', 'organization', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e1f-71ef-a04e-0c8d7e31241d', 'Manage warehouses', 'organization.warehouses.manage', 'organization', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e1f-71ef-a04e-0c8d7f2b621f', 'View devices', 'organization.devices.view', 'organization', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e20-720c-aa98-e8289d0d635a', 'Manage devices', 'organization.devices.manage', 'organization', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e20-720c-aa98-e8289da34120', 'View currencies', 'organization.currencies.view', 'organization', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e20-720c-aa98-e8289e4696c2', 'Manage currencies', 'organization.currencies.manage', 'organization', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e20-720c-aa98-e8289eedd644', 'View payment methods', 'organization.payment_methods.view', 'organization', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e21-70d8-ab1e-7da9b65b4252', 'Manage payment methods', 'organization.payment_methods.manage', 'organization', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e21-70d8-ab1e-7da9b6f39027', 'View catalogs', 'catalog.catalogs.view', 'catalog', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e21-70d8-ab1e-7da9b78cc3a9', 'Manage catalogs', 'catalog.catalogs.manage', 'catalog', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e21-70d8-ab1e-7da9b7fa98d5', 'View categories', 'catalog.categories.view', 'catalog', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e22-7144-a543-74fc284c6884', 'Manage categories', 'catalog.categories.manage', 'catalog', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e22-7144-a543-74fc28c8bf04', 'View products', 'catalog.products.view', 'catalog', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e22-7144-a543-74fc2969f588', 'Manage products', 'catalog.products.manage', 'catalog', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e22-7144-a543-74fc2a2d8e50', 'View barcodes', 'catalog.barcodes.view', 'catalog', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e23-70d9-b94a-35b1397ada7f', 'Manage barcodes', 'catalog.barcodes.manage', 'catalog', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e23-70d9-b94a-35b13a5edb71', 'View sales', 'sales.view', 'sales', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e23-70d9-b94a-35b13b336cd4', 'Create sales', 'sales.create', 'sales', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e23-70d9-b94a-35b13be411b9', 'Create sale', 'sale.create', 'sales', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e24-70ed-9673-2e7f43671e71', 'Create payment', 'payments.create', 'sales', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e24-70ed-9673-2e7f4465a3f4', 'Create payment', 'payment.create', 'sales', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e25-7040-9adb-74c67b6c7df6', 'Print receipt', 'receipts.print', 'sales', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e25-7040-9adb-74c67c2ad069', 'Print receipt', 'receipt.print', 'sales', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e26-727a-8f51-01aee9f1613f', 'Void sales', 'sales.void', 'sales', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e26-727a-8f51-01aeea348af4', 'Refund sales', 'sales.refund', 'sales', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e27-7217-9719-e9479caaf445', 'Refund sale', 'sale.refund', 'sales', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e27-7217-9719-e9479d4ab057', 'Process sale returns', 'sales.return', 'sales', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e27-7217-9719-e9479d8958ed', 'Merge pending sales', 'sales.merge', 'sales', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e28-7373-8bad-e35241e7af05', 'Apply discounts', 'sales.discount.apply', 'sales', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e28-7373-8bad-e35242941f6a', 'View promotions', 'promotions.view', 'promotions', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e28-7373-8bad-e35242ddb02e', 'Manage promotions', 'promotions.manage', 'promotions', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e28-7373-8bad-e352430e6e26', 'View cash registers', 'registers.view', 'registers', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e29-7379-ac4e-60dd84e23cc6', 'Manage cash registers', 'registers.manage', 'registers', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e29-7379-ac4e-60dd85ccb7c5', 'Open register session', 'registers.session.open', 'registers', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e29-7379-ac4e-60dd8687c4ab', 'Close register session', 'registers.session.close', 'registers', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2a-7367-b9a7-0ff06fd21806', 'Record cash movements', 'registers.movement.record', 'registers', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2a-7367-b9a7-0ff07062f259', 'View cashier shifts', 'shifts.view', 'shifts', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2a-7367-b9a7-0ff07094bb93', 'Manage cashier shifts', 'shifts.manage', 'shifts', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2a-7367-b9a7-0ff070f54e20', 'Open cashier shift', 'shifts.open', 'shifts', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2a-7367-b9a7-0ff0712acb1c', 'Close cashier shift', 'shifts.close', 'shifts', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2b-7347-baae-20004a8f7f12', 'Record shift cash movements', 'shifts.movement.record', 'shifts', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2b-7347-baae-20004a9bf06c', 'View POS tables', 'pos.tables.view', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2b-7347-baae-20004afcc321', 'Manage POS tables', 'pos.tables.manage', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2b-7347-baae-20004b9e4ea3', 'Open table orders', 'pos.tables.open', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2c-7221-b65b-202933ddc91c', 'Transfer table orders', 'pos.tables.transfer', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2c-7221-b65b-202934bbbe15', 'Merge table orders', 'pos.tables.merge', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2c-7221-b65b-20293555a6a8', 'Reserve POS tables', 'pos.tables.reserve', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2c-7221-b65b-202935bb93b8', 'View POS table statistics', 'pos.tables.stats', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2d-736e-a41c-a018de2bfe38', 'View inventory', 'inventory.view', 'inventory', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2d-736e-a41c-a018de6ec89b', 'Manage inventory', 'inventory.manage', 'inventory', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2d-736e-a41c-a018defef9fb', 'Adjust stock', 'inventory.adjust', 'inventory', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2d-736e-a41c-a018df87feeb', 'Adjust stock', 'stock.adjust', 'inventory', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2e-725d-a6e6-8e6233c041f0', 'Transfer stock', 'inventory.transfer', 'inventory', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2e-725d-a6e6-8e6234023c88', 'Create inventory count', 'inventory.count.create', 'inventory', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2e-725d-a6e6-8e62340afc71', 'Enter inventory count quantities', 'inventory.count.enter', 'inventory', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2e-725d-a6e6-8e623458a507', 'Review inventory count', 'inventory.count.review', 'inventory', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2f-722b-aa7b-3e9b9724c7c2', 'Approve inventory count and post adjustments', 'inventory.count.approve', 'inventory', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2f-722b-aa7b-3e9b97645572', 'Configure cycle count rules', 'inventory.cycle.configure', 'inventory', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2f-722b-aa7b-3e9b97c0a4de', 'View expenses', 'expenses.view', 'expenses', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e2f-722b-aa7b-3e9b9897bbe1', 'Manage expenses', 'expenses.manage', 'expenses', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e30-71a7-80cd-0770328f4f32', 'Create expense', 'expenses.create', 'expenses', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e30-71a7-80cd-077032ab5f71', 'Submit expense', 'expenses.submit', 'expenses', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e30-71a7-80cd-077032cfd336', 'Approve expense', 'expenses.approve', 'expenses', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e30-71a7-80cd-07703397c7a6', 'Pay expense', 'expenses.pay', 'expenses', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e31-7272-9187-2afb8dcbad7f', 'Cancel expense', 'expenses.cancel', 'expenses', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e31-7272-9187-2afb8ea39749', 'Manage expense categories', 'expenses.categories', 'expenses', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e31-7272-9187-2afb8ec694a9', 'Manage recurring expenses', 'expenses.recurring', 'expenses', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e31-7272-9187-2afb8f8a08da', 'View expense reports', 'expenses.reports', 'expenses', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e31-7272-9187-2afb9051cd35', 'Export expense reports', 'expenses.export', 'expenses', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e32-73d8-bbd2-cff19e59f04b', 'Manage expense budgets', 'expenses.budgets', 'expenses', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e32-73d8-bbd2-cff19f0019b8', 'View purchases', 'purchases.view', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e32-73d8-bbd2-cff19f3222ac', 'Manage purchases', 'purchases.manage', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e33-7240-a808-cf1bde70867f', 'Receive goods', 'purchases.receive', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e33-7240-a808-cf1bded0cdac', 'Create requisition', 'purchases.requisition.create', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e33-7240-a808-cf1bdf728b67', 'Approve requisition', 'purchases.requisition.approve', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e33-7240-a808-cf1bdf75e6cf', 'Create proforma', 'purchases.proforma.create', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e34-716b-924b-3a48aa64df1e', 'Approve proforma', 'purchases.proforma.approve', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e34-716b-924b-3a48ab4c4bb4', 'Create purchase order', 'purchases.order.create', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e34-716b-924b-3a48abf0fb17', 'Approve purchase order', 'purchases.order.approve', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e34-716b-924b-3a48ac421e84', 'Create supplier invoice', 'purchases.invoice.create', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e35-72f2-afc0-c85c65db5cce', 'Approve supplier invoice', 'purchases.invoice.approve', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e35-72f2-afc0-c85c66dafc0d', 'Make supplier payment', 'purchases.payment.create', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e35-72f2-afc0-c85c6758c8ef', 'Approve supplier payment', 'purchases.payment.approve', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e36-7350-8e00-eda9252c2e05', 'Create purchase return', 'purchases.return.create', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e36-7350-8e00-eda92594addf', 'Approve purchase return', 'purchases.return.approve', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e36-7350-8e00-eda92664f2f0', 'Export purchase reports', 'purchases.export', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e37-7182-aa6b-7a6eb3a7c890', 'Delete purchase documents', 'purchases.delete', 'purchases', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e37-7182-aa6b-7a6eb3e9480f', 'View customers', 'customers.view', 'customers', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e37-7182-aa6b-7a6eb44bee91', 'Manage customers', 'customers.manage', 'customers', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e37-7182-aa6b-7a6eb5469e89', 'View suppliers', 'suppliers.view', 'suppliers', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e38-7367-8345-6ecb45b2fa7d', 'Manage suppliers', 'suppliers.manage', 'suppliers', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e38-7367-8345-6ecb4624ffd2', 'View users', 'users.view', 'admin', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e38-7367-8345-6ecb4675e586', 'Manage users', 'users.manage', 'admin', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e38-7367-8345-6ecb46ed852f', 'View roles', 'roles.view', 'admin', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e39-7136-b3e4-e762f640c5e1', 'Manage roles', 'roles.manage', 'admin', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e39-7136-b3e4-e762f66345cb', 'View reports', 'reports.view', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e39-7136-b3e4-e762f685cb93', 'Export reports', 'reports.export', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e39-7136-b3e4-e762f6d3c80d', 'View accounting', 'accounting.view', 'accounting', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3a-722a-8007-8a2949439587', 'Manage accounting', 'accounting.manage', 'accounting', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3a-722a-8007-8a2949839f3b', 'View transactions', 'transactions.view', 'transactions', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3a-722a-8007-8a294a0a53b1', 'Manage transactions', 'transactions.manage', 'transactions', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3a-722a-8007-8a294a70a5e8', 'View audit logs', 'audit.view', 'audit', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3b-70fe-a772-4c426428a5db', 'View settings', 'settings.view', 'settings', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3b-70fe-a772-4c4264a4af63', 'Manage settings', 'settings.manage', 'settings', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3b-70fe-a772-4c4265513d7a', 'View restaurant', 'restaurant.view', 'restaurant', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3b-70fe-a772-4c42662bc73d', 'Manage restaurant', 'restaurant.manage', 'restaurant', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3c-7176-820c-2c71f698ee6a', 'View hotel', 'hotel.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3c-7176-820c-2c71f701c196', 'Manage hotel', 'hotel.manage', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3c-7176-820c-2c71f7e4fcf7', 'View hotel dashboard', 'hotel.dashboard.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3c-7176-820c-2c71f845a6f4', 'View front desk', 'hotel.front_desk.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3d-707b-a615-d3ca480fca8f', 'Check in at the front desk', 'hotel.front_desk.check_in', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3d-707b-a615-d3ca48e03841', 'View room configuration', 'hotel.referential.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3d-707b-a615-d3ca49864cdf', 'Create room configuration', 'hotel.referential.create', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3d-707b-a615-d3ca4a09fa4a', 'Update room configuration', 'hotel.referential.update', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3e-707e-aa82-9b9af60ce314', 'Delete room configuration', 'hotel.referential.delete', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3e-707e-aa82-9b9af6a33a3d', 'View amenities', 'hotel.amenities.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3e-707e-aa82-9b9af743af56', 'Create amenities', 'hotel.amenities.create', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3e-707e-aa82-9b9af8353444', 'Update amenities', 'hotel.amenities.update', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3f-7050-b7aa-4990c059a84f', 'Delete amenities', 'hotel.amenities.delete', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3f-7050-b7aa-4990c11b642a', 'View room types', 'hotel.room_types.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3f-7050-b7aa-4990c166b104', 'Create room types', 'hotel.room_types.create', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e3f-7050-b7aa-4990c1827ddd', 'Update room types', 'hotel.room_types.update', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e40-716d-bfd0-2d7f583ce2ad', 'Delete room types', 'hotel.room_types.delete', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e40-716d-bfd0-2d7f58835fd2', 'View buildings', 'hotel.buildings.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e40-716d-bfd0-2d7f59634eb5', 'Create buildings', 'hotel.buildings.create', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e40-716d-bfd0-2d7f5a28cfa2', 'Update buildings', 'hotel.buildings.update', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e41-7068-ae45-b47257798155', 'Delete buildings', 'hotel.buildings.delete', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e41-7068-ae45-b472581fc2b0', 'View wings', 'hotel.wings.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e41-7068-ae45-b472584d7eaf', 'Create wings', 'hotel.wings.create', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e41-7068-ae45-b47258bc69d5', 'Update wings', 'hotel.wings.update', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e42-71fb-becb-da7ab622eb23', 'Delete wings', 'hotel.wings.delete', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e42-71fb-becb-da7ab6e88126', 'View floors', 'hotel.floors.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e42-71fb-becb-da7ab7679a80', 'Create floors', 'hotel.floors.create', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e42-71fb-becb-da7ab85308bc', 'Update floors', 'hotel.floors.update', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e43-71ab-8866-50fa9264eb9e', 'Delete floors', 'hotel.floors.delete', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e43-71ab-8866-50fa92f0f207', 'View rooms', 'hotel.rooms.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e43-71ab-8866-50fa92fa0ed4', 'Create rooms', 'hotel.rooms.create', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e44-7361-9324-54f4cde7c888', 'Update rooms', 'hotel.rooms.update', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e44-7361-9324-54f4ce32d163', 'Delete rooms', 'hotel.rooms.delete', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e44-7361-9324-54f4ce937c76', 'Update room status', 'hotel.rooms.update_status', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e45-707d-881e-3c12ce0dd087', 'View hotel reservations', 'hotel.reservations.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e46-73b6-9dad-d47436a1f6b9', 'Create hotel reservations', 'hotel.reservations.create', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e46-73b6-9dad-d47436aa179f', 'Update hotel reservations', 'hotel.reservations.update', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e46-73b6-9dad-d47436dad8a8', 'Confirm hotel reservations', 'hotel.reservations.confirm', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e47-7060-9612-d2116f361772', 'Cancel hotel reservations', 'hotel.reservations.cancel', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e47-7060-9612-d21170214451', 'Mark reservation no-show', 'hotel.reservations.no_show', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e47-7060-9612-d21170c41574', 'Collect reservation deposit', 'hotel.reservations.collect_deposit', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e48-7046-8365-2efed4a9fc3d', 'Export hotel reservations', 'hotel.reservations.export', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e48-7046-8365-2efed5338fc1', 'Notify reservation guests', 'hotel.reservations.notify', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e48-7046-8365-2efed603d619', 'View stays', 'hotel.stays.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e48-7046-8365-2efed69baf39', 'Check in a stay', 'hotel.stays.check_in', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e49-7273-880f-b66b275722ba', 'Record a stay arrival', 'hotel.stays.arrival', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e49-7273-880f-b66b2765c3fb', 'Change stay room', 'hotel.stays.change_room', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e49-7273-880f-b66b284733ca', 'Add a stay charge', 'hotel.stays.add_charge', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e49-7273-880f-b66b2883f626', 'Take a stay payment', 'hotel.stays.pay', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4a-7394-9ff2-f09a14be00af', 'Collect stay deposit', 'hotel.stays.collect_deposit', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4a-7394-9ff2-f09a159a2fbd', 'Refund stay deposit', 'hotel.stays.refund_deposit', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4a-7394-9ff2-f09a164ece40', 'Check out a stay', 'hotel.stays.check_out', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4a-7394-9ff2-f09a169e5889', 'Sign a stay', 'hotel.stays.sign', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4b-7207-8efc-3cb402453216', 'Export stays', 'hotel.stays.export', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4b-7207-8efc-3cb4024577fa', 'View guest invoices', 'hotel.invoices.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4b-7207-8efc-3cb4025edccd', 'Export guest invoices', 'hotel.invoices.export', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4b-7207-8efc-3cb402dc9b89', 'Print guest invoices', 'hotel.invoices.print', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4c-718e-aebc-681b42dbbf39', 'View hotel guests', 'hotel.guests.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4c-718e-aebc-681b4332008b', 'Create hotel guests', 'hotel.guests.create', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4c-718e-aebc-681b43c319d9', 'Update hotel guests', 'hotel.guests.update', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4d-70b3-a6db-146913b6fdba', 'Sign a guest record', 'hotel.guests.sign', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4d-70b3-a6db-14691488bad7', 'Export hotel guests', 'hotel.guests.export', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4d-70b3-a6db-146914da8bb2', 'View housekeeping', 'hotel.housekeeping.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4d-70b3-a6db-1469150d520a', 'Update room condition', 'hotel.housekeeping.update_condition', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4e-73c2-99be-835b216390a0', 'Create housekeeping task', 'hotel.housekeeping.create_task', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4e-73c2-99be-835b21becfba', 'Update housekeeping task', 'hotel.housekeeping.update_task', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4e-73c2-99be-835b21e51788', 'View hotel calendar', 'hotel.calendar.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4e-73c2-99be-835b22d48f5c', 'Create calendar events', 'hotel.calendar.create', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4f-730e-a839-b8f586347b75', 'Update calendar events', 'hotel.calendar.update', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4f-730e-a839-b8f5863ff793', 'Delete calendar events', 'hotel.calendar.delete', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4f-730e-a839-b8f586f5a13e', 'View concierge', 'hotel.concierge.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4f-730e-a839-b8f587003dfe', 'Create concierge requests', 'hotel.concierge.create', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e4f-730e-a839-b8f587d2f309', 'Update concierge status', 'hotel.concierge.update_status', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e50-7006-b506-3764f7f8523c', 'Assign concierge requests', 'hotel.concierge.assign', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e50-7006-b506-3764f89ecafc', 'View hotel reviews', 'hotel.reviews.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e50-7006-b506-3764f97651c1', 'Respond to hotel reviews', 'hotel.reviews.respond', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e51-7335-b2c6-aa1195d0b0d2', 'Update review status', 'hotel.reviews.update_status', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e51-7335-b2c6-aa1195d30aad', 'Export hotel reviews', 'hotel.reviews.export', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e51-7335-b2c6-aa119673b844', 'View hotel reports', 'hotel.reports.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e51-7335-b2c6-aa1196a456cc', 'Export hotel reports', 'hotel.reports.export', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e52-73dd-b89b-8d3d9ec19885', 'View hotel configuration', 'hotel.config.view', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e52-73dd-b89b-8d3d9f0af82b', 'Update hotel configuration', 'hotel.config.update', 'hotel', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e52-73dd-b89b-8d3d9f1521de', 'View analytics', 'analytics.view', 'dashboard', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e52-73dd-b89b-8d3d9f23606a', 'View condensed reports', 'reports.condensed.view', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e53-7004-8efc-25f9a7e136aa', 'Export condensed reports', 'reports.condensed.export', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e53-7004-8efc-25f9a7e781bc', 'View daily reports', 'reports.daily.view', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e53-7004-8efc-25f9a7eb21db', 'Export daily reports', 'reports.daily.export', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e53-7004-8efc-25f9a7fc1aed', 'View financial reports', 'reports.financial.view', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e54-701a-8f91-3872375b6972', 'Export financial reports', 'reports.financial.export', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e54-701a-8f91-387237c01dc0', 'View forecasting reports', 'reports.forecasting.view', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e54-701a-8f91-38723802e363', 'Export forecasting reports', 'reports.forecasting.export', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e54-701a-8f91-3872388a8e48', 'View inventory reports', 'reports.inventory_reports.view', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e55-7136-ac6d-b335d35439f4', 'Export inventory reports', 'reports.inventory_reports.export', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e56-7339-b141-af788b0e0bda', 'View performance reports', 'reports.performance.view', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e56-7339-b141-af788bf312f6', 'Export performance reports', 'reports.performance.export', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e57-7382-9029-268815b75ab8', 'View sales reports', 'reports.sales_reports.view', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e57-7382-9029-26881655f6de', 'Export sales reports', 'reports.sales_reports.export', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e58-710e-a7bd-c4b0ae70684b', 'Export revenue reports', 'reports.revenue.export', 'reports', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e58-710e-a7bd-c4b0ae8a4312', 'Approve devices', 'organization.devices.approve', 'organization', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e58-710e-a7bd-c4b0aec3dafc', 'Block devices', 'organization.devices.block', 'organization', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e59-7280-ac41-cea3bd1b6fe7', 'View sync', 'sync.view', 'sync', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e59-7280-ac41-cea3bd5f2f70', 'Configure sync', 'sync.configure', 'sync', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e59-7280-ac41-cea3bd767dce', 'Force sync', 'sync.force', 'sync', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e59-7280-ac41-cea3be4d033d', 'View reservations', 'reservations.view', 'reservations', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5a-7057-9e6e-46c6948279a7', 'Manage reservations', 'reservations.manage', 'reservations', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5a-7057-9e6e-46c6954a467d', 'Access the point of sale', 'pos.access', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5a-7057-9e6e-46c69636230e', 'Work as cashier', 'pos.cashier', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5a-7057-9e6e-46c696fa19cf', 'Choose session stores', 'pos.session.choose_stores', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5b-722b-832b-535e422fa9dc', 'Open a session for others', 'pos.session.open_for_others', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5b-722b-832b-535e42ba2a21', 'Print session report', 'pos.session.print_report', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5b-722b-832b-535e433622af', 'Require a cashier session', 'pos.session.required', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5b-722b-832b-535e4362f7fa', 'Edit POS orders', 'pos.orders.edit', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5c-71bb-9938-96e54b1d85a6', 'Delete POS orders', 'pos.orders.delete', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5c-71bb-9938-96e54b779c23', 'Update POS orders', 'pos.orders.update', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5c-71bb-9938-96e54c309244', 'Override order tax', 'pos.orders.tax_override', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5c-71bb-9938-96e54d2a2c52', 'Override order price', 'pos.orders.override_price', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5d-703b-9446-678fb8fc8d56', 'Create delivery orders', 'pos.orders.delivery', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5d-703b-9446-678fb8ff6f54', 'Create dine-in orders', 'pos.orders.dine_in', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5d-703b-9446-678fb9c474f2', 'Create takeaway orders', 'pos.orders.takeaway', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5d-703b-9446-678fb9ef499b', 'Send order to kitchen', 'pos.orders.send_kitchen', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5e-7325-ba11-08f4e5ae8602', 'Void an order item', 'pos.orders.void_item', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5e-7325-ba11-08f4e6873a96', 'Refund an order item', 'pos.orders.refund_item', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5e-7325-ba11-08f4e70d2b41', 'Set the order date', 'pos.orders.set_date', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5e-7325-ba11-08f4e732cbbc', 'Print order invoice', 'pos.orders.print_invoice', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5f-708e-90af-f1434487a846', 'Print kitchen ticket', 'pos.orders.print_kitchen', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5f-708e-90af-f1434560e477', 'Print order summary', 'pos.orders.print_summary', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5f-708e-90af-f14345c0da9e', 'Reprint invoice', 'pos.orders.reprint_invoice', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e5f-708e-90af-f14346b04803', 'Reprint kitchen ticket', 'pos.orders.reprint_kitchen', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e60-7195-bac6-9b9966b41049', 'Reprint order summary', 'pos.orders.reprint_summary', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e60-7195-bac6-9b99671d0724', 'Reprint receipt', 'pos.orders.reprint_receipt', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e60-7195-bac6-9b99678b09b0', 'Hold an order directly', 'pos.orders.hold_direct', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e60-7195-bac6-9b99680d55b8', 'Add to cart', 'pos.cart.add', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e61-71e8-b85b-66900fa30845', 'Modify the cart', 'pos.cart.modify', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e61-71e8-b85b-66900fbdb4d0', 'Remove from cart', 'pos.cart.remove', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e61-71e8-b85b-669010bab420', 'Clear the cart', 'pos.cart.clear', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e62-7303-84bd-adb15a7e9562', 'Hold an order', 'pos.cart.hold', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e62-7303-84bd-adb15a9894bf', 'Assign a server', 'pos.cart.assign_server', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e62-7303-84bd-adb15b34ba98', 'View POS payments', 'pos.payments.view', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e62-7303-84bd-adb15bec07d8', 'Refund a POS payment', 'pos.payments.refund', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e63-702b-a1bb-ca8980386486', 'Take a mixed payment', 'pos.payments.mixed', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e63-702b-a1bb-ca89804487a4', 'Take a cash payment', 'pos.payments.cash', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e63-702b-a1bb-ca8980634366', 'Take a card payment', 'pos.payments.card', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e63-702b-a1bb-ca89811c2697', 'Take a mobile payment', 'pos.payments.mobile', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e64-700f-bf1c-ed2057ae6d54', 'Take a check payment', 'pos.payments.check', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e64-700f-bf1c-ed2057f4b3a5', 'Take a wallet payment', 'pos.payments.wallet', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e64-700f-bf1c-ed20583915e0', 'Take a bank transfer', 'pos.payments.bank_transfer', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e65-71cc-891a-4d67665fc14c', 'Pay and close the order', 'pos.payments.close', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e65-71cc-891a-4d6766ddda65', 'Pay on credit', 'pos.payments.credit', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e66-7376-b959-697a8eb8f7b1', 'Require a customer for credit', 'pos.payments.credit_customer', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e66-7376-b959-697a8f9fb43a', 'Take a single payment', 'pos.payments.unique', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e68-704f-969c-a5849bf9ff3b', 'View the kitchen display', 'pos.kitchen.view', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e69-71df-924e-8395238d4a7b', 'Manage the kitchen display', 'pos.kitchen.manage', 'pos', '2026-10-27 09:49:04');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e69-71df-924e-839524564685', 'View other shift details', 'pos.shifts.details', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6a-700d-86a7-dcec3fe376ba', 'View all shifts', 'pos.shifts.view_all', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6a-700d-86a7-dcec40a7b806', 'Override a discount', 'pos.discounts.override', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6b-704b-aa87-21e6a533e048', 'View tips', 'pos.tips.view', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6b-704b-aa87-21e6a56b590d', 'Manage tips', 'pos.tips.manage', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6b-704b-aa87-21e6a5bab077', 'Apply a promotion', 'pos.promotions.apply', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6c-7109-91b2-fedfe66eb4a4', 'Apply a coupon', 'pos.promotions.coupon', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6c-7109-91b2-fedfe76dc01f', 'Apply a house offer', 'pos.offers.house', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6c-7109-91b2-fedfe7ddb7ca', 'Require a customer for house offers', 'pos.offers.require_customer', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6c-7109-91b2-fedfe81a07df', 'Access POS sync', 'pos.sync.access', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6d-721e-a525-9c2f61ba3e9d', 'Close the store from POS', 'pos.sync.close_store', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6d-721e-a525-9c2f622305bd', 'Run a full sync', 'pos.sync.full', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6d-721e-a525-9c2f631992e9', 'Upload POS data', 'pos.sync.upload', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6e-7253-95d3-4ce384c2c780', 'View the last sync date', 'pos.sync.last_date', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6e-7253-95d3-4ce384f2409c', 'Attach a customer to the sale', 'pos.customers.attach', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6e-7253-95d3-4ce38553f556', 'Search POS customers', 'pos.customers.search', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6e-7253-95d3-4ce385e211b4', 'Print an invoice', 'pos.print.invoice', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6f-7029-a374-0036e7175aab', 'Print a stub', 'pos.print.stub', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6f-7029-a374-0036e80dc5c8', 'Print a kitchen ticket', 'pos.print.kitchen', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6f-7029-a374-0036e8a4f021', 'Print the receipt and the kitchen ticket only once', 'pos.print.once', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e6f-7029-a374-0036e9108b0b', 'View CRM', 'crm.view', 'crm', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e70-72f0-91bd-229761af8984', 'Manage CRM', 'crm.manage', 'crm', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e70-72f0-91bd-229761bef131', 'View HR', 'hr.view', 'hr', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e70-72f0-91bd-2297625de1f2', 'Manage HR', 'hr.manage', 'hr', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e71-71fa-8fdd-fd8c6a8ead72', 'View projects', 'projects.view', 'projects', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e71-71fa-8fdd-fd8c6aaf394a', 'Manage projects', 'projects.manage', 'projects', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e71-71fa-8fdd-fd8c6b367508', 'View documents', 'documents.view', 'documents', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e71-71fa-8fdd-fd8c6bcef9e2', 'Manage documents', 'documents.manage', 'documents', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e72-711e-af92-5baee23a0131', 'View fleet', 'fleet.view', 'fleet', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e72-711e-af92-5baee2651018', 'Manage fleet', 'fleet.manage', 'fleet', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e72-711e-af92-5baee3641397', 'View maintenance', 'maintenance.view', 'maintenance', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e72-711e-af92-5baee36e1ad0', 'Manage maintenance', 'maintenance.manage', 'maintenance', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e73-7166-9ee3-8cd05ee441da', 'View manufacturing', 'manufacturing.view', 'manufacturing', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e73-7166-9ee3-8cd05f2293cd', 'Manage manufacturing', 'manufacturing.manage', 'manufacturing', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e73-7166-9ee3-8cd05fba33c1', 'View e-commerce', 'ecommerce.view', 'ecommerce', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e74-739f-b341-cc46513e554e', 'Manage e-commerce', 'ecommerce.manage', 'ecommerce', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e74-739f-b341-cc465221b2f4', 'View the notification center', 'notifications.view', 'notifications', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e75-7250-ac52-c8f3da3a3957', 'Manage notification channels', 'notifications.manage', 'notifications', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e75-7250-ac52-c8f3daf2a92d', 'Create companies', 'organization.companies.create', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e75-7250-ac52-c8f3daf9ad3a', 'Update companies', 'organization.companies.update', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e76-726b-b994-3f7b29aea6e9', 'Delete companies', 'organization.companies.delete', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e76-726b-b994-3f7b29cd3ef7', 'Create branches', 'organization.branches.create', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e77-72ae-babc-129e4cb67b3b', 'Update branches', 'organization.branches.update', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e77-72ae-babc-129e4d09fcdc', 'Delete branches', 'organization.branches.delete', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e78-731f-b81b-2b313c52512a', 'Create stores', 'organization.stores.create', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e78-731f-b81b-2b313d151ee0', 'Update stores', 'organization.stores.update', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e79-72cf-a96f-83555e8cbdc6', 'Delete stores', 'organization.stores.delete', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e79-72cf-a96f-83555f49f7a4', 'Create warehouses', 'organization.warehouses.create', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e79-72cf-a96f-83555fd6a6ca', 'Update warehouses', 'organization.warehouses.update', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7a-7104-a128-5447d8564376', 'Delete warehouses', 'organization.warehouses.delete', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7a-7104-a128-5447d8ccdfc4', 'Create devices', 'organization.devices.create', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7a-7104-a128-5447d959b265', 'Update devices', 'organization.devices.update', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7b-7310-ae98-b45a8cddd0e5', 'Delete devices', 'organization.devices.delete', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7b-7310-ae98-b45a8cf41172', 'Create currencies', 'organization.currencies.create', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7b-7310-ae98-b45a8d185e0a', 'Update currencies', 'organization.currencies.update', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7b-7310-ae98-b45a8d887852', 'Delete currencies', 'organization.currencies.delete', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7c-737f-a5ed-6b8c6c00712a', 'Create payment methods', 'organization.payment_methods.create', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7c-737f-a5ed-6b8c6cd69672', 'Update payment methods', 'organization.payment_methods.update', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7c-737f-a5ed-6b8c6d04959a', 'Delete payment methods', 'organization.payment_methods.delete', 'organization', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7c-737f-a5ed-6b8c6d0dbf19', 'Create catalogs', 'catalog.catalogs.create', 'catalog', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7d-7127-98b6-d0c8c87271ac', 'Update catalogs', 'catalog.catalogs.update', 'catalog', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7d-7127-98b6-d0c8c8c3b936', 'Delete catalogs', 'catalog.catalogs.delete', 'catalog', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7d-7127-98b6-d0c8c96f03e9', 'Create categories', 'catalog.categories.create', 'catalog', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7d-7127-98b6-d0c8c98e9e0c', 'Update categories', 'catalog.categories.update', 'catalog', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7e-7202-9078-38c000e6ed9d', 'Delete categories', 'catalog.categories.delete', 'catalog', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7e-7202-9078-38c001130ca9', 'Create products', 'catalog.products.create', 'catalog', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7e-7202-9078-38c001fe9628', 'Update products', 'catalog.products.update', 'catalog', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7f-715d-8e27-36b37fcbef23', 'Delete products', 'catalog.products.delete', 'catalog', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7f-715d-8e27-36b380029014', 'Create barcodes', 'catalog.barcodes.create', 'catalog', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7f-715d-8e27-36b3808a271c', 'Update barcodes', 'catalog.barcodes.update', 'catalog', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e7f-715d-8e27-36b380e83612', 'Delete barcodes', 'catalog.barcodes.delete', 'catalog', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e80-7053-8961-cd2c49eb45c9', 'Create promotions', 'promotions.create', 'promotions', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e80-7053-8961-cd2c4a315bed', 'Update promotions', 'promotions.update', 'promotions', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e80-7053-8961-cd2c4a7bdcab', 'Delete promotions', 'promotions.delete', 'promotions', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e80-7053-8961-cd2c4ab0fd2c', 'Create cash registers', 'registers.create', 'registers', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e81-72af-a8bc-90365ea7ebb7', 'Update cash registers', 'registers.update', 'registers', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e81-72af-a8bc-90365f921e21', 'Delete cash registers', 'registers.delete', 'registers', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e81-72af-a8bc-9036600a52e9', 'Create cashier shifts', 'shifts.create', 'shifts', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e81-72af-a8bc-903660b33fbf', 'Update cashier shifts', 'shifts.update', 'shifts', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e82-7032-ba6d-5dfcd150db6b', 'Delete cashier shifts', 'shifts.delete', 'shifts', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e82-7032-ba6d-5dfcd20c63c9', 'Create POS tables', 'pos.tables.create', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e82-7032-ba6d-5dfcd2e0ab75', 'Update POS tables', 'pos.tables.update', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e83-702c-a1c0-c0fdb2c921da', 'Delete POS tables', 'pos.tables.delete', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e83-702c-a1c0-c0fdb31df41f', 'Create inventory', 'inventory.create', 'inventory', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e84-723e-8ab6-a02c8823803a', 'Update inventory', 'inventory.update', 'inventory', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e84-723e-8ab6-a02c88d32b03', 'Delete inventory', 'inventory.delete', 'inventory', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e84-723e-8ab6-a02c8906816a', 'Update expenses', 'expenses.update', 'expenses', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e85-7394-a5f0-3a5651d737de', 'Delete expenses', 'expenses.delete', 'expenses', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e85-7394-a5f0-3a5651fec93a', 'Create purchases', 'purchases.create', 'purchases', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e85-7394-a5f0-3a56527ba764', 'Update purchases', 'purchases.update', 'purchases', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e85-7394-a5f0-3a565286ccc3', 'Create customers', 'customers.create', 'customers', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e86-7006-9213-ca062ff676e2', 'Update customers', 'customers.update', 'customers', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e86-7006-9213-ca063050dd19', 'Delete customers', 'customers.delete', 'customers', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e86-7006-9213-ca0630accb54', 'Create suppliers', 'suppliers.create', 'suppliers', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e87-73eb-ae5a-a3e618127f52', 'Update suppliers', 'suppliers.update', 'suppliers', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e87-73eb-ae5a-a3e6181daba4', 'Delete suppliers', 'suppliers.delete', 'suppliers', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e88-73c9-a052-50a12ddc5639', 'Create users', 'users.create', 'admin', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e89-72c6-b4bf-95389b4c8679', 'Update users', 'users.update', 'admin', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8a-728a-b676-b6af38c77c6a', 'Delete users', 'users.delete', 'admin', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8a-728a-b676-b6af39551446', 'Create roles', 'roles.create', 'admin', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8a-728a-b676-b6af39a22fee', 'Update roles', 'roles.update', 'admin', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8b-7359-8e8e-bc4ec5cba317', 'Delete roles', 'roles.delete', 'admin', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8b-7359-8e8e-bc4ec6bf724d', 'Create accounting', 'accounting.create', 'accounting', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8b-7359-8e8e-bc4ec761eb6e', 'Update accounting', 'accounting.update', 'accounting', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8c-7192-94fd-39e9b415457c', 'Delete accounting', 'accounting.delete', 'accounting', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8c-7192-94fd-39e9b43f3640', 'Create transactions', 'transactions.create', 'transactions', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8c-7192-94fd-39e9b48d003d', 'Update transactions', 'transactions.update', 'transactions', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8c-7192-94fd-39e9b5621984', 'Delete transactions', 'transactions.delete', 'transactions', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8d-712e-b147-5c819e2312ba', 'Create settings', 'settings.create', 'settings', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8d-712e-b147-5c819e89cd67', 'Update settings', 'settings.update', 'settings', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8d-712e-b147-5c819eec930d', 'Delete settings', 'settings.delete', 'settings', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8e-703b-baf3-1e7a5d687478', 'Create restaurant', 'restaurant.create', 'restaurant', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8e-703b-baf3-1e7a5e2324df', 'Update restaurant', 'restaurant.update', 'restaurant', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8e-703b-baf3-1e7a5ef61cfd', 'Delete restaurant', 'restaurant.delete', 'restaurant', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8e-703b-baf3-1e7a5f04c44b', 'Create hotel', 'hotel.create', 'hotel', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8f-730d-8ee5-30119081f073', 'Update hotel', 'hotel.update', 'hotel', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8f-730d-8ee5-3011912fb2f7', 'Delete hotel', 'hotel.delete', 'hotel', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8f-730d-8ee5-301191e54029', 'Create reservations', 'reservations.create', 'reservations', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e8f-730d-8ee5-301191f6960b', 'Update reservations', 'reservations.update', 'reservations', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e90-71b2-a4c3-8faec06c7170', 'Delete reservations', 'reservations.delete', 'reservations', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e90-71b2-a4c3-8faec0af83df', 'Create the kitchen display', 'pos.kitchen.create', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e90-71b2-a4c3-8faec1000fd6', 'Update the kitchen display', 'pos.kitchen.update', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e90-71b2-a4c3-8faec12f8d2e', 'Delete the kitchen display', 'pos.kitchen.delete', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e91-706a-8198-94d4984cd05a', 'Create tips', 'pos.tips.create', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e91-706a-8198-94d4992e9f74', 'Update tips', 'pos.tips.update', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e91-706a-8198-94d4994db646', 'Delete tips', 'pos.tips.delete', 'pos', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e92-73f5-9cc7-eed3a3b03346', 'Create CRM', 'crm.create', 'crm', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e92-73f5-9cc7-eed3a3c02a35', 'Update CRM', 'crm.update', 'crm', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e92-73f5-9cc7-eed3a3ca6b95', 'Delete CRM', 'crm.delete', 'crm', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e93-72a6-892d-c51269c4c39e', 'Create HR', 'hr.create', 'hr', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e93-72a6-892d-c5126a24e344', 'Update HR', 'hr.update', 'hr', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e94-7114-a579-89b04b36822a', 'Delete HR', 'hr.delete', 'hr', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e95-727b-9aea-8f550433f61d', 'Create projects', 'projects.create', 'projects', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e95-727b-9aea-8f550483ec1f', 'Update projects', 'projects.update', 'projects', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e95-727b-9aea-8f5504e7f171', 'Delete projects', 'projects.delete', 'projects', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e96-705f-b91a-e21e52958257', 'Create documents', 'documents.create', 'documents', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e96-705f-b91a-e21e530c7fc9', 'Update documents', 'documents.update', 'documents', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e97-7156-a051-90dd77ae65ea', 'Delete documents', 'documents.delete', 'documents', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e97-7156-a051-90dd782ae810', 'Create fleet', 'fleet.create', 'fleet', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e97-7156-a051-90dd785a30b7', 'Update fleet', 'fleet.update', 'fleet', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e97-7156-a051-90dd7864edf7', 'Delete fleet', 'fleet.delete', 'fleet', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e98-728d-98c6-ddb44c29cf58', 'Create maintenance', 'maintenance.create', 'maintenance', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e98-728d-98c6-ddb44d16a25c', 'Update maintenance', 'maintenance.update', 'maintenance', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e99-727d-b8af-91b48e8e8f9d', 'Delete maintenance', 'maintenance.delete', 'maintenance', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e99-727d-b8af-91b48ee15f60', 'Create manufacturing', 'manufacturing.create', 'manufacturing', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e99-727d-b8af-91b48f957ee7', 'Update manufacturing', 'manufacturing.update', 'manufacturing', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e9a-7194-85d9-e1c92640c1a5', 'Delete manufacturing', 'manufacturing.delete', 'manufacturing', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e9a-7194-85d9-e1c9265cbaf8', 'Create e-commerce', 'ecommerce.create', 'ecommerce', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e9a-7194-85d9-e1c92670de39', 'Update e-commerce', 'ecommerce.update', 'ecommerce', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e9a-7194-85d9-e1c926d0b0bf', 'Delete e-commerce', 'ecommerce.delete', 'ecommerce', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e9b-704e-a33f-2b0050e639e9', 'Create notification channels', 'notifications.create', 'notifications', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e9b-704e-a33f-2b00518c473b', 'Update notification channels', 'notifications.update', 'notifications', '2026-10-27 09:49:05');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a17cc3-6e9b-704e-a33f-2b0051e07aac', 'Delete notification channels', 'notifications.delete', 'notifications', '2026-10-27 09:49:05');

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

INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e1d-7033-9ace-c7d9bf3aac13');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e1d-7033-9ace-c7d9bf6e7751');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e1e-73b2-8707-bc0d8f0b7332');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e1e-73b2-8707-bc0d8fe66817');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e1e-73b2-8707-bc0d9015eb47');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e1e-73b2-8707-bc0d90a05ac7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e1f-71ef-a04e-0c8d7d7a50ee');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e1f-71ef-a04e-0c8d7dca236b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e1f-71ef-a04e-0c8d7e31241d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e1f-71ef-a04e-0c8d7f2b621f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e20-720c-aa98-e8289d0d635a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e20-720c-aa98-e8289da34120');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e20-720c-aa98-e8289e4696c2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e20-720c-aa98-e8289eedd644');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e21-70d8-ab1e-7da9b65b4252');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e21-70d8-ab1e-7da9b6f39027');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e21-70d8-ab1e-7da9b78cc3a9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e21-70d8-ab1e-7da9b7fa98d5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e22-7144-a543-74fc284c6884');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e22-7144-a543-74fc28c8bf04');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e22-7144-a543-74fc2969f588');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e22-7144-a543-74fc2a2d8e50');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e23-70d9-b94a-35b1397ada7f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e23-70d9-b94a-35b13a5edb71');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e23-70d9-b94a-35b13b336cd4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e23-70d9-b94a-35b13be411b9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e24-70ed-9673-2e7f43671e71');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e24-70ed-9673-2e7f4465a3f4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e25-7040-9adb-74c67b6c7df6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e25-7040-9adb-74c67c2ad069');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e26-727a-8f51-01aee9f1613f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e26-727a-8f51-01aeea348af4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e27-7217-9719-e9479caaf445');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e27-7217-9719-e9479d4ab057');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e27-7217-9719-e9479d8958ed');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e28-7373-8bad-e35241e7af05');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e28-7373-8bad-e35242941f6a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e28-7373-8bad-e35242ddb02e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e28-7373-8bad-e352430e6e26');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e29-7379-ac4e-60dd84e23cc6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e29-7379-ac4e-60dd85ccb7c5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e29-7379-ac4e-60dd8687c4ab');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2a-7367-b9a7-0ff06fd21806');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2a-7367-b9a7-0ff07062f259');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2a-7367-b9a7-0ff07094bb93');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2a-7367-b9a7-0ff070f54e20');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2a-7367-b9a7-0ff0712acb1c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2b-7347-baae-20004a8f7f12');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2b-7347-baae-20004a9bf06c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2b-7347-baae-20004afcc321');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2b-7347-baae-20004b9e4ea3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2c-7221-b65b-202933ddc91c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2c-7221-b65b-202934bbbe15');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2c-7221-b65b-20293555a6a8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2c-7221-b65b-202935bb93b8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2d-736e-a41c-a018de2bfe38');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2d-736e-a41c-a018de6ec89b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2d-736e-a41c-a018defef9fb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2d-736e-a41c-a018df87feeb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2e-725d-a6e6-8e6233c041f0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2e-725d-a6e6-8e6234023c88');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2e-725d-a6e6-8e62340afc71');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2e-725d-a6e6-8e623458a507');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2f-722b-aa7b-3e9b9724c7c2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2f-722b-aa7b-3e9b97645572');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2f-722b-aa7b-3e9b97c0a4de');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e2f-722b-aa7b-3e9b9897bbe1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e30-71a7-80cd-0770328f4f32');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e30-71a7-80cd-077032ab5f71');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e30-71a7-80cd-077032cfd336');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e30-71a7-80cd-07703397c7a6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e31-7272-9187-2afb8dcbad7f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e31-7272-9187-2afb8ea39749');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e31-7272-9187-2afb8ec694a9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e31-7272-9187-2afb8f8a08da');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e31-7272-9187-2afb9051cd35');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e32-73d8-bbd2-cff19e59f04b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e32-73d8-bbd2-cff19f0019b8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e32-73d8-bbd2-cff19f3222ac');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e33-7240-a808-cf1bde70867f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e33-7240-a808-cf1bded0cdac');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e33-7240-a808-cf1bdf728b67');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e33-7240-a808-cf1bdf75e6cf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e34-716b-924b-3a48aa64df1e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e34-716b-924b-3a48ab4c4bb4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e34-716b-924b-3a48abf0fb17');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e34-716b-924b-3a48ac421e84');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e35-72f2-afc0-c85c65db5cce');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e35-72f2-afc0-c85c66dafc0d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e35-72f2-afc0-c85c6758c8ef');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e36-7350-8e00-eda9252c2e05');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e36-7350-8e00-eda92594addf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e36-7350-8e00-eda92664f2f0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e37-7182-aa6b-7a6eb3a7c890');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e37-7182-aa6b-7a6eb3e9480f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e37-7182-aa6b-7a6eb44bee91');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e37-7182-aa6b-7a6eb5469e89');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e38-7367-8345-6ecb45b2fa7d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e38-7367-8345-6ecb4624ffd2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e38-7367-8345-6ecb4675e586');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e38-7367-8345-6ecb46ed852f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e39-7136-b3e4-e762f640c5e1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e39-7136-b3e4-e762f66345cb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e39-7136-b3e4-e762f685cb93');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e39-7136-b3e4-e762f6d3c80d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3a-722a-8007-8a2949439587');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3a-722a-8007-8a2949839f3b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3a-722a-8007-8a294a0a53b1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3a-722a-8007-8a294a70a5e8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3b-70fe-a772-4c426428a5db');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3b-70fe-a772-4c4264a4af63');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3b-70fe-a772-4c4265513d7a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3b-70fe-a772-4c42662bc73d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3c-7176-820c-2c71f698ee6a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3c-7176-820c-2c71f701c196');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3c-7176-820c-2c71f7e4fcf7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3c-7176-820c-2c71f845a6f4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3d-707b-a615-d3ca480fca8f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3d-707b-a615-d3ca48e03841');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3d-707b-a615-d3ca49864cdf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3d-707b-a615-d3ca4a09fa4a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3e-707e-aa82-9b9af60ce314');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3e-707e-aa82-9b9af6a33a3d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3e-707e-aa82-9b9af743af56');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3e-707e-aa82-9b9af8353444');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3f-7050-b7aa-4990c059a84f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3f-7050-b7aa-4990c11b642a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3f-7050-b7aa-4990c166b104');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e3f-7050-b7aa-4990c1827ddd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e40-716d-bfd0-2d7f583ce2ad');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e40-716d-bfd0-2d7f58835fd2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e40-716d-bfd0-2d7f59634eb5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e40-716d-bfd0-2d7f5a28cfa2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e41-7068-ae45-b47257798155');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e41-7068-ae45-b472581fc2b0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e41-7068-ae45-b472584d7eaf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e41-7068-ae45-b47258bc69d5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e42-71fb-becb-da7ab622eb23');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e42-71fb-becb-da7ab6e88126');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e42-71fb-becb-da7ab7679a80');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e42-71fb-becb-da7ab85308bc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e43-71ab-8866-50fa9264eb9e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e43-71ab-8866-50fa92f0f207');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e43-71ab-8866-50fa92fa0ed4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e44-7361-9324-54f4cde7c888');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e44-7361-9324-54f4ce32d163');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e44-7361-9324-54f4ce937c76');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e45-707d-881e-3c12ce0dd087');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e46-73b6-9dad-d47436a1f6b9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e46-73b6-9dad-d47436aa179f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e46-73b6-9dad-d47436dad8a8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e47-7060-9612-d2116f361772');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e47-7060-9612-d21170214451');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e47-7060-9612-d21170c41574');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e48-7046-8365-2efed4a9fc3d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e48-7046-8365-2efed5338fc1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e48-7046-8365-2efed603d619');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e48-7046-8365-2efed69baf39');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e49-7273-880f-b66b275722ba');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e49-7273-880f-b66b2765c3fb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e49-7273-880f-b66b284733ca');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e49-7273-880f-b66b2883f626');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4a-7394-9ff2-f09a14be00af');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4a-7394-9ff2-f09a159a2fbd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4a-7394-9ff2-f09a164ece40');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4a-7394-9ff2-f09a169e5889');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4b-7207-8efc-3cb402453216');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4b-7207-8efc-3cb4024577fa');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4b-7207-8efc-3cb4025edccd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4b-7207-8efc-3cb402dc9b89');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4c-718e-aebc-681b42dbbf39');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4c-718e-aebc-681b4332008b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4c-718e-aebc-681b43c319d9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4d-70b3-a6db-146913b6fdba');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4d-70b3-a6db-14691488bad7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4d-70b3-a6db-146914da8bb2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4d-70b3-a6db-1469150d520a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4e-73c2-99be-835b216390a0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4e-73c2-99be-835b21becfba');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4e-73c2-99be-835b21e51788');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4e-73c2-99be-835b22d48f5c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4f-730e-a839-b8f586347b75');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4f-730e-a839-b8f5863ff793');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4f-730e-a839-b8f586f5a13e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4f-730e-a839-b8f587003dfe');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e4f-730e-a839-b8f587d2f309');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e50-7006-b506-3764f7f8523c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e50-7006-b506-3764f89ecafc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e50-7006-b506-3764f97651c1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e51-7335-b2c6-aa1195d0b0d2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e51-7335-b2c6-aa1195d30aad');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e51-7335-b2c6-aa119673b844');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e51-7335-b2c6-aa1196a456cc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e52-73dd-b89b-8d3d9ec19885');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e52-73dd-b89b-8d3d9f0af82b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e52-73dd-b89b-8d3d9f1521de');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e52-73dd-b89b-8d3d9f23606a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e53-7004-8efc-25f9a7e136aa');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e53-7004-8efc-25f9a7e781bc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e53-7004-8efc-25f9a7eb21db');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e53-7004-8efc-25f9a7fc1aed');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e54-701a-8f91-3872375b6972');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e54-701a-8f91-387237c01dc0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e54-701a-8f91-38723802e363');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e54-701a-8f91-3872388a8e48');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e55-7136-ac6d-b335d35439f4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e56-7339-b141-af788b0e0bda');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e56-7339-b141-af788bf312f6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e57-7382-9029-268815b75ab8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e57-7382-9029-26881655f6de');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e58-710e-a7bd-c4b0ae70684b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e58-710e-a7bd-c4b0ae8a4312');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e58-710e-a7bd-c4b0aec3dafc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e59-7280-ac41-cea3bd1b6fe7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e59-7280-ac41-cea3bd5f2f70');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e59-7280-ac41-cea3bd767dce');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e59-7280-ac41-cea3be4d033d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5a-7057-9e6e-46c6948279a7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5a-7057-9e6e-46c6954a467d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5a-7057-9e6e-46c69636230e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5a-7057-9e6e-46c696fa19cf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5b-722b-832b-535e422fa9dc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5b-722b-832b-535e42ba2a21');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5b-722b-832b-535e433622af');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5b-722b-832b-535e4362f7fa');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5c-71bb-9938-96e54b1d85a6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5c-71bb-9938-96e54b779c23');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5c-71bb-9938-96e54c309244');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5c-71bb-9938-96e54d2a2c52');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5d-703b-9446-678fb8fc8d56');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5d-703b-9446-678fb8ff6f54');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5d-703b-9446-678fb9c474f2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5d-703b-9446-678fb9ef499b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5e-7325-ba11-08f4e5ae8602');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5e-7325-ba11-08f4e6873a96');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5e-7325-ba11-08f4e70d2b41');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5e-7325-ba11-08f4e732cbbc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5f-708e-90af-f1434487a846');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5f-708e-90af-f1434560e477');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5f-708e-90af-f14345c0da9e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e5f-708e-90af-f14346b04803');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e60-7195-bac6-9b9966b41049');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e60-7195-bac6-9b99671d0724');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e60-7195-bac6-9b99678b09b0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e60-7195-bac6-9b99680d55b8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e61-71e8-b85b-66900fa30845');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e61-71e8-b85b-66900fbdb4d0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e61-71e8-b85b-669010bab420');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e62-7303-84bd-adb15a7e9562');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e62-7303-84bd-adb15a9894bf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e62-7303-84bd-adb15b34ba98');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e62-7303-84bd-adb15bec07d8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e63-702b-a1bb-ca8980386486');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e63-702b-a1bb-ca89804487a4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e63-702b-a1bb-ca8980634366');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e63-702b-a1bb-ca89811c2697');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e64-700f-bf1c-ed2057ae6d54');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e64-700f-bf1c-ed2057f4b3a5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e64-700f-bf1c-ed20583915e0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e65-71cc-891a-4d67665fc14c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e65-71cc-891a-4d6766ddda65');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e66-7376-b959-697a8eb8f7b1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e66-7376-b959-697a8f9fb43a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e68-704f-969c-a5849bf9ff3b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e69-71df-924e-8395238d4a7b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e69-71df-924e-839524564685');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6a-700d-86a7-dcec3fe376ba');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6a-700d-86a7-dcec40a7b806');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6b-704b-aa87-21e6a533e048');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6b-704b-aa87-21e6a56b590d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6b-704b-aa87-21e6a5bab077');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6c-7109-91b2-fedfe66eb4a4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6c-7109-91b2-fedfe76dc01f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6c-7109-91b2-fedfe7ddb7ca');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6c-7109-91b2-fedfe81a07df');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6d-721e-a525-9c2f61ba3e9d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6d-721e-a525-9c2f622305bd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6d-721e-a525-9c2f631992e9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6e-7253-95d3-4ce384c2c780');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6e-7253-95d3-4ce384f2409c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6e-7253-95d3-4ce38553f556');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6e-7253-95d3-4ce385e211b4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6f-7029-a374-0036e7175aab');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6f-7029-a374-0036e80dc5c8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6f-7029-a374-0036e8a4f021');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e6f-7029-a374-0036e9108b0b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e70-72f0-91bd-229761af8984');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e70-72f0-91bd-229761bef131');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e70-72f0-91bd-2297625de1f2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e71-71fa-8fdd-fd8c6a8ead72');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e71-71fa-8fdd-fd8c6aaf394a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e71-71fa-8fdd-fd8c6b367508');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e71-71fa-8fdd-fd8c6bcef9e2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e72-711e-af92-5baee23a0131');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e72-711e-af92-5baee2651018');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e72-711e-af92-5baee3641397');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e72-711e-af92-5baee36e1ad0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e73-7166-9ee3-8cd05ee441da');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e73-7166-9ee3-8cd05f2293cd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e73-7166-9ee3-8cd05fba33c1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e74-739f-b341-cc46513e554e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e74-739f-b341-cc465221b2f4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e75-7250-ac52-c8f3da3a3957');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e75-7250-ac52-c8f3daf2a92d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e75-7250-ac52-c8f3daf9ad3a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e76-726b-b994-3f7b29aea6e9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e76-726b-b994-3f7b29cd3ef7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e77-72ae-babc-129e4cb67b3b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e77-72ae-babc-129e4d09fcdc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e78-731f-b81b-2b313c52512a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e78-731f-b81b-2b313d151ee0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e79-72cf-a96f-83555e8cbdc6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e79-72cf-a96f-83555f49f7a4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e79-72cf-a96f-83555fd6a6ca');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7a-7104-a128-5447d8564376');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7a-7104-a128-5447d8ccdfc4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7a-7104-a128-5447d959b265');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7b-7310-ae98-b45a8cddd0e5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7b-7310-ae98-b45a8cf41172');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7b-7310-ae98-b45a8d185e0a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7b-7310-ae98-b45a8d887852');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7c-737f-a5ed-6b8c6c00712a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7c-737f-a5ed-6b8c6cd69672');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7c-737f-a5ed-6b8c6d04959a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7c-737f-a5ed-6b8c6d0dbf19');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7d-7127-98b6-d0c8c87271ac');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7d-7127-98b6-d0c8c8c3b936');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7d-7127-98b6-d0c8c96f03e9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7d-7127-98b6-d0c8c98e9e0c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7e-7202-9078-38c000e6ed9d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7e-7202-9078-38c001130ca9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7e-7202-9078-38c001fe9628');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7f-715d-8e27-36b37fcbef23');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7f-715d-8e27-36b380029014');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7f-715d-8e27-36b3808a271c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e7f-715d-8e27-36b380e83612');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e80-7053-8961-cd2c49eb45c9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e80-7053-8961-cd2c4a315bed');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e80-7053-8961-cd2c4a7bdcab');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e80-7053-8961-cd2c4ab0fd2c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e81-72af-a8bc-90365ea7ebb7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e81-72af-a8bc-90365f921e21');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e81-72af-a8bc-9036600a52e9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e81-72af-a8bc-903660b33fbf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e82-7032-ba6d-5dfcd150db6b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e82-7032-ba6d-5dfcd20c63c9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e82-7032-ba6d-5dfcd2e0ab75');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e83-702c-a1c0-c0fdb2c921da');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e83-702c-a1c0-c0fdb31df41f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e84-723e-8ab6-a02c8823803a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e84-723e-8ab6-a02c88d32b03');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e84-723e-8ab6-a02c8906816a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e85-7394-a5f0-3a5651d737de');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e85-7394-a5f0-3a5651fec93a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e85-7394-a5f0-3a56527ba764');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e85-7394-a5f0-3a565286ccc3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e86-7006-9213-ca062ff676e2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e86-7006-9213-ca063050dd19');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e86-7006-9213-ca0630accb54');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e87-73eb-ae5a-a3e618127f52');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e87-73eb-ae5a-a3e6181daba4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e88-73c9-a052-50a12ddc5639');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e89-72c6-b4bf-95389b4c8679');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8a-728a-b676-b6af38c77c6a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8a-728a-b676-b6af39551446');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8a-728a-b676-b6af39a22fee');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8b-7359-8e8e-bc4ec5cba317');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8b-7359-8e8e-bc4ec6bf724d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8b-7359-8e8e-bc4ec761eb6e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8c-7192-94fd-39e9b415457c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8c-7192-94fd-39e9b43f3640');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8c-7192-94fd-39e9b48d003d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8c-7192-94fd-39e9b5621984');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8d-712e-b147-5c819e2312ba');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8d-712e-b147-5c819e89cd67');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8d-712e-b147-5c819eec930d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8e-703b-baf3-1e7a5d687478');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8e-703b-baf3-1e7a5e2324df');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8e-703b-baf3-1e7a5ef61cfd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8e-703b-baf3-1e7a5f04c44b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8f-730d-8ee5-30119081f073');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8f-730d-8ee5-3011912fb2f7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8f-730d-8ee5-301191e54029');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e8f-730d-8ee5-301191f6960b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e90-71b2-a4c3-8faec06c7170');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e90-71b2-a4c3-8faec0af83df');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e90-71b2-a4c3-8faec1000fd6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e90-71b2-a4c3-8faec12f8d2e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e91-706a-8198-94d4984cd05a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e91-706a-8198-94d4992e9f74');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e91-706a-8198-94d4994db646');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e92-73f5-9cc7-eed3a3b03346');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e92-73f5-9cc7-eed3a3c02a35');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e92-73f5-9cc7-eed3a3ca6b95');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e93-72a6-892d-c51269c4c39e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e93-72a6-892d-c5126a24e344');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e94-7114-a579-89b04b36822a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e95-727b-9aea-8f550433f61d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e95-727b-9aea-8f550483ec1f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e95-727b-9aea-8f5504e7f171');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e96-705f-b91a-e21e52958257');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e96-705f-b91a-e21e530c7fc9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e97-7156-a051-90dd77ae65ea');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e97-7156-a051-90dd782ae810');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e97-7156-a051-90dd785a30b7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e97-7156-a051-90dd7864edf7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e98-728d-98c6-ddb44c29cf58');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e98-728d-98c6-ddb44d16a25c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e99-727d-b8af-91b48e8e8f9d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e99-727d-b8af-91b48ee15f60');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e99-727d-b8af-91b48f957ee7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e9a-7194-85d9-e1c92640c1a5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e9a-7194-85d9-e1c9265cbaf8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e9a-7194-85d9-e1c92670de39');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e9a-7194-85d9-e1c926d0b0bf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e9b-704e-a33f-2b0050e639e9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e9b-704e-a33f-2b00518c473b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', '01a17cc3-6e9b-704e-a33f-2b0051e07aac');

DROP TABLE IF EXISTS "roles";
CREATE TABLE "roles" ("id" varchar not null, "tenant_id" varchar, "name" varchar not null, "slug" varchar not null, "is_system" tinyint(1) not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));

INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc3-6e9c-72bb-bdb5-848df86ac021', NULL, 'Super Admin', 'super_admin', 1, '2026-10-27 09:49:05', '2026-10-27 09:49:05');

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

INSERT INTO "user_roles" ("id", "user_id", "role_id", "branch_id", "store_id", "created_at", "updated_at") VALUES ('01a17cc3-6eb2-711a-9797-ae03221fbf6b', '01a17cc3-6eb1-72e3-9f7b-b2a94f1e3d8b', '01a17cc3-6e9c-72bb-bdb5-848df86ac021', NULL, NULL, '2026-10-27 09:49:05', '2026-10-27 09:49:05');

DROP TABLE IF EXISTS "users";
CREATE TABLE "users" ("id" varchar not null, "name" varchar not null, "email" varchar not null, "email_verified_at" datetime, "password" varchar not null, "phone" varchar, "pin" varchar, "is_active" tinyint(1) not null default ('1'), "remember_token" varchar, "created_at" datetime, "updated_at" datetime, "tenant_id" varchar, "api_token" varchar, "two_factor_secret" text, "two_factor_confirmed_at" datetime, "two_factor_recovery_codes" text, "phone_verified_at" datetime, "party_id" varchar, foreign key("tenant_id") references tenants("id") on delete set null on update no action, foreign key("party_id") references "parties"("id") on delete set null, primary key ("id"));

INSERT INTO "users" ("id", "name", "email", "email_verified_at", "password", "phone", "pin", "is_active", "remember_token", "created_at", "updated_at", "tenant_id", "api_token", "two_factor_secret", "two_factor_confirmed_at", "two_factor_recovery_codes", "phone_verified_at", "party_id") VALUES ('01a17cc3-6eb1-72e3-9f7b-b2a94f1e3d8b', 'Platform Backup', 'platform-backup@test.local', NULL, '$2y$04$MPUS1wBNqZHdj2e83EGMTeyjYpvG9OSqQO5KEk71W98Rw5KIz89V6', NULL, NULL, 1, NULL, '2026-10-27 09:49:05', '2026-10-27 09:49:05', NULL, NULL, NULL, NULL, NULL, NULL, NULL);

DROP TABLE IF EXISTS "warehouses";
CREATE TABLE "warehouses" ("id" varchar not null, "tenant_id" varchar not null, "branch_id" varchar not null, "name" varchar not null, "code" varchar not null, "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "location_id" varchar, foreign key("branch_id") references branches("id") on delete cascade on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("location_id") references "locations"("id") on delete set null, primary key ("id"));


COMMIT;
PRAGMA foreign_keys=ON;
