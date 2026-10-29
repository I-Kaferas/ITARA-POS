-- ITARA-POS logical database backup
-- driver: sqlite
-- created: 2026-10-29T05:54:11+00:00

PRAGMA foreign_keys=OFF;
BEGIN;

DROP TABLE IF EXISTS "accounting_entries";
CREATE TABLE "accounting_entries" ("id" varchar not null, "tenant_id" varchar not null, "entry_type" varchar not null, "reference_type" varchar, "reference_id" varchar, "debit" integer not null default '0', "credit" integer not null default '0', "account_code" varchar not null, "description" text, "recorded_by" varchar, "occurred_at" datetime, "created_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("recorded_by") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "audit_logs";
CREATE TABLE "audit_logs" ("id" varchar not null, "tenant_id" varchar not null, "user_id" varchar, "action" varchar not null, "entity_type" varchar not null, "entity_id" varchar, "payload" text, "ip_address" varchar, "created_at" datetime not null default CURRENT_TIMESTAMP, foreign key("tenant_id") references "tenants"("id") on delete cascade, foreign key("user_id") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "auth_tokens";
CREATE TABLE "auth_tokens" ("id" varchar not null, "user_id" varchar not null, "device_name" varchar, "access_token_hash" varchar not null, "refresh_token_hash" varchar not null, "ip_address" varchar, "user_agent" text, "last_used_at" datetime, "access_expires_at" datetime not null, "refresh_expires_at" datetime not null, "revoked_at" datetime, "created_at" datetime, "updated_at" datetime, foreign key("user_id") references "users"("id") on delete cascade, primary key ("id"));

INSERT INTO "auth_tokens" ("id", "user_id", "device_name", "access_token_hash", "refresh_token_hash", "ip_address", "user_agent", "last_used_at", "access_expires_at", "refresh_expires_at", "revoked_at", "created_at", "updated_at") VALUES ('01a18639-1a26-71fb-af55-32fe0ba329e2', '01a18639-1a1f-70fa-991e-1b43be9d5767', NULL, 'fdccd3b6ded38f94f5a6a24975528353a6f4b0565aa0d0c177d7571b420b2734', 'bb950515161bd8f94ab9f524688665d42893ad3e4fea13d56791a85d31a18962', NULL, NULL, '2026-10-29 05:54:11', '2026-10-29 06:54:11', '2026-11-28 05:54:11', NULL, '2026-10-29 05:54:11', '2026-10-29 05:54:11');

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
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (132, '2026_10_27_130000_link_warehouses_to_stores', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (133, '2026_10_27_160000_create_recurring_expenses_table', 1);
INSERT INTO "migrations" ("id", "migration", "batch") VALUES (134, '2026_10_27_161500_extend_recurring_expenses', 1);

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

INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1878-71ce-a432-598a60060951', 'View dashboard', 'dashboard.view', 'dashboard', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-187a-72c5-b82b-4270396e65e5', 'View companies', 'organization.companies.view', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-187b-71c7-bcdc-6745aa824554', 'Manage companies', 'organization.companies.manage', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-187b-71c7-bcdc-6745ab0b40cf', 'View branches', 'organization.branches.view', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-187c-71f2-aca3-305fb8df1e9c', 'Manage branches', 'organization.branches.manage', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-187d-7162-9402-26a887c6910c', 'View stores', 'organization.stores.view', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-187f-7309-a1b5-a66a1fd2a562', 'Manage stores', 'organization.stores.manage', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1880-70c8-884a-3a93b5968557', 'View warehouses', 'organization.warehouses.view', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1881-7085-82bc-3419d35cdb9c', 'Manage warehouses', 'organization.warehouses.manage', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1882-736a-91a2-55e049e5e540', 'View devices', 'organization.devices.view', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1883-721a-971e-35de6440edc0', 'Manage devices', 'organization.devices.manage', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1884-7121-a963-af599e83a022', 'View currencies', 'organization.currencies.view', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1885-72bf-87be-bbc11bf56103', 'Manage currencies', 'organization.currencies.manage', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1886-7194-8311-5b5795a2dd84', 'View payment methods', 'organization.payment_methods.view', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1887-72a3-89ad-039f88c3b816', 'Manage payment methods', 'organization.payment_methods.manage', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1888-72b1-a453-deba36a60eec', 'View catalogs', 'catalog.catalogs.view', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1889-71a3-8749-ca3e5c4604f8', 'Manage catalogs', 'catalog.catalogs.manage', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-188a-73f1-a451-6171465ab483', 'View categories', 'catalog.categories.view', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-188b-7033-90da-8dbeca6fc429', 'Manage categories', 'catalog.categories.manage', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-188c-73b5-9542-d3ea5369ab3d', 'View products', 'catalog.products.view', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-188d-710e-9b4f-8c49fe24d569', 'Manage products', 'catalog.products.manage', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-188e-7278-a04c-a6399aebcd67', 'View barcodes', 'catalog.barcodes.view', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-188f-7029-b911-62b9721f6de4', 'Manage barcodes', 'catalog.barcodes.manage', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-188f-7029-b911-62b9725749eb', 'View sales', 'sales.view', 'sales', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-188f-7029-b911-62b972e8b03b', 'Create sales', 'sales.create', 'sales', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1890-716b-8725-2e2435a11ef2', 'Create sale', 'sale.create', 'sales', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1891-7088-b841-8234033340ea', 'Create payment', 'payments.create', 'sales', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1891-7088-b841-823403f503a3', 'Create payment', 'payment.create', 'sales', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1892-7383-bdfb-b966eac8644b', 'Print receipt', 'receipts.print', 'sales', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1893-7276-823c-43d87bff5c4f', 'Print receipt', 'receipt.print', 'sales', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1895-7220-bdaa-699a6d5b1dbe', 'Void sales', 'sales.void', 'sales', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1896-7137-962a-e4cde52f98e2', 'Refund sales', 'sales.refund', 'sales', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1897-7321-a816-b4ccf6df566d', 'Refund sale', 'sale.refund', 'sales', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1898-71e0-967e-a174de12a36b', 'Process sale returns', 'sales.return', 'sales', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1899-7265-8b7c-8096d80232d3', 'Merge pending sales', 'sales.merge', 'sales', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-189a-714d-94a7-5a82e5c5e69c', 'Apply discounts', 'sales.discount.apply', 'sales', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-189b-7049-9109-78fc69102aed', 'View promotions', 'promotions.view', 'promotions', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-189c-7080-abaf-93441cd9fee5', 'Manage promotions', 'promotions.manage', 'promotions', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-189e-72c1-82ec-460348e0d8d2', 'View cash registers', 'registers.view', 'registers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-189f-7267-b637-77309758a914', 'Manage cash registers', 'registers.manage', 'registers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18a0-73c4-9e85-034e61455a48', 'Open register session', 'registers.session.open', 'registers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18a0-73c4-9e85-034e61c5116a', 'Close register session', 'registers.session.close', 'registers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18a1-71fb-bd86-1c86c6f8bf9b', 'Record cash movements', 'registers.movement.record', 'registers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18a1-71fb-bd86-1c86c7e1cbef', 'View cashier shifts', 'shifts.view', 'shifts', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18a2-7200-9458-e11c4d0f180e', 'Manage cashier shifts', 'shifts.manage', 'shifts', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18a3-733f-9590-6cf69f7634e5', 'Open cashier shift', 'shifts.open', 'shifts', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18a4-732f-b9fc-52443ae4a4c1', 'Close cashier shift', 'shifts.close', 'shifts', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18a5-7259-a1d8-4a03e43eb5c9', 'Record shift cash movements', 'shifts.movement.record', 'shifts', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18a6-72ea-ae31-249894b83ccf', 'View POS tables', 'pos.tables.view', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18a7-712f-9078-20ea227e4115', 'Manage POS tables', 'pos.tables.manage', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18a9-7045-8bfd-a58904db45d6', 'Open table orders', 'pos.tables.open', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18aa-7218-87c2-3fb0f2d00951', 'Transfer table orders', 'pos.tables.transfer', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ab-7254-9d37-0785e795b4ab', 'Merge table orders', 'pos.tables.merge', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ac-73bb-b22e-2d857df13ae9', 'Reserve POS tables', 'pos.tables.reserve', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ad-7355-9cba-c65f96120a92', 'View POS table statistics', 'pos.tables.stats', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ae-70a6-955e-e788398681fe', 'View inventory', 'inventory.view', 'inventory', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18af-72f7-be2b-10c85b1072f0', 'Manage inventory', 'inventory.manage', 'inventory', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18b0-70dd-bcda-4b3bd6e0191b', 'Adjust stock', 'inventory.adjust', 'inventory', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18b1-70e4-819f-23a2215692c2', 'Adjust stock', 'stock.adjust', 'inventory', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18b1-70e4-819f-23a22204e173', 'Transfer stock', 'inventory.transfer', 'inventory', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18b2-71e6-a12c-d89e1bb9fb70', 'Create inventory count', 'inventory.count.create', 'inventory', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18b2-71e6-a12c-d89e1ca55b70', 'Enter inventory count quantities', 'inventory.count.enter', 'inventory', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18b3-70f0-8815-2ad9517e0e74', 'Review inventory count', 'inventory.count.review', 'inventory', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18b3-70f0-8815-2ad9526489a5', 'Approve inventory count and post adjustments', 'inventory.count.approve', 'inventory', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18b4-7320-aa6f-efdae8b65d48', 'Configure cycle count rules', 'inventory.cycle.configure', 'inventory', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18b5-729d-911f-5cadefd4548a', 'View expenses', 'expenses.view', 'expenses', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18b6-70dc-9a67-198a82d46562', 'Manage expenses', 'expenses.manage', 'expenses', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18b7-721c-b736-ea3c84b24f70', 'Create expense', 'expenses.create', 'expenses', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18b8-73a4-841a-c51ef5ed37fe', 'Submit expense', 'expenses.submit', 'expenses', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18b9-70cc-9140-e0a955898958', 'Approve expense', 'expenses.approve', 'expenses', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ba-73d6-922e-62544609d894', 'Pay expense', 'expenses.pay', 'expenses', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18bc-71fe-996b-2813b2bf71f9', 'Cancel expense', 'expenses.cancel', 'expenses', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18bd-7319-85a7-a670bf3c7938', 'Manage expense categories', 'expenses.categories', 'expenses', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18be-73d9-9795-d91723181a14', 'Manage recurring expenses', 'expenses.recurring', 'expenses', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18bf-7234-8765-8d3f9843573a', 'View expense reports', 'expenses.reports', 'expenses', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18bf-7234-8765-8d3f990f2f75', 'Export expense reports', 'expenses.export', 'expenses', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18c0-7066-bb4e-47d4f86aadcd', 'Manage expense budgets', 'expenses.budgets', 'expenses', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18c2-7349-8d5d-f5bf6c2407d0', 'View purchases', 'purchases.view', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18c3-72ac-b93b-f883d613f32f', 'Manage purchases', 'purchases.manage', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18c4-718a-827a-a9b0957f65a1', 'Receive goods', 'purchases.receive', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18c5-7208-8242-4619c896c419', 'Create requisition', 'purchases.requisition.create', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18c6-73ef-ae94-2ffd90c9c789', 'Approve requisition', 'purchases.requisition.approve', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18c8-70ef-b333-fd53a6340572', 'Create proforma', 'purchases.proforma.create', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18c9-73ff-897b-8c16687b3f9c', 'Approve proforma', 'purchases.proforma.approve', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ca-738c-b457-7aabff9fde77', 'Create purchase order', 'purchases.order.create', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18cb-73c6-80c7-cd03179a45bf', 'Approve purchase order', 'purchases.order.approve', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18cc-71b3-8af2-f3c400b5b7fb', 'Create supplier invoice', 'purchases.invoice.create', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ce-72ca-ba41-5fa945b02d27', 'Approve supplier invoice', 'purchases.invoice.approve', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ce-72ca-ba41-5fa94684105f', 'Make supplier payment', 'purchases.payment.create', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ce-72ca-ba41-5fa9475aaa2c', 'Approve supplier payment', 'purchases.payment.approve', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18cf-7240-9df5-43e4c3bb122e', 'Create purchase return', 'purchases.return.create', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18cf-7240-9df5-43e4c3c901f2', 'Approve purchase return', 'purchases.return.approve', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18d0-723a-ac52-1d4372ed3838', 'Export purchase reports', 'purchases.export', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18d1-7334-96dc-1cfa188f8fa5', 'Delete purchase documents', 'purchases.delete', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18d1-7334-96dc-1cfa18aa1601', 'View customers', 'customers.view', 'customers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18d2-70b9-a6f5-303ce19a7fc3', 'Manage customers', 'customers.manage', 'customers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18d2-70b9-a6f5-303ce1a16f45', 'View suppliers', 'suppliers.view', 'suppliers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18d2-70b9-a6f5-303ce254fb7d', 'Manage suppliers', 'suppliers.manage', 'suppliers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18d3-73d4-ba5c-36027cdcb45d', 'View users', 'users.view', 'admin', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18d4-73b4-9b10-3d3cf3a2ab80', 'Manage users', 'users.manage', 'admin', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18d5-7392-83ec-6ecaa0ba847d', 'View roles', 'roles.view', 'admin', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18d6-7356-a2a3-d7395bad470f', 'Manage roles', 'roles.manage', 'admin', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18d7-7022-9be0-fe38660dca53', 'View reports', 'reports.view', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18d8-719a-9c41-4e574c543e6a', 'Export reports', 'reports.export', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18da-709f-ab5c-beaec2351542', 'View accounting', 'accounting.view', 'accounting', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18db-73da-a12e-d43ccdb51cf1', 'Manage accounting', 'accounting.manage', 'accounting', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18dc-70eb-8b8e-a1d32fc30019', 'View transactions', 'transactions.view', 'transactions', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18dd-7092-a744-e6d8e27136b6', 'Manage transactions', 'transactions.manage', 'transactions', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18de-719f-9738-3cf7d3e83bad', 'View audit logs', 'audit.view', 'audit', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e0-70db-8bbd-aca1829c14fd', 'View settings', 'settings.view', 'settings', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e1-700f-b8ce-30827199b22f', 'Manage settings', 'settings.manage', 'settings', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e1-700f-b8ce-30827242c00f', 'View restaurant', 'restaurant.view', 'restaurant', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e2-7327-914d-a6d62aaeb9e0', 'Manage restaurant', 'restaurant.manage', 'restaurant', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e2-7327-914d-a6d62b3a0f49', 'View hotel', 'hotel.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e3-7250-85ac-18874b9accee', 'Manage hotel', 'hotel.manage', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e3-7250-85ac-18874c31b88a', 'View hotel dashboard', 'hotel.dashboard.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e3-7250-85ac-18874c5e0a92', 'View front desk', 'hotel.front_desk.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e4-720c-b904-42971e62b394', 'Check in at the front desk', 'hotel.front_desk.check_in', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e4-720c-b904-42971eeb0e78', 'View room configuration', 'hotel.referential.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e4-720c-b904-42971f77ce86', 'Create room configuration', 'hotel.referential.create', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e5-712e-a29e-3ed44670efde', 'Update room configuration', 'hotel.referential.update', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e6-7059-994f-e9cf64f837f3', 'Delete room configuration', 'hotel.referential.delete', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e6-7059-994f-e9cf6582315f', 'View amenities', 'hotel.amenities.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e7-706b-a1f9-bbd5bbf165e4', 'Create amenities', 'hotel.amenities.create', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e8-71b4-ba13-0a5594a4aa8c', 'Update amenities', 'hotel.amenities.update', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e8-71b4-ba13-0a5594e105e5', 'Delete amenities', 'hotel.amenities.delete', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18e9-7235-a79b-ae89f13d6b89', 'View room types', 'hotel.room_types.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ea-70fe-8ae9-29f3d63ff41f', 'Create room types', 'hotel.room_types.create', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18eb-73c9-9f2b-5f83d73fe676', 'Update room types', 'hotel.room_types.update', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18eb-73c9-9f2b-5f83d7deb822', 'Delete room types', 'hotel.room_types.delete', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ec-7280-8584-0aa44a8f9e15', 'View buildings', 'hotel.buildings.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ed-7222-b432-c806a27fb24d', 'Create buildings', 'hotel.buildings.create', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ee-70c3-9977-ef336b000817', 'Update buildings', 'hotel.buildings.update', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ee-70c3-9977-ef336bbcb78b', 'Delete buildings', 'hotel.buildings.delete', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ee-70c3-9977-ef336c850b0b', 'View wings', 'hotel.wings.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ef-7353-b787-00e5bc3c8746', 'Create wings', 'hotel.wings.create', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ef-7353-b787-00e5bd29ec0b', 'Update wings', 'hotel.wings.update', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18f0-71a9-95f7-93247a7a461d', 'Delete wings', 'hotel.wings.delete', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18f1-737f-8342-1fbe545a2c6d', 'View floors', 'hotel.floors.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18f2-709c-b3cb-42cff60be159', 'Create floors', 'hotel.floors.create', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18f3-7028-8f99-44c2a337f437', 'Update floors', 'hotel.floors.update', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18f4-7118-9f1b-9702fe46dca2', 'Delete floors', 'hotel.floors.delete', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18f4-7118-9f1b-9702ff0904a3', 'View rooms', 'hotel.rooms.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18f4-7118-9f1b-9702ff4b1bec', 'Create rooms', 'hotel.rooms.create', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18f5-70c0-a7c4-48d5048cb834', 'Update rooms', 'hotel.rooms.update', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18f6-72e2-80d6-03b5c3da4f74', 'Delete rooms', 'hotel.rooms.delete', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18f6-72e2-80d6-03b5c47888f7', 'Update room status', 'hotel.rooms.update_status', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18f7-7360-a386-6dae58aab80f', 'View hotel reservations', 'hotel.reservations.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18f8-731a-bd47-14dcf55f4710', 'Create hotel reservations', 'hotel.reservations.create', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18f9-71fe-b61c-03d45dbb15b2', 'Update hotel reservations', 'hotel.reservations.update', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18f9-71fe-b61c-03d45e4b74dd', 'Confirm hotel reservations', 'hotel.reservations.confirm', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18fb-7266-b00f-2a547ed45911', 'Cancel hotel reservations', 'hotel.reservations.cancel', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18fc-7121-aeab-1bcd1358106e', 'Mark reservation no-show', 'hotel.reservations.no_show', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18fd-723e-8a66-6571e97ed824', 'Collect reservation deposit', 'hotel.reservations.collect_deposit', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18fe-720a-a2b3-57ff9cb91394', 'Export hotel reservations', 'hotel.reservations.export', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ff-7246-acc6-938e9d64c86c', 'Notify reservation guests', 'hotel.reservations.notify', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-18ff-7246-acc6-938e9e311cdb', 'View stays', 'hotel.stays.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1900-73c6-bd18-927b58b83769', 'Check in a stay', 'hotel.stays.check_in', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1900-73c6-bd18-927b590f8a37', 'Record a stay arrival', 'hotel.stays.arrival', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1901-7112-b7af-165140e8fa3e', 'Change stay room', 'hotel.stays.change_room', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1902-7381-98f6-719aa19e2461', 'Add a stay charge', 'hotel.stays.add_charge', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1903-7233-a8b1-9fb4257c47eb', 'Take a stay payment', 'hotel.stays.pay', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1904-707d-8493-f8d97a5c253f', 'Collect stay deposit', 'hotel.stays.collect_deposit', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1904-707d-8493-f8d97ad8f4b5', 'Refund stay deposit', 'hotel.stays.refund_deposit', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1905-73a4-9e70-ae646fb9c4b0', 'Check out a stay', 'hotel.stays.check_out', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1905-73a4-9e70-ae647078a76d', 'Sign a stay', 'hotel.stays.sign', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1906-7279-8a64-da4c47d17f42', 'Export stays', 'hotel.stays.export', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1906-7279-8a64-da4c4868a11d', 'View guest invoices', 'hotel.invoices.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1907-7210-82bc-b438a048c5cf', 'Export guest invoices', 'hotel.invoices.export', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1908-7188-8863-c6ce9af1f634', 'Print guest invoices', 'hotel.invoices.print', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1909-70bd-b8cd-90b3a982a5c2', 'View hotel guests', 'hotel.guests.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-190a-73d2-b371-8ee9f5240d94', 'Create hotel guests', 'hotel.guests.create', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-190a-73d2-b371-8ee9f5a8cd1d', 'Update hotel guests', 'hotel.guests.update', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-190a-73d2-b371-8ee9f65c1213', 'Sign a guest record', 'hotel.guests.sign', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-190b-73c8-8cf8-9af62677ba32', 'Export hotel guests', 'hotel.guests.export', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-190c-7002-9c3c-4298d8267929', 'View housekeeping', 'hotel.housekeeping.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-190d-7105-8f48-9af4c9ba03b5', 'Update room condition', 'hotel.housekeeping.update_condition', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-190d-7105-8f48-9af4c9bc4b40', 'Create housekeeping task', 'hotel.housekeeping.create_task', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-190e-720e-9ee2-a69ffd145fa2', 'Update housekeeping task', 'hotel.housekeeping.update_task', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-190f-7012-8865-5481f483aba1', 'View hotel calendar', 'hotel.calendar.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-190f-7012-8865-5481f5470d31', 'Create calendar events', 'hotel.calendar.create', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1911-71ed-9c07-1bed3c8b4d6a', 'Update calendar events', 'hotel.calendar.update', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1912-73c8-be76-8993e4dd5a9f', 'Delete calendar events', 'hotel.calendar.delete', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1913-721d-ad3c-bfedf419df97', 'View concierge', 'hotel.concierge.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1913-721d-ad3c-bfedf4a359df', 'Create concierge requests', 'hotel.concierge.create', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1914-7373-9c17-2eec06683c94', 'Update concierge status', 'hotel.concierge.update_status', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1915-715d-a167-108c47f44445', 'Assign concierge requests', 'hotel.concierge.assign', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1915-715d-a167-108c487fcbbd', 'View hotel reviews', 'hotel.reviews.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1916-7154-b089-264d6a0d4407', 'Respond to hotel reviews', 'hotel.reviews.respond', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1916-7154-b089-264d6a502046', 'Update review status', 'hotel.reviews.update_status', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1918-73c2-9e3a-7746e21b94f4', 'Export hotel reviews', 'hotel.reviews.export', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1919-7311-9b96-b45f61dd8e4c', 'View hotel reports', 'hotel.reports.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-191a-72a1-b141-9256a4a8def2', 'Export hotel reports', 'hotel.reports.export', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-191a-72a1-b141-9256a50a349c', 'View hotel configuration', 'hotel.config.view', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-191b-737a-a64d-b2d07f7a5c21', 'Update hotel configuration', 'hotel.config.update', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-191b-737a-a64d-b2d07ff73a9a', 'View analytics', 'analytics.view', 'dashboard', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-191c-7249-90d1-dfdb72cc25df', 'View condensed reports', 'reports.condensed.view', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-191c-7249-90d1-dfdb7376c64a', 'Export condensed reports', 'reports.condensed.export', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-191c-7249-90d1-dfdb73776619', 'View daily reports', 'reports.daily.view', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-191d-70db-b587-20b23664af61', 'Export daily reports', 'reports.daily.export', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-191d-70db-b587-20b23731ec48', 'View financial reports', 'reports.financial.view', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-191e-70c2-84ba-6c863f4d0e01', 'Export financial reports', 'reports.financial.export', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-191e-70c2-84ba-6c863f67eae8', 'View forecasting reports', 'reports.forecasting.view', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-191f-7014-9562-0b6c369f2061', 'Export forecasting reports', 'reports.forecasting.export', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1920-71cb-b470-6316e2772a30', 'View inventory reports', 'reports.inventory_reports.view', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1921-7389-982c-79e5f28ed05d', 'Export inventory reports', 'reports.inventory_reports.export', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1921-7389-982c-79e5f2db7f4b', 'View performance reports', 'reports.performance.view', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1922-739c-af76-fc9b6b28cce5', 'Export performance reports', 'reports.performance.export', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1922-739c-af76-fc9b6b29b492', 'View sales reports', 'reports.sales_reports.view', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1923-73e2-bf59-985547fe0b6d', 'Export sales reports', 'reports.sales_reports.export', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1924-7190-908a-4e3921c7baed', 'Export revenue reports', 'reports.revenue.export', 'reports', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1925-70aa-816e-c4da5d39884e', 'Approve devices', 'organization.devices.approve', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1926-7017-aceb-e79dc0fa3d34', 'Block devices', 'organization.devices.block', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1928-70bc-a7f3-39e38285bd63', 'View sync', 'sync.view', 'sync', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1929-708f-b131-1cb90e2c254c', 'Configure sync', 'sync.configure', 'sync', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-192a-7159-9b01-e60dc7b3cc36', 'Force sync', 'sync.force', 'sync', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-192b-7228-9e1f-250a7a16cb71', 'View reservations', 'reservations.view', 'reservations', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-192c-7293-b76a-2d27f0825c42', 'Manage reservations', 'reservations.manage', 'reservations', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-192d-736a-8bed-21b1139918d6', 'Access the point of sale', 'pos.access', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-192e-71cd-beb5-e4b0bed37691', 'Work as cashier', 'pos.cashier', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-192f-7207-904f-13122c326760', 'Choose session stores', 'pos.session.choose_stores', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1930-7123-9b78-ba66685058d7', 'Open a session for others', 'pos.session.open_for_others', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1932-72eb-99ae-02b920ff8de2', 'Print session report', 'pos.session.print_report', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1933-7168-a3b5-e7adea2c211d', 'Require a cashier session', 'pos.session.required', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1935-7374-a477-0e9bcd4d8500', 'Edit POS orders', 'pos.orders.edit', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1936-7056-8a2f-6fc906a617fb', 'Delete POS orders', 'pos.orders.delete', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1936-7056-8a2f-6fc906c321c7', 'Update POS orders', 'pos.orders.update', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1937-71fe-a2de-66de11bd01ed', 'Override order tax', 'pos.orders.tax_override', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1937-71fe-a2de-66de12222e69', 'Override order price', 'pos.orders.override_price', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1938-729c-a3b4-0e6e56b006ae', 'Create delivery orders', 'pos.orders.delivery', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1939-71df-8779-f76f25a5b9af', 'Create dine-in orders', 'pos.orders.dine_in', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-193a-7393-81bc-12c653d2bc97', 'Create takeaway orders', 'pos.orders.takeaway', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-193a-7393-81bc-12c6541ae547', 'Send order to kitchen', 'pos.orders.send_kitchen', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-193b-7318-a168-9b66251e9fcc', 'Void an order item', 'pos.orders.void_item', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-193b-7318-a168-9b66255ab539', 'Refund an order item', 'pos.orders.refund_item', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-193b-7318-a168-9b6625f32852', 'Set the order date', 'pos.orders.set_date', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-193c-7158-b772-a5080ec832d1', 'Print order invoice', 'pos.orders.print_invoice', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-193c-7158-b772-a5080f941ff0', 'Print kitchen ticket', 'pos.orders.print_kitchen', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-193c-7158-b772-a508105ffdaf', 'Print order summary', 'pos.orders.print_summary', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-193c-7158-b772-a508110199c3', 'Reprint invoice', 'pos.orders.reprint_invoice', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-193d-72d0-8ab8-32167cd1c0c5', 'Reprint kitchen ticket', 'pos.orders.reprint_kitchen', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-193d-72d0-8ab8-32167cfad005', 'Reprint order summary', 'pos.orders.reprint_summary', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-193d-72d0-8ab8-32167d0303c3', 'Reprint receipt', 'pos.orders.reprint_receipt', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-193e-70fa-a088-a9c74da0b85b', 'Hold an order directly', 'pos.orders.hold_direct', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-193f-7301-ad67-f369da7c2d9f', 'Add to cart', 'pos.cart.add', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1940-719c-aa54-1c18f98f9020', 'Modify the cart', 'pos.cart.modify', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1941-7038-a2b3-dd1590d8dbea', 'Remove from cart', 'pos.cart.remove', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1942-723b-925c-d7c058ad2bdc', 'Clear the cart', 'pos.cart.clear', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1943-71a8-a889-22f4ba818fb6', 'Hold an order', 'pos.cart.hold', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1944-72a1-a6dc-0dfc443b4454', 'Assign a server', 'pos.cart.assign_server', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1945-7385-919a-fb0b8d52387d', 'View POS payments', 'pos.payments.view', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1946-73ab-9ef6-527ff84be3ec', 'Refund a POS payment', 'pos.payments.refund', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1946-73ab-9ef6-527ff8d349e1', 'Take a mixed payment', 'pos.payments.mixed', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1947-7248-9e92-de2f82cf1bcd', 'Take a cash payment', 'pos.payments.cash', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1947-7248-9e92-de2f83b1dbf1', 'Take a card payment', 'pos.payments.card', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1948-7109-9b75-7b00e10cfdf3', 'Take a mobile payment', 'pos.payments.mobile', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1948-7109-9b75-7b00e1603d36', 'Take a check payment', 'pos.payments.check', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1948-7109-9b75-7b00e1edb44a', 'Take a wallet payment', 'pos.payments.wallet', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-194a-70d9-945b-ea4c3aa27aa4', 'Take a bank transfer', 'pos.payments.bank_transfer', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-194b-7291-8c40-d65b2afc4e18', 'Pay and close the order', 'pos.payments.close', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-194c-737a-9b03-677f0273b9b0', 'Pay on credit', 'pos.payments.credit', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-194d-701c-8a21-9bd6264f4eb3', 'Require a customer for credit', 'pos.payments.credit_customer', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-194f-7187-a9d6-d6d776759f59', 'Take a single payment', 'pos.payments.unique', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1950-73d7-9584-02503c6564e4', 'View the kitchen display', 'pos.kitchen.view', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1951-7387-9d18-edcb9b5e9120', 'Manage the kitchen display', 'pos.kitchen.manage', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1951-7387-9d18-edcb9c1acbcb', 'View other shift details', 'pos.shifts.details', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1952-738e-bf95-b1122a80c4d2', 'View all shifts', 'pos.shifts.view_all', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1953-73c3-9260-bf55f8850a22', 'Override a discount', 'pos.discounts.override', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1954-7027-931b-061de3bc02ef', 'View tips', 'pos.tips.view', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1955-73af-bacd-276e2b39c313', 'Manage tips', 'pos.tips.manage', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1956-73fc-9da8-8e81e0e0b67f', 'Apply a promotion', 'pos.promotions.apply', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1957-7107-afc5-a1388db8a8df', 'Apply a coupon', 'pos.promotions.coupon', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1957-7107-afc5-a1388e025040', 'Apply a house offer', 'pos.offers.house', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1958-70e1-9571-342a2b080abd', 'Require a customer for house offers', 'pos.offers.require_customer', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1959-7346-89e9-b0fab0d797f6', 'Access POS sync', 'pos.sync.access', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-195a-714f-9aee-070a0a7be8f6', 'Close the store from POS', 'pos.sync.close_store', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-195b-7284-b5db-def46bf93382', 'Run a full sync', 'pos.sync.full', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-195c-7080-9b6e-a24e07c375ae', 'Upload POS data', 'pos.sync.upload', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-195c-7080-9b6e-a24e08584bae', 'View the last sync date', 'pos.sync.last_date', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-195d-70b5-a236-18a488280f6e', 'Attach a customer to the sale', 'pos.customers.attach', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-195d-70b5-a236-18a488f59aa2', 'Search POS customers', 'pos.customers.search', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-195d-70b5-a236-18a4896a6618', 'Print an invoice', 'pos.print.invoice', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-195f-7210-a906-104af6fc6843', 'Print a stub', 'pos.print.stub', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1960-70cc-be5a-69782149efa0', 'Print a kitchen ticket', 'pos.print.kitchen', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1962-723b-9d6b-ac38fb27db25', 'Print the receipt and the kitchen ticket only once', 'pos.print.once', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1962-723b-9d6b-ac38fc076bad', 'View CRM', 'crm.view', 'crm', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1963-716f-99dd-bb949b69beb4', 'Manage CRM', 'crm.manage', 'crm', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1963-716f-99dd-bb949c66fd06', 'View HR', 'hr.view', 'hr', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1964-706f-b72d-b14b3e7c33bf', 'Manage HR', 'hr.manage', 'hr', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1965-732c-89ed-c51683acc9a4', 'View projects', 'projects.view', 'projects', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1966-722d-9c65-bdc775659566', 'Manage projects', 'projects.manage', 'projects', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1967-72b1-95f7-0c0c6c01119e', 'View documents', 'documents.view', 'documents', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1967-72b1-95f7-0c0c6c7afbad', 'Manage documents', 'documents.manage', 'documents', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1968-705e-bd49-2b389ef8efa9', 'View fleet', 'fleet.view', 'fleet', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1969-734f-8036-f8c8b038bc44', 'Manage fleet', 'fleet.manage', 'fleet', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-196a-71cf-9078-01e28273c781', 'View maintenance', 'maintenance.view', 'maintenance', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-196b-73a9-8485-127dbf8784c9', 'Manage maintenance', 'maintenance.manage', 'maintenance', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-196b-73a9-8485-127dbf93136e', 'View manufacturing', 'manufacturing.view', 'manufacturing', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-196c-73ca-9694-12ff3144ecc4', 'Manage manufacturing', 'manufacturing.manage', 'manufacturing', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-196d-7004-a3b5-4cbd8c860f03', 'View e-commerce', 'ecommerce.view', 'ecommerce', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-196d-7004-a3b5-4cbd8cf7921e', 'Manage e-commerce', 'ecommerce.manage', 'ecommerce', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-196e-7104-aebc-c323abaa45c2', 'View the notification center', 'notifications.view', 'notifications', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-196e-7104-aebc-c323ac8b7ee0', 'Manage notification channels', 'notifications.manage', 'notifications', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-196f-72b3-84e4-de296ebb03d3', 'Create companies', 'organization.companies.create', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1970-7087-a3d2-f2cef76100a6', 'Update companies', 'organization.companies.update', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1970-7087-a3d2-f2cef83d82a7', 'Delete companies', 'organization.companies.delete', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1971-7102-9df8-24ec4f3b502d', 'Create branches', 'organization.branches.create', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1972-72ae-baee-5148325c3e9e', 'Update branches', 'organization.branches.update', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1972-72ae-baee-514832cecaf2', 'Delete branches', 'organization.branches.delete', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1973-710b-9927-daf78647945f', 'Create stores', 'organization.stores.create', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1973-710b-9927-daf7872ecf25', 'Update stores', 'organization.stores.update', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1974-72ad-aaf6-c7621326a9e4', 'Delete stores', 'organization.stores.delete', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1975-7313-8fa1-cb3a42b39098', 'Create warehouses', 'organization.warehouses.create', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1975-7313-8fa1-cb3a42c7feeb', 'Update warehouses', 'organization.warehouses.update', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1976-73f4-81cf-d33fddd39a19', 'Delete warehouses', 'organization.warehouses.delete', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1976-73f4-81cf-d33fde8b8bcd', 'Create devices', 'organization.devices.create', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1977-7386-b6fe-a3a8df764d37', 'Update devices', 'organization.devices.update', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1978-70ec-8ece-aca18e48ebc5', 'Delete devices', 'organization.devices.delete', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1979-7259-926f-a9d2ae1f120c', 'Create currencies', 'organization.currencies.create', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1979-7259-926f-a9d2ae4531e8', 'Update currencies', 'organization.currencies.update', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-197a-70fd-a47a-15e295b11d95', 'Delete currencies', 'organization.currencies.delete', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-197a-70fd-a47a-15e2965e7978', 'Create payment methods', 'organization.payment_methods.create', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-197a-70fd-a47a-15e29703d3c4', 'Update payment methods', 'organization.payment_methods.update', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-197b-723b-a000-b072c532f7f0', 'Delete payment methods', 'organization.payment_methods.delete', 'organization', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-197b-723b-a000-b072c5f29cde', 'Create catalogs', 'catalog.catalogs.create', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-197c-73f9-8c3b-2a57d6a75b04', 'Update catalogs', 'catalog.catalogs.update', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-197c-73f9-8c3b-2a57d72194e5', 'Delete catalogs', 'catalog.catalogs.delete', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-197d-7308-82e2-823b30161f91', 'Create categories', 'catalog.categories.create', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-197e-7178-a74e-cd3d70ddc49f', 'Update categories', 'catalog.categories.update', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-197f-700f-ae65-3853723a046e', 'Delete categories', 'catalog.categories.delete', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1980-7034-9245-85ffd54d734e', 'Create products', 'catalog.products.create', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1980-7034-9245-85ffd5971541', 'Update products', 'catalog.products.update', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1981-70e0-b10b-4e1b5369ee6d', 'Delete products', 'catalog.products.delete', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1982-71a3-8525-226350c65351', 'Create barcodes', 'catalog.barcodes.create', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1983-72c0-9b80-2375d453bdc8', 'Update barcodes', 'catalog.barcodes.update', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1984-7312-82bc-60c8f6143753', 'Delete barcodes', 'catalog.barcodes.delete', 'catalog', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1986-729e-9688-c08d39fcd9e2', 'Create promotions', 'promotions.create', 'promotions', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1987-7216-8f6b-b0c3960e64c2', 'Update promotions', 'promotions.update', 'promotions', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1989-71f9-b40f-4fb433ce6975', 'Delete promotions', 'promotions.delete', 'promotions', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1989-71f9-b40f-4fb43444fc51', 'Create cash registers', 'registers.create', 'registers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-198a-70de-b370-3f6647f5d1b4', 'Update cash registers', 'registers.update', 'registers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-198a-70de-b370-3f66488f23c5', 'Delete cash registers', 'registers.delete', 'registers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-198b-7383-a6f4-581c3f2ea353', 'Create cashier shifts', 'shifts.create', 'shifts', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-198c-7369-baf2-06837de2c46f', 'Update cashier shifts', 'shifts.update', 'shifts', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-198e-7261-a333-605cab6dad88', 'Delete cashier shifts', 'shifts.delete', 'shifts', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-198f-7080-b141-001027b9e2bc', 'Create POS tables', 'pos.tables.create', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1990-7263-887e-681b28dbb1fd', 'Update POS tables', 'pos.tables.update', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1992-7032-8917-c967a7210a69', 'Delete POS tables', 'pos.tables.delete', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1993-73de-8221-20c12a15db2e', 'Create inventory', 'inventory.create', 'inventory', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1995-71ba-8817-f01dc5f42400', 'Update inventory', 'inventory.update', 'inventory', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1996-7225-9625-f6abad86e0ed', 'Delete inventory', 'inventory.delete', 'inventory', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1998-72c6-be08-3762a00ffa11', 'Update expenses', 'expenses.update', 'expenses', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1999-7275-ba82-438b8b32fae3', 'Delete expenses', 'expenses.delete', 'expenses', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-1999-7275-ba82-438b8b99f9f8', 'Create purchases', 'purchases.create', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-199a-71af-a085-38cb760c783a', 'Update purchases', 'purchases.update', 'purchases', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-199a-71af-a085-38cb76ef71ed', 'Create customers', 'customers.create', 'customers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-199b-7055-9b59-392312d35280', 'Update customers', 'customers.update', 'customers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-199c-73d1-89ef-daa03897ffd4', 'Delete customers', 'customers.delete', 'customers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-199d-71ac-92a8-53ba6d26633e', 'Create suppliers', 'suppliers.create', 'suppliers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-199e-7334-899d-49b181dc7c19', 'Update suppliers', 'suppliers.update', 'suppliers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-199e-7334-899d-49b182b3d353', 'Delete suppliers', 'suppliers.delete', 'suppliers', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19a0-716c-adc0-881d611e1fc6', 'Create users', 'users.create', 'admin', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19a1-703a-a3b3-2d6b3b7df73d', 'Update users', 'users.update', 'admin', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19a3-70b5-93f7-6cf4ef2c491f', 'Delete users', 'users.delete', 'admin', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19a4-7353-af97-9de5911d0a68', 'Create roles', 'roles.create', 'admin', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19a4-7353-af97-9de591c8df3c', 'Update roles', 'roles.update', 'admin', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19a5-71fc-8c8a-8ed8717bf026', 'Delete roles', 'roles.delete', 'admin', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19a6-725a-8df2-1aa77c446530', 'Create accounting', 'accounting.create', 'accounting', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19a7-7061-9fd3-5d0668921540', 'Update accounting', 'accounting.update', 'accounting', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19a7-7061-9fd3-5d0668cca2bb', 'Delete accounting', 'accounting.delete', 'accounting', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19a8-73bd-adc7-7739845d6343', 'Create transactions', 'transactions.create', 'transactions', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19a8-73bd-adc7-7739854f5b33', 'Update transactions', 'transactions.update', 'transactions', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19a9-7317-8416-dd8f991c99a5', 'Delete transactions', 'transactions.delete', 'transactions', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19aa-726d-9ffc-da640ca4adb2', 'Create settings', 'settings.create', 'settings', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19ab-70da-b2de-295131d1022f', 'Update settings', 'settings.update', 'settings', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19ab-70da-b2de-295131dd7efb', 'Delete settings', 'settings.delete', 'settings', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19ac-7047-a209-31801f2127d7', 'Create restaurant', 'restaurant.create', 'restaurant', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19ad-7197-bd3a-a4c35f505364', 'Update restaurant', 'restaurant.update', 'restaurant', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19ae-700c-9ba8-1c58bb7e256d', 'Delete restaurant', 'restaurant.delete', 'restaurant', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19af-704d-a8f2-659c36270ccb', 'Create hotel', 'hotel.create', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19af-704d-a8f2-659c369e7936', 'Update hotel', 'hotel.update', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19b0-7344-a9b3-261558cb81ee', 'Delete hotel', 'hotel.delete', 'hotel', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19b1-71cb-b108-7ee19301f9e4', 'Create reservations', 'reservations.create', 'reservations', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19b1-71cb-b108-7ee19302fb3d', 'Update reservations', 'reservations.update', 'reservations', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19b2-71c8-8f68-c6cc546eb612', 'Delete reservations', 'reservations.delete', 'reservations', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19b3-7053-ab22-ef24b5b637c2', 'Create the kitchen display', 'pos.kitchen.create', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19b5-71f9-a19e-e64a0b22450e', 'Update the kitchen display', 'pos.kitchen.update', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19b6-71f6-9d14-e29da3ef8947', 'Delete the kitchen display', 'pos.kitchen.delete', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19b7-72b2-bd01-deeac0282cbe', 'Create tips', 'pos.tips.create', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19b8-7025-8033-b4506630adce', 'Update tips', 'pos.tips.update', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19b9-7112-97fc-26d1e37272ca', 'Delete tips', 'pos.tips.delete', 'pos', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19ba-7151-b1c2-e9ecdd9fb248', 'Create CRM', 'crm.create', 'crm', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19bb-713b-86ef-fe1442c5decc', 'Update CRM', 'crm.update', 'crm', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19bc-705b-8d26-037e03ae3fe3', 'Delete CRM', 'crm.delete', 'crm', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19bd-707f-8d46-cfcb29ec528b', 'Create HR', 'hr.create', 'hr', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19be-71f3-bedb-33bad6c8eca0', 'Update HR', 'hr.update', 'hr', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19c0-719b-ae4c-fd7d9a269c3c', 'Delete HR', 'hr.delete', 'hr', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19c1-71fd-be86-23677b7e22bc', 'Create projects', 'projects.create', 'projects', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19c3-71fd-82d6-8d16d027091e', 'Update projects', 'projects.update', 'projects', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19c4-72cf-9b33-53ab1faf2d33', 'Delete projects', 'projects.delete', 'projects', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19c6-705a-b22e-1e320e14312e', 'Create documents', 'documents.create', 'documents', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19c7-7046-a23d-2e1432f9fc45', 'Update documents', 'documents.update', 'documents', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19c9-70df-8fdd-5a0d8d09031e', 'Delete documents', 'documents.delete', 'documents', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19ca-71f2-b4ef-798198d1304e', 'Create fleet', 'fleet.create', 'fleet', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19cb-7213-b186-8ce6692727c8', 'Update fleet', 'fleet.update', 'fleet', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19cc-729c-9ad9-462c2d288fc9', 'Delete fleet', 'fleet.delete', 'fleet', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19cc-729c-9ad9-462c2d3f6c1f', 'Create maintenance', 'maintenance.create', 'maintenance', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19cd-7259-b8d0-c34d37abd280', 'Update maintenance', 'maintenance.update', 'maintenance', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19ce-7320-9aa0-933aa9935c65', 'Delete maintenance', 'maintenance.delete', 'maintenance', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19cf-715c-ae09-0eda61545182', 'Create manufacturing', 'manufacturing.create', 'manufacturing', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19d0-71f8-9336-2634f2369b74', 'Update manufacturing', 'manufacturing.update', 'manufacturing', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19d1-72bd-a32c-14c90739d746', 'Delete manufacturing', 'manufacturing.delete', 'manufacturing', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19d2-710d-86b8-428cc6a5f79f', 'Create e-commerce', 'ecommerce.create', 'ecommerce', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19d3-7340-9b4e-b69213abf03e', 'Update e-commerce', 'ecommerce.update', 'ecommerce', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19d4-70f1-95a0-90649e8d263a', 'Delete e-commerce', 'ecommerce.delete', 'ecommerce', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19d6-72f8-99d3-2c834619520f', 'Create notification channels', 'notifications.create', 'notifications', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19d7-71a4-b4d6-799d174b71b1', 'Update notification channels', 'notifications.update', 'notifications', '2026-10-29 05:54:11');
INSERT INTO "permissions" ("id", "name", "slug", "group", "created_at") VALUES ('01a18639-19d8-734d-85e7-81e6bfba3c17', 'Delete notification channels', 'notifications.delete', 'notifications', '2026-10-29 05:54:11');

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


DROP TABLE IF EXISTS "recurring_expenses";
CREATE TABLE "recurring_expenses" ("id" varchar not null, "tenant_id" varchar not null, "branch_id" varchar, "store_id" varchar, "expense_category_id" varchar, "cash_register_id" varchar, "name" varchar not null, "amount" integer not null, "currency_code" varchar not null default ('BIF'), "frequency" varchar not null default ('monthly'), "next_due_on" date not null, "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "fund_source" varchar not null default 'main', "user_id" varchar, "starts_on" date, "ends_on" date, "notes" text, foreign key("cash_register_id") references cash_registers("id") on delete set null on update no action, foreign key("expense_category_id") references expense_categories("id") on delete set null on update no action, foreign key("store_id") references stores("id") on delete set null on update no action, foreign key("branch_id") references branches("id") on delete set null on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("user_id") references "users"("id") on delete set null, primary key ("id"));


DROP TABLE IF EXISTS "role_permissions";
CREATE TABLE "role_permissions" ("role_id" varchar not null, "permission_id" varchar not null, foreign key("role_id") references "roles"("id") on delete cascade, foreign key("permission_id") references "permissions"("id") on delete cascade, primary key ("role_id", "permission_id"));

INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1878-71ce-a432-598a60060951');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-187a-72c5-b82b-4270396e65e5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-187b-71c7-bcdc-6745aa824554');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-187b-71c7-bcdc-6745ab0b40cf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-187c-71f2-aca3-305fb8df1e9c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-187d-7162-9402-26a887c6910c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-187f-7309-a1b5-a66a1fd2a562');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1880-70c8-884a-3a93b5968557');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1881-7085-82bc-3419d35cdb9c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1882-736a-91a2-55e049e5e540');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1883-721a-971e-35de6440edc0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1884-7121-a963-af599e83a022');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1885-72bf-87be-bbc11bf56103');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1886-7194-8311-5b5795a2dd84');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1887-72a3-89ad-039f88c3b816');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1888-72b1-a453-deba36a60eec');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1889-71a3-8749-ca3e5c4604f8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-188a-73f1-a451-6171465ab483');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-188b-7033-90da-8dbeca6fc429');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-188c-73b5-9542-d3ea5369ab3d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-188d-710e-9b4f-8c49fe24d569');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-188e-7278-a04c-a6399aebcd67');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-188f-7029-b911-62b9721f6de4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-188f-7029-b911-62b9725749eb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-188f-7029-b911-62b972e8b03b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1890-716b-8725-2e2435a11ef2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1891-7088-b841-8234033340ea');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1891-7088-b841-823403f503a3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1892-7383-bdfb-b966eac8644b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1893-7276-823c-43d87bff5c4f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1895-7220-bdaa-699a6d5b1dbe');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1896-7137-962a-e4cde52f98e2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1897-7321-a816-b4ccf6df566d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1898-71e0-967e-a174de12a36b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1899-7265-8b7c-8096d80232d3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-189a-714d-94a7-5a82e5c5e69c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-189b-7049-9109-78fc69102aed');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-189c-7080-abaf-93441cd9fee5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-189e-72c1-82ec-460348e0d8d2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-189f-7267-b637-77309758a914');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18a0-73c4-9e85-034e61455a48');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18a0-73c4-9e85-034e61c5116a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18a1-71fb-bd86-1c86c6f8bf9b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18a1-71fb-bd86-1c86c7e1cbef');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18a2-7200-9458-e11c4d0f180e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18a3-733f-9590-6cf69f7634e5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18a4-732f-b9fc-52443ae4a4c1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18a5-7259-a1d8-4a03e43eb5c9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18a6-72ea-ae31-249894b83ccf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18a7-712f-9078-20ea227e4115');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18a9-7045-8bfd-a58904db45d6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18aa-7218-87c2-3fb0f2d00951');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ab-7254-9d37-0785e795b4ab');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ac-73bb-b22e-2d857df13ae9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ad-7355-9cba-c65f96120a92');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ae-70a6-955e-e788398681fe');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18af-72f7-be2b-10c85b1072f0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18b0-70dd-bcda-4b3bd6e0191b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18b1-70e4-819f-23a2215692c2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18b1-70e4-819f-23a22204e173');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18b2-71e6-a12c-d89e1bb9fb70');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18b2-71e6-a12c-d89e1ca55b70');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18b3-70f0-8815-2ad9517e0e74');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18b3-70f0-8815-2ad9526489a5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18b4-7320-aa6f-efdae8b65d48');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18b5-729d-911f-5cadefd4548a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18b6-70dc-9a67-198a82d46562');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18b7-721c-b736-ea3c84b24f70');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18b8-73a4-841a-c51ef5ed37fe');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18b9-70cc-9140-e0a955898958');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ba-73d6-922e-62544609d894');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18bc-71fe-996b-2813b2bf71f9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18bd-7319-85a7-a670bf3c7938');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18be-73d9-9795-d91723181a14');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18bf-7234-8765-8d3f9843573a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18bf-7234-8765-8d3f990f2f75');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18c0-7066-bb4e-47d4f86aadcd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18c2-7349-8d5d-f5bf6c2407d0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18c3-72ac-b93b-f883d613f32f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18c4-718a-827a-a9b0957f65a1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18c5-7208-8242-4619c896c419');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18c6-73ef-ae94-2ffd90c9c789');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18c8-70ef-b333-fd53a6340572');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18c9-73ff-897b-8c16687b3f9c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ca-738c-b457-7aabff9fde77');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18cb-73c6-80c7-cd03179a45bf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18cc-71b3-8af2-f3c400b5b7fb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ce-72ca-ba41-5fa945b02d27');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ce-72ca-ba41-5fa94684105f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ce-72ca-ba41-5fa9475aaa2c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18cf-7240-9df5-43e4c3bb122e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18cf-7240-9df5-43e4c3c901f2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18d0-723a-ac52-1d4372ed3838');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18d1-7334-96dc-1cfa188f8fa5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18d1-7334-96dc-1cfa18aa1601');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18d2-70b9-a6f5-303ce19a7fc3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18d2-70b9-a6f5-303ce1a16f45');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18d2-70b9-a6f5-303ce254fb7d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18d3-73d4-ba5c-36027cdcb45d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18d4-73b4-9b10-3d3cf3a2ab80');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18d5-7392-83ec-6ecaa0ba847d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18d6-7356-a2a3-d7395bad470f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18d7-7022-9be0-fe38660dca53');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18d8-719a-9c41-4e574c543e6a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18da-709f-ab5c-beaec2351542');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18db-73da-a12e-d43ccdb51cf1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18dc-70eb-8b8e-a1d32fc30019');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18dd-7092-a744-e6d8e27136b6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18de-719f-9738-3cf7d3e83bad');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e0-70db-8bbd-aca1829c14fd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e1-700f-b8ce-30827199b22f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e1-700f-b8ce-30827242c00f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e2-7327-914d-a6d62aaeb9e0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e2-7327-914d-a6d62b3a0f49');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e3-7250-85ac-18874b9accee');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e3-7250-85ac-18874c31b88a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e3-7250-85ac-18874c5e0a92');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e4-720c-b904-42971e62b394');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e4-720c-b904-42971eeb0e78');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e4-720c-b904-42971f77ce86');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e5-712e-a29e-3ed44670efde');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e6-7059-994f-e9cf64f837f3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e6-7059-994f-e9cf6582315f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e7-706b-a1f9-bbd5bbf165e4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e8-71b4-ba13-0a5594a4aa8c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e8-71b4-ba13-0a5594e105e5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18e9-7235-a79b-ae89f13d6b89');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ea-70fe-8ae9-29f3d63ff41f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18eb-73c9-9f2b-5f83d73fe676');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18eb-73c9-9f2b-5f83d7deb822');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ec-7280-8584-0aa44a8f9e15');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ed-7222-b432-c806a27fb24d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ee-70c3-9977-ef336b000817');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ee-70c3-9977-ef336bbcb78b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ee-70c3-9977-ef336c850b0b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ef-7353-b787-00e5bc3c8746');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ef-7353-b787-00e5bd29ec0b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18f0-71a9-95f7-93247a7a461d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18f1-737f-8342-1fbe545a2c6d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18f2-709c-b3cb-42cff60be159');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18f3-7028-8f99-44c2a337f437');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18f4-7118-9f1b-9702fe46dca2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18f4-7118-9f1b-9702ff0904a3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18f4-7118-9f1b-9702ff4b1bec');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18f5-70c0-a7c4-48d5048cb834');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18f6-72e2-80d6-03b5c3da4f74');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18f6-72e2-80d6-03b5c47888f7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18f7-7360-a386-6dae58aab80f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18f8-731a-bd47-14dcf55f4710');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18f9-71fe-b61c-03d45dbb15b2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18f9-71fe-b61c-03d45e4b74dd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18fb-7266-b00f-2a547ed45911');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18fc-7121-aeab-1bcd1358106e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18fd-723e-8a66-6571e97ed824');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18fe-720a-a2b3-57ff9cb91394');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ff-7246-acc6-938e9d64c86c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-18ff-7246-acc6-938e9e311cdb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1900-73c6-bd18-927b58b83769');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1900-73c6-bd18-927b590f8a37');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1901-7112-b7af-165140e8fa3e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1902-7381-98f6-719aa19e2461');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1903-7233-a8b1-9fb4257c47eb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1904-707d-8493-f8d97a5c253f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1904-707d-8493-f8d97ad8f4b5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1905-73a4-9e70-ae646fb9c4b0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1905-73a4-9e70-ae647078a76d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1906-7279-8a64-da4c47d17f42');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1906-7279-8a64-da4c4868a11d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1907-7210-82bc-b438a048c5cf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1908-7188-8863-c6ce9af1f634');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1909-70bd-b8cd-90b3a982a5c2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-190a-73d2-b371-8ee9f5240d94');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-190a-73d2-b371-8ee9f5a8cd1d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-190a-73d2-b371-8ee9f65c1213');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-190b-73c8-8cf8-9af62677ba32');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-190c-7002-9c3c-4298d8267929');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-190d-7105-8f48-9af4c9ba03b5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-190d-7105-8f48-9af4c9bc4b40');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-190e-720e-9ee2-a69ffd145fa2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-190f-7012-8865-5481f483aba1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-190f-7012-8865-5481f5470d31');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1911-71ed-9c07-1bed3c8b4d6a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1912-73c8-be76-8993e4dd5a9f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1913-721d-ad3c-bfedf419df97');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1913-721d-ad3c-bfedf4a359df');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1914-7373-9c17-2eec06683c94');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1915-715d-a167-108c47f44445');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1915-715d-a167-108c487fcbbd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1916-7154-b089-264d6a0d4407');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1916-7154-b089-264d6a502046');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1918-73c2-9e3a-7746e21b94f4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1919-7311-9b96-b45f61dd8e4c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-191a-72a1-b141-9256a4a8def2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-191a-72a1-b141-9256a50a349c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-191b-737a-a64d-b2d07f7a5c21');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-191b-737a-a64d-b2d07ff73a9a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-191c-7249-90d1-dfdb72cc25df');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-191c-7249-90d1-dfdb7376c64a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-191c-7249-90d1-dfdb73776619');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-191d-70db-b587-20b23664af61');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-191d-70db-b587-20b23731ec48');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-191e-70c2-84ba-6c863f4d0e01');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-191e-70c2-84ba-6c863f67eae8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-191f-7014-9562-0b6c369f2061');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1920-71cb-b470-6316e2772a30');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1921-7389-982c-79e5f28ed05d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1921-7389-982c-79e5f2db7f4b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1922-739c-af76-fc9b6b28cce5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1922-739c-af76-fc9b6b29b492');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1923-73e2-bf59-985547fe0b6d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1924-7190-908a-4e3921c7baed');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1925-70aa-816e-c4da5d39884e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1926-7017-aceb-e79dc0fa3d34');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1928-70bc-a7f3-39e38285bd63');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1929-708f-b131-1cb90e2c254c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-192a-7159-9b01-e60dc7b3cc36');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-192b-7228-9e1f-250a7a16cb71');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-192c-7293-b76a-2d27f0825c42');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-192d-736a-8bed-21b1139918d6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-192e-71cd-beb5-e4b0bed37691');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-192f-7207-904f-13122c326760');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1930-7123-9b78-ba66685058d7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1932-72eb-99ae-02b920ff8de2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1933-7168-a3b5-e7adea2c211d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1935-7374-a477-0e9bcd4d8500');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1936-7056-8a2f-6fc906a617fb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1936-7056-8a2f-6fc906c321c7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1937-71fe-a2de-66de11bd01ed');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1937-71fe-a2de-66de12222e69');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1938-729c-a3b4-0e6e56b006ae');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1939-71df-8779-f76f25a5b9af');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-193a-7393-81bc-12c653d2bc97');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-193a-7393-81bc-12c6541ae547');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-193b-7318-a168-9b66251e9fcc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-193b-7318-a168-9b66255ab539');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-193b-7318-a168-9b6625f32852');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-193c-7158-b772-a5080ec832d1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-193c-7158-b772-a5080f941ff0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-193c-7158-b772-a508105ffdaf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-193c-7158-b772-a508110199c3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-193d-72d0-8ab8-32167cd1c0c5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-193d-72d0-8ab8-32167cfad005');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-193d-72d0-8ab8-32167d0303c3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-193e-70fa-a088-a9c74da0b85b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-193f-7301-ad67-f369da7c2d9f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1940-719c-aa54-1c18f98f9020');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1941-7038-a2b3-dd1590d8dbea');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1942-723b-925c-d7c058ad2bdc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1943-71a8-a889-22f4ba818fb6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1944-72a1-a6dc-0dfc443b4454');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1945-7385-919a-fb0b8d52387d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1946-73ab-9ef6-527ff84be3ec');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1946-73ab-9ef6-527ff8d349e1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1947-7248-9e92-de2f82cf1bcd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1947-7248-9e92-de2f83b1dbf1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1948-7109-9b75-7b00e10cfdf3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1948-7109-9b75-7b00e1603d36');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1948-7109-9b75-7b00e1edb44a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-194a-70d9-945b-ea4c3aa27aa4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-194b-7291-8c40-d65b2afc4e18');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-194c-737a-9b03-677f0273b9b0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-194d-701c-8a21-9bd6264f4eb3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-194f-7187-a9d6-d6d776759f59');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1950-73d7-9584-02503c6564e4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1951-7387-9d18-edcb9b5e9120');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1951-7387-9d18-edcb9c1acbcb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1952-738e-bf95-b1122a80c4d2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1953-73c3-9260-bf55f8850a22');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1954-7027-931b-061de3bc02ef');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1955-73af-bacd-276e2b39c313');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1956-73fc-9da8-8e81e0e0b67f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1957-7107-afc5-a1388db8a8df');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1957-7107-afc5-a1388e025040');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1958-70e1-9571-342a2b080abd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1959-7346-89e9-b0fab0d797f6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-195a-714f-9aee-070a0a7be8f6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-195b-7284-b5db-def46bf93382');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-195c-7080-9b6e-a24e07c375ae');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-195c-7080-9b6e-a24e08584bae');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-195d-70b5-a236-18a488280f6e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-195d-70b5-a236-18a488f59aa2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-195d-70b5-a236-18a4896a6618');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-195f-7210-a906-104af6fc6843');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1960-70cc-be5a-69782149efa0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1962-723b-9d6b-ac38fb27db25');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1962-723b-9d6b-ac38fc076bad');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1963-716f-99dd-bb949b69beb4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1963-716f-99dd-bb949c66fd06');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1964-706f-b72d-b14b3e7c33bf');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1965-732c-89ed-c51683acc9a4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1966-722d-9c65-bdc775659566');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1967-72b1-95f7-0c0c6c01119e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1967-72b1-95f7-0c0c6c7afbad');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1968-705e-bd49-2b389ef8efa9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1969-734f-8036-f8c8b038bc44');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-196a-71cf-9078-01e28273c781');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-196b-73a9-8485-127dbf8784c9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-196b-73a9-8485-127dbf93136e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-196c-73ca-9694-12ff3144ecc4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-196d-7004-a3b5-4cbd8c860f03');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-196d-7004-a3b5-4cbd8cf7921e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-196e-7104-aebc-c323abaa45c2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-196e-7104-aebc-c323ac8b7ee0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-196f-72b3-84e4-de296ebb03d3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1970-7087-a3d2-f2cef76100a6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1970-7087-a3d2-f2cef83d82a7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1971-7102-9df8-24ec4f3b502d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1972-72ae-baee-5148325c3e9e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1972-72ae-baee-514832cecaf2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1973-710b-9927-daf78647945f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1973-710b-9927-daf7872ecf25');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1974-72ad-aaf6-c7621326a9e4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1975-7313-8fa1-cb3a42b39098');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1975-7313-8fa1-cb3a42c7feeb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1976-73f4-81cf-d33fddd39a19');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1976-73f4-81cf-d33fde8b8bcd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1977-7386-b6fe-a3a8df764d37');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1978-70ec-8ece-aca18e48ebc5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1979-7259-926f-a9d2ae1f120c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1979-7259-926f-a9d2ae4531e8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-197a-70fd-a47a-15e295b11d95');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-197a-70fd-a47a-15e2965e7978');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-197a-70fd-a47a-15e29703d3c4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-197b-723b-a000-b072c532f7f0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-197b-723b-a000-b072c5f29cde');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-197c-73f9-8c3b-2a57d6a75b04');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-197c-73f9-8c3b-2a57d72194e5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-197d-7308-82e2-823b30161f91');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-197e-7178-a74e-cd3d70ddc49f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-197f-700f-ae65-3853723a046e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1980-7034-9245-85ffd54d734e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1980-7034-9245-85ffd5971541');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1981-70e0-b10b-4e1b5369ee6d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1982-71a3-8525-226350c65351');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1983-72c0-9b80-2375d453bdc8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1984-7312-82bc-60c8f6143753');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1986-729e-9688-c08d39fcd9e2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1987-7216-8f6b-b0c3960e64c2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1989-71f9-b40f-4fb433ce6975');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1989-71f9-b40f-4fb43444fc51');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-198a-70de-b370-3f6647f5d1b4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-198a-70de-b370-3f66488f23c5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-198b-7383-a6f4-581c3f2ea353');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-198c-7369-baf2-06837de2c46f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-198e-7261-a333-605cab6dad88');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-198f-7080-b141-001027b9e2bc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1990-7263-887e-681b28dbb1fd');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1992-7032-8917-c967a7210a69');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1993-73de-8221-20c12a15db2e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1995-71ba-8817-f01dc5f42400');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1996-7225-9625-f6abad86e0ed');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1998-72c6-be08-3762a00ffa11');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1999-7275-ba82-438b8b32fae3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-1999-7275-ba82-438b8b99f9f8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-199a-71af-a085-38cb760c783a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-199a-71af-a085-38cb76ef71ed');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-199b-7055-9b59-392312d35280');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-199c-73d1-89ef-daa03897ffd4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-199d-71ac-92a8-53ba6d26633e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-199e-7334-899d-49b181dc7c19');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-199e-7334-899d-49b182b3d353');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19a0-716c-adc0-881d611e1fc6');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19a1-703a-a3b3-2d6b3b7df73d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19a3-70b5-93f7-6cf4ef2c491f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19a4-7353-af97-9de5911d0a68');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19a4-7353-af97-9de591c8df3c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19a5-71fc-8c8a-8ed8717bf026');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19a6-725a-8df2-1aa77c446530');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19a7-7061-9fd3-5d0668921540');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19a7-7061-9fd3-5d0668cca2bb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19a8-73bd-adc7-7739845d6343');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19a8-73bd-adc7-7739854f5b33');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19a9-7317-8416-dd8f991c99a5');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19aa-726d-9ffc-da640ca4adb2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19ab-70da-b2de-295131d1022f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19ab-70da-b2de-295131dd7efb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19ac-7047-a209-31801f2127d7');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19ad-7197-bd3a-a4c35f505364');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19ae-700c-9ba8-1c58bb7e256d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19af-704d-a8f2-659c36270ccb');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19af-704d-a8f2-659c369e7936');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19b0-7344-a9b3-261558cb81ee');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19b1-71cb-b108-7ee19301f9e4');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19b1-71cb-b108-7ee19302fb3d');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19b2-71c8-8f68-c6cc546eb612');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19b3-7053-ab22-ef24b5b637c2');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19b5-71f9-a19e-e64a0b22450e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19b6-71f6-9d14-e29da3ef8947');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19b7-72b2-bd01-deeac0282cbe');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19b8-7025-8033-b4506630adce');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19b9-7112-97fc-26d1e37272ca');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19ba-7151-b1c2-e9ecdd9fb248');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19bb-713b-86ef-fe1442c5decc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19bc-705b-8d26-037e03ae3fe3');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19bd-707f-8d46-cfcb29ec528b');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19be-71f3-bedb-33bad6c8eca0');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19c0-719b-ae4c-fd7d9a269c3c');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19c1-71fd-be86-23677b7e22bc');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19c3-71fd-82d6-8d16d027091e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19c4-72cf-9b33-53ab1faf2d33');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19c6-705a-b22e-1e320e14312e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19c7-7046-a23d-2e1432f9fc45');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19c9-70df-8fdd-5a0d8d09031e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19ca-71f2-b4ef-798198d1304e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19cb-7213-b186-8ce6692727c8');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19cc-729c-9ad9-462c2d288fc9');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19cc-729c-9ad9-462c2d3f6c1f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19cd-7259-b8d0-c34d37abd280');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19ce-7320-9aa0-933aa9935c65');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19cf-715c-ae09-0eda61545182');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19d0-71f8-9336-2634f2369b74');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19d1-72bd-a32c-14c90739d746');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19d2-710d-86b8-428cc6a5f79f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19d3-7340-9b4e-b69213abf03e');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19d4-70f1-95a0-90649e8d263a');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19d6-72f8-99d3-2c834619520f');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19d7-71a4-b4d6-799d174b71b1');
INSERT INTO "role_permissions" ("role_id", "permission_id") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', '01a18639-19d8-734d-85e7-81e6bfba3c17');

