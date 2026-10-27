-- ITARA-POS tenant backup
-- tenant_id: 01a17cc4-0933-70e0-9fdd-b874257da8cc
-- driver: sqlite
-- created: 2026-10-27T09:49:45+00:00
-- scope: tenant

PRAGMA foreign_keys=OFF;
BEGIN;

DELETE FROM "user_roles" WHERE "user_id" IN ('01a17cc4-098e-71cb-8fd2-f6d79de12457');
INSERT INTO "user_roles" ("id", "user_id", "role_id", "branch_id", "store_id", "created_at", "updated_at") VALUES ('01a17cc4-0991-73c5-ae73-b6b298394b39', '01a17cc4-098e-71cb-8fd2-f6d79de12457', '01a17cc4-0951-708e-8348-e65edde41e05', NULL, NULL, '2026-10-27 09:49:44', '2026-10-27 09:49:44');

DELETE FROM "accounting_entries" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "audit_logs" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "barcodes" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "batches" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "branch_expenses" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "branches" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';
INSERT INTO "branches" ("id", "tenant_id", "company_id", "name", "code", "address", "is_active", "created_at", "updated_at", "deleted_at", "settings", "location_id") VALUES ('01a17cc4-09a1-703e-a8ba-2b647840f336', '01a17cc4-0933-70e0-9fdd-b874257da8cc', '01a17cc4-0997-700c-a2c1-79d721233e02', 'Branch', 'ALPHA-BAK', NULL, 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44', NULL, NULL, NULL);

DELETE FROM "brands" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "business_documents" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "cash_movements" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "cash_register_sessions" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "cash_registers" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "cashier_shifts" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "catalog_attributes" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "catalogs" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';
INSERT INTO "catalogs" ("id", "tenant_id", "company_id", "name", "description", "is_default", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc4-099e-7147-8098-0d15562e6a55', '01a17cc4-0933-70e0-9fdd-b874257da8cc', '01a17cc4-0997-700c-a2c1-79d721233e02', 'Catalogue', NULL, 1, 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44', NULL, NULL);

DELETE FROM "categories" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "companies" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';
INSERT INTO "companies" ("id", "tenant_id", "name", "legal_name", "tax_id", "currency_code", "address", "settings", "is_active", "created_at", "updated_at", "deleted_at", "trade_name", "legal_form", "registration_number", "phone", "email", "website", "logo_url", "locale", "timezone", "party_id") VALUES ('01a17cc4-0997-700c-a2c1-79d721233e02', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'Company alpha-bak', NULL, NULL, 'FBU', NULL, NULL, 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'fr', 'Africa/Bujumbura', NULL);

DELETE FROM "company_payment_methods" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "crm_accounts" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "crm_activities" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "crm_campaign_members" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "crm_campaigns" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "crm_leads" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "crm_opportunities" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "crm_pipeline_stages" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "currencies" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';
INSERT INTO "currencies" ("id", "tenant_id", "code", "name", "symbol", "decimal_places", "exchange_rate", "is_default", "is_active", "created_at", "updated_at", "deleted_at") VALUES ('01a17cc4-099d-7083-8642-52b65962a315', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'FBU', 'Franc Burundais', 'FBu', 0, 1, 1, 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44', NULL);

DELETE FROM "currency_exchange_rates" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "customer_addresses" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "customer_payments" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "customer_transactions" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "customers" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';
INSERT INTO "customers" ("id", "tenant_id", "name", "email", "phone", "is_active", "created_at", "updated_at", "deleted_at", "code", "company_name", "tax_id", "date_of_birth", "gender", "credit_limit", "payment_terms_days", "loyalty_points", "loyalty_tier", "notes", "metadata", "crm_role", "job_title", "crm_account_id", "party_id") VALUES ('01a17cc4-09be-73bf-ae24-7a582a442f2e', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'Customer alpha-bak', 'customer-alpha-bak@test.local', NULL, 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44', NULL, 'CLI-0001', NULL, NULL, NULL, NULL, NULL, 0, 0, 'standard', NULL, NULL, 'client', NULL, NULL, NULL);

DELETE FROM "desk_documents" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "devices" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "employees" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "expense_categories" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "gallery_images" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "goods_receipt_items" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "goods_receipts" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "inbox_notifications" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "inventory_alerts" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "inventory_count_items" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "inventory_counts" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "inventory_movements" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "inventory_verification_findings" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "inventory_verification_plans" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "inventory_verification_runs" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "locations" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "merchant_qr_codes" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "notification_channel_settings" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "notification_deliveries" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "notification_preferences" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "numbering_rules" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "numbering_sequences" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "offline_transactions" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "parties" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "party_contexts" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "payment_transactions" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "platform_audit_logs" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "pos_reservations" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "pos_table_events" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "pos_table_zones" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "pos_tables" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "prices" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "product_accompaniment_links" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "product_bundle_items" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "product_images" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "product_sale_units" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "product_variants" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "products" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';
INSERT INTO "products" ("id", "tenant_id", "catalog_id", "category_id", "sku", "name", "description", "barcode", "unit", "base_price", "cost_price", "is_active", "metadata", "created_at", "updated_at", "deleted_at", "product_type", "brand_id", "unit_id", "tax_id", "is_serialized", "track_batch", "track_expiration", "expiration_days", "low_stock_threshold", "bottle_volume_ml", "inventory_class", "count_frequency", "last_counted_at", "next_count_at", "accompaniment_enabled", "tax_class_id") VALUES ('01a17cc4-09bb-7347-a329-cf648d8c6f5d', '01a17cc4-0933-70e0-9fdd-b874257da8cc', '01a17cc4-099e-7147-8098-0d15562e6a55', NULL, 'ALPHA-BAK-001', 'Product alpha-bak', NULL, NULL, 'piece', 1000, 0, 1, NULL, '2026-10-27 09:49:44', '2026-10-27 09:49:44', NULL, 'simple', NULL, NULL, NULL, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL);

DELETE FROM "promotions" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "purchase_invoices" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "purchase_order_items" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "purchase_orders" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "purchase_payments" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "purchase_proforma_items" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "purchase_proformas" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "purchase_requisition_items" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "purchase_requisitions" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "purchases" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "push_subscriptions" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "qr_order_items" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "qr_orders" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "qr_table_sessions" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "realtime_outbox" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc4-09b4-703e-8f17-18dda6e7cf11', '01a17cc4-0933-70e0-9fdd-b874257da8cc', '01a17cc4-09a1-703e-a8ba-2b6478820d82', NULL, 'unit.created', 'unit', '01a17cc4-09a3-7383-974d-cad03b89bd6d', NULL, '{"code":"piece","name":"Pi\u00e8ce","symbol":"pc"}', '2026-10-27 09:49:44', NULL, '2026-10-27 09:49:44', '2026-10-27 09:49:44');
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc4-09b5-70ca-99cc-4a6772189030', '01a17cc4-0933-70e0-9fdd-b874257da8cc', '01a17cc4-09a1-703e-a8ba-2b6478820d82', NULL, 'unit.created', 'unit', '01a17cc4-09b5-70ca-99cc-4a67711b5289', NULL, '{"code":"kg","name":"Kilogramme","symbol":"kg"}', '2026-10-27 09:49:44', NULL, '2026-10-27 09:49:44', '2026-10-27 09:49:44');
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc4-09b6-739c-a931-7b3d47fb14cd', '01a17cc4-0933-70e0-9fdd-b874257da8cc', '01a17cc4-09a1-703e-a8ba-2b6478820d82', NULL, 'unit.created', 'unit', '01a17cc4-09b6-739c-a931-7b3d47f17bfd', NULL, '{"code":"g","name":"Gramme","symbol":"g"}', '2026-10-27 09:49:44', NULL, '2026-10-27 09:49:44', '2026-10-27 09:49:44');
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc4-09b7-738c-8c7e-fb06545a04ce', '01a17cc4-0933-70e0-9fdd-b874257da8cc', '01a17cc4-09a1-703e-a8ba-2b6478820d82', NULL, 'unit.created', 'unit', '01a17cc4-09b7-738c-8c7e-fb06543ed69c', NULL, '{"code":"L","name":"Litre","symbol":"L"}', '2026-10-27 09:49:44', NULL, '2026-10-27 09:49:44', '2026-10-27 09:49:44');
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc4-09b8-7115-9842-ecf10229b5ab', '01a17cc4-0933-70e0-9fdd-b874257da8cc', '01a17cc4-09a1-703e-a8ba-2b6478820d82', NULL, 'unit.created', 'unit', '01a17cc4-09b8-7115-9842-ecf101ac5e5f', NULL, '{"code":"h","name":"Heure","symbol":"h"}', '2026-10-27 09:49:44', NULL, '2026-10-27 09:49:44', '2026-10-27 09:49:44');
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc4-09bc-7348-bc7a-b31a636beb59', '01a17cc4-0933-70e0-9fdd-b874257da8cc', NULL, NULL, 'product.created', 'product', '01a17cc4-09bb-7347-a329-cf648d8c6f5d', NULL, '{"name":"Product alpha-bak","sku":"ALPHA-BAK-001","base_price":1000,"is_active":true}', '2026-10-27 09:49:44', NULL, '2026-10-27 09:49:44', '2026-10-27 09:49:44');

DELETE FROM "roles" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-0935-7362-a92b-091311fe3a73', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'Company Owner', 'company_owner', 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-0951-708e-8348-e65edde41e05', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'Admin', 'administrator', 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-0969-714d-8b89-d5dd34acb5b7', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'Branch Manager', 'branch_manager', 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-0970-7245-bdbb-79794c56f3ad', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'Store Manager', 'store_manager', 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-0973-705d-bbce-d202801a961f', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'Caissier', 'cashier', 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-0975-73f0-8b21-d7e7ccd7cdbf', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'Stock Manager', 'inventory_manager', 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-0977-73bd-9067-fe333a3b0134', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'Manager', 'manager', 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-0979-7167-afdb-3754a44befb0', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'Comptable', 'accountant', 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-097a-72ab-9c83-4d0b019db273', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'Serveur', 'serveur', 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-097b-713d-adc8-c015276d8ab7', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'Réceptionniste', 'receptionist', 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-097c-72ad-9996-db179defc7f8', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'Sales Agent', 'sales_agent', 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-097f-7311-908e-2881df090951', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'Auditor', 'auditor', 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44');

DELETE FROM "saas_invoices" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "saas_payments" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "saas_subscription_events" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "saas_subscriptions" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "sale_discounts" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "sale_installments" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "sale_invoices" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "sale_items" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "sale_payments" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "sale_receipts" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "sale_refunds" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "sale_return_items" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "sale_returns" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "sale_taxes" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "sales" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "serial_numbers" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "service_appointments" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "service_offerings" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "stock_adjustment_items" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "stock_adjustments" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "stock_balances" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "stock_transfer_items" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "stock_transfers" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "store_products" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "stores" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';
INSERT INTO "stores" ("id", "tenant_id", "branch_id", "name", "code", "is_active", "created_at", "updated_at", "deleted_at", "kind", "location_id", "is_main", "qr_approval_mode") VALUES ('01a17cc4-09a1-703e-a8ba-2b6478820d82', '01a17cc4-0933-70e0-9fdd-b874257da8cc', '01a17cc4-09a1-703e-a8ba-2b647840f336', 'Store', 'ALPHA-BAK01', 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44', NULL, 'store', NULL, 0, 'manual');

DELETE FROM "supplier_contacts" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "supplier_payments" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "supplier_transactions" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "suppliers" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';
INSERT INTO "suppliers" ("id", "tenant_id", "name", "code", "email", "phone", "is_active", "created_at", "updated_at", "deleted_at", "legal_name", "tax_id", "address", "payment_terms_days", "credit_limit", "currency_code", "notes", "metadata", "party_id") VALUES ('01a17cc4-09c1-731d-915a-d7c657ec77f6', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'Supplier alpha-bak', 'ALPHA-BAK-SUP', NULL, NULL, 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44', NULL, NULL, NULL, NULL, 30, NULL, 'USD', NULL, NULL, NULL);

DELETE FROM "sync_events" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "sync_failures" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "table_qr_tokens" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "tax_classes" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "tax_groups" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "tax_rules" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "taxes" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "transactions" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';

DELETE FROM "units" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';
INSERT INTO "units" ("id", "tenant_id", "code", "name", "symbol", "is_fractional", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc4-09a3-7383-974d-cad03b89bd6d', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'piece', 'Pièce', 'pc', 0, 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44', NULL, '01a17cc4-09a1-703e-a8ba-2b6478820d82');
INSERT INTO "units" ("id", "tenant_id", "code", "name", "symbol", "is_fractional", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc4-09b5-70ca-99cc-4a67711b5289', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'kg', 'Kilogramme', 'kg', 1, 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44', NULL, '01a17cc4-09a1-703e-a8ba-2b6478820d82');
INSERT INTO "units" ("id", "tenant_id", "code", "name", "symbol", "is_fractional", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc4-09b6-739c-a931-7b3d47f17bfd', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'g', 'Gramme', 'g', 1, 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44', NULL, '01a17cc4-09a1-703e-a8ba-2b6478820d82');
INSERT INTO "units" ("id", "tenant_id", "code", "name", "symbol", "is_fractional", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc4-09b7-738c-8c7e-fb06543ed69c', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'L', 'Litre', 'L', 1, 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44', NULL, '01a17cc4-09a1-703e-a8ba-2b6478820d82');
INSERT INTO "units" ("id", "tenant_id", "code", "name", "symbol", "is_fractional", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc4-09b8-7115-9842-ecf101ac5e5f', '01a17cc4-0933-70e0-9fdd-b874257da8cc', 'h', 'Heure', 'h', 1, 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44', NULL, '01a17cc4-09a1-703e-a8ba-2b6478820d82');

DELETE FROM "users" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';
INSERT INTO "users" ("id", "name", "email", "email_verified_at", "password", "phone", "pin", "is_active", "remember_token", "created_at", "updated_at", "tenant_id", "api_token", "two_factor_secret", "two_factor_confirmed_at", "two_factor_recovery_codes", "phone_verified_at", "party_id") VALUES ('01a17cc4-098e-71cb-8fd2-f6d79de12457', 'User alpha-bak', 'alpha-bak@test.local', '2026-10-27 09:49:44', '$2y$04$yit8MeAS6UFlI8VFwjaZ.OtNF7dTUw5NqF.xma78HcfWQZodvzkIO', NULL, NULL, 1, NULL, '2026-10-27 09:49:44', '2026-10-27 09:49:44', '01a17cc4-0933-70e0-9fdd-b874257da8cc', NULL, NULL, NULL, NULL, NULL, NULL);

DELETE FROM "warehouses" WHERE "tenant_id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';
INSERT INTO "warehouses" ("id", "tenant_id", "branch_id", "name", "code", "is_active", "created_at", "updated_at", "deleted_at", "location_id") VALUES ('01a17cc4-09ba-73c0-ab12-5e9fb0f3ca13', '01a17cc4-0933-70e0-9fdd-b874257da8cc', '01a17cc4-09a1-703e-a8ba-2b647840f336', 'Warehouse', 'ALPHA-BAK-WH', 1, '2026-10-27 09:49:44', '2026-10-27 09:49:44', NULL, NULL);

DELETE FROM "tenants" WHERE "id" = '01a17cc4-0933-70e0-9fdd-b874257da8cc';
INSERT INTO "tenants" ("id", "name", "slug", "status", "settings", "created_at", "updated_at", "deleted_at", "legal_name", "trade_name", "logo_url", "address", "phone", "email", "website", "country_code", "currency_code", "timezone", "locale", "tax_regime", "tax_id", "registration_number", "subscription") VALUES ('01a17cc4-0933-70e0-9fdd-b874257da8cc', 'Tenant alpha-bak', 'alpha-bak', 'active', NULL, '2026-10-27 09:49:44', '2026-10-27 09:49:44', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'BI', 'FBU', 'Africa/Bujumbura', 'fr', NULL, NULL, NULL, NULL);

COMMIT;
PRAGMA foreign_keys=ON;