DROP TABLE IF EXISTS "roles";
CREATE TABLE "roles" ("id" varchar not null, "tenant_id" varchar, "name" varchar not null, "slug" varchar not null, "is_system" tinyint(1) not null default '0', "created_at" datetime, "updated_at" datetime, foreign key("tenant_id") references "tenants"("id") on delete cascade, primary key ("id"));

INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a18639-19dc-7248-9fc3-b0e484d50d97', NULL, 'Super Admin', 'super_admin', 1, '2026-10-29 05:54:11', '2026-10-29 05:54:11');

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

INSERT INTO "user_roles" ("id", "user_id", "role_id", "branch_id", "store_id", "created_at", "updated_at") VALUES ('01a18639-1a22-7397-a2fb-c484dde1387e', '01a18639-1a1f-70fa-991e-1b43be9d5767', '01a18639-19dc-7248-9fc3-b0e484d50d97', NULL, NULL, '2026-10-29 05:54:11', '2026-10-29 05:54:11');

DROP TABLE IF EXISTS "users";
CREATE TABLE "users" ("id" varchar not null, "name" varchar not null, "email" varchar not null, "email_verified_at" datetime, "password" varchar not null, "phone" varchar, "pin" varchar, "is_active" tinyint(1) not null default ('1'), "remember_token" varchar, "created_at" datetime, "updated_at" datetime, "tenant_id" varchar, "api_token" varchar, "two_factor_secret" text, "two_factor_confirmed_at" datetime, "two_factor_recovery_codes" text, "phone_verified_at" datetime, "party_id" varchar, foreign key("tenant_id") references tenants("id") on delete set null on update no action, foreign key("party_id") references "parties"("id") on delete set null, primary key ("id"));

INSERT INTO "users" ("id", "name", "email", "email_verified_at", "password", "phone", "pin", "is_active", "remember_token", "created_at", "updated_at", "tenant_id", "api_token", "two_factor_secret", "two_factor_confirmed_at", "two_factor_recovery_codes", "phone_verified_at", "party_id") VALUES ('01a18639-1a1f-70fa-991e-1b43be9d5767', 'Platform Backup', 'platform-backup@test.local', NULL, '$2y$04$FQEDabXALdKfVmivntjFLud8sRNBtDzLduWl0wstYd3QqwJFjs1FC', NULL, NULL, 1, NULL, '2026-10-29 05:54:11', '2026-10-29 05:54:11', NULL, NULL, NULL, NULL, NULL, NULL, NULL);

DROP TABLE IF EXISTS "warehouses";
CREATE TABLE "warehouses" ("id" varchar not null, "tenant_id" varchar not null, "branch_id" varchar not null, "name" varchar not null, "code" varchar not null, "is_active" tinyint(1) not null default ('1'), "created_at" datetime, "updated_at" datetime, "deleted_at" datetime, "location_id" varchar, "store_id" varchar, foreign key("location_id") references locations("id") on delete set null on update no action, foreign key("tenant_id") references tenants("id") on delete cascade on update no action, foreign key("branch_id") references branches("id") on delete cascade on update no action, foreign key("store_id") references "stores"("id") on delete set null, primary key ("id"));


COMMIT;
PRAGMA foreign_keys=ON;
