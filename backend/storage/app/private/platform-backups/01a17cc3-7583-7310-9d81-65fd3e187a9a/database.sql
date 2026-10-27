-- ITARA-POS tenant backup
-- tenant_id: 01a17cc3-7305-733f-a2db-b0a5627c0f8f
-- driver: sqlite
-- created: 2026-10-27T09:49:06+00:00
-- scope: tenant

PRAGMA foreign_keys=OFF;
BEGIN;

DELETE FROM "user_roles" WHERE "user_id" IN ('01a17cc3-7392-714f-b58a-c7516da2c45f');
INSERT INTO "user_roles" ("id", "user_id", "role_id", "branch_id", "store_id", "created_at", "updated_at") VALUES ('01a17cc3-7394-73ab-aac3-92527d6a8301', '01a17cc3-7392-714f-b58a-c7516da2c45f', '01a17cc3-733b-707f-bdb7-d3d57c167aab', NULL, NULL, '2026-10-27 09:49:06', '2026-10-27 09:49:06');

DELETE FROM "accounting_entries" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "audit_logs" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "barcodes" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "batches" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "branch_expenses" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "branches" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';
INSERT INTO "branches" ("id", "tenant_id", "company_id", "name", "code", "address", "is_active", "created_at", "updated_at", "deleted_at", "settings", "location_id") VALUES ('01a17cc3-739e-7226-8abc-28605be73ff6', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', '01a17cc3-7399-7300-8646-a583f88ae185', 'Branch', 'ALPHA-BAK', NULL, 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06', NULL, NULL, NULL);

DELETE FROM "brands" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "business_documents" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "cash_movements" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "cash_register_sessions" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "cash_registers" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "cashier_shifts" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "catalog_attributes" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "catalogs" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';
INSERT INTO "catalogs" ("id", "tenant_id", "company_id", "name", "description", "is_default", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc3-739d-730b-b8db-b1695f15dab6', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', '01a17cc3-7399-7300-8646-a583f88ae185', 'Catalogue', NULL, 1, 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06', NULL, NULL);

DELETE FROM "categories" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "companies" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';
INSERT INTO "companies" ("id", "tenant_id", "name", "legal_name", "tax_id", "currency_code", "address", "settings", "is_active", "created_at", "updated_at", "deleted_at", "trade_name", "legal_form", "registration_number", "phone", "email", "website", "logo_url", "locale", "timezone", "party_id") VALUES ('01a17cc3-7399-7300-8646-a583f88ae185', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'Company alpha-bak', NULL, NULL, 'FBU', NULL, NULL, 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'fr', 'Africa/Bujumbura', NULL);

DELETE FROM "company_payment_methods" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "crm_accounts" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "crm_activities" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "crm_campaign_members" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "crm_campaigns" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "crm_leads" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "crm_opportunities" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "crm_pipeline_stages" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "currencies" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';
INSERT INTO "currencies" ("id", "tenant_id", "code", "name", "symbol", "decimal_places", "exchange_rate", "is_default", "is_active", "created_at", "updated_at", "deleted_at") VALUES ('01a17cc3-739b-739f-88ee-477ba7c68f97', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'FBU', 'Franc Burundais', 'FBu', 0, 1, 1, 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06', NULL);

DELETE FROM "currency_exchange_rates" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "customer_addresses" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "customer_payments" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "customer_transactions" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "customers" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';
INSERT INTO "customers" ("id", "tenant_id", "name", "email", "phone", "is_active", "created_at", "updated_at", "deleted_at", "code", "company_name", "tax_id", "date_of_birth", "gender", "credit_limit", "payment_terms_days", "loyalty_points", "loyalty_tier", "notes", "metadata", "crm_role", "job_title", "crm_account_id", "party_id") VALUES ('01a17cc3-73ad-7292-af55-dca281771497', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'Customer alpha-bak', 'customer-alpha-bak@test.local', NULL, 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06', NULL, 'CLI-0001', NULL, NULL, NULL, NULL, NULL, 0, 0, 'standard', NULL, NULL, 'client', NULL, NULL, NULL);

DELETE FROM "desk_documents" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "devices" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "employees" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "expense_categories" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "gallery_images" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "goods_receipt_items" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "goods_receipts" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "inbox_notifications" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "inventory_alerts" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "inventory_count_items" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "inventory_counts" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "inventory_movements" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "inventory_verification_findings" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "inventory_verification_plans" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "inventory_verification_runs" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "locations" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "merchant_qr_codes" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "notification_channel_settings" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "notification_deliveries" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "notification_preferences" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "numbering_rules" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "numbering_sequences" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "offline_transactions" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "parties" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "party_contexts" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "payment_transactions" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "platform_audit_logs" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "pos_reservations" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "pos_table_events" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "pos_table_zones" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "pos_tables" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "prices" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "product_accompaniment_links" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "product_bundle_items" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "product_images" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "product_sale_units" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "product_variants" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "products" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';
INSERT INTO "products" ("id", "tenant_id", "catalog_id", "category_id", "sku", "name", "description", "barcode", "unit", "base_price", "cost_price", "is_active", "metadata", "created_at", "updated_at", "deleted_at", "product_type", "brand_id", "unit_id", "tax_id", "is_serialized", "track_batch", "track_expiration", "expiration_days", "low_stock_threshold", "bottle_volume_ml", "inventory_class", "count_frequency", "last_counted_at", "next_count_at", "accompaniment_enabled", "tax_class_id") VALUES ('01a17cc3-73aa-7055-b244-1a6216873043', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', '01a17cc3-739d-730b-b8db-b1695f15dab6', NULL, 'ALPHA-BAK-001', 'Product alpha-bak', NULL, NULL, 'piece', 1000, 0, 1, NULL, '2026-10-27 09:49:06', '2026-10-27 09:49:06', NULL, 'simple', NULL, NULL, NULL, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL);

DELETE FROM "promotions" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "purchase_invoices" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "purchase_order_items" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "purchase_orders" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "purchase_payments" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "purchase_proforma_items" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "purchase_proformas" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "purchase_requisition_items" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "purchase_requisitions" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "purchases" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "push_subscriptions" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "qr_order_items" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "qr_orders" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "qr_table_sessions" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "realtime_outbox" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc3-73a1-7310-b01c-42daea79ff27', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', '01a17cc3-739f-7022-b259-943336f137c6', NULL, 'unit.created', 'unit', '01a17cc3-73a0-72db-995f-9aa8637cd8b2', NULL, '{"code":"piece","name":"Pi\u00e8ce","symbol":"pc"}', '2026-10-27 09:49:06', NULL, '2026-10-27 09:49:06', '2026-10-27 09:49:06');
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc3-73a3-7393-9e4f-f3b75aa68deb', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', '01a17cc3-739f-7022-b259-943336f137c6', NULL, 'unit.created', 'unit', '01a17cc3-73a2-72a7-aa47-cc397dcf44dd', NULL, '{"code":"kg","name":"Kilogramme","symbol":"kg"}', '2026-10-27 09:49:06', NULL, '2026-10-27 09:49:06', '2026-10-27 09:49:06');
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc3-73a5-733c-8315-097476e69e8e', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', '01a17cc3-739f-7022-b259-943336f137c6', NULL, 'unit.created', 'unit', '01a17cc3-73a4-73e7-bbfc-8b241219d52c', NULL, '{"code":"g","name":"Gramme","symbol":"g"}', '2026-10-27 09:49:06', NULL, '2026-10-27 09:49:06', '2026-10-27 09:49:06');
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc3-73a6-72ed-9f7a-8ef525165b8c', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', '01a17cc3-739f-7022-b259-943336f137c6', NULL, 'unit.created', 'unit', '01a17cc3-73a6-72ed-9f7a-8ef5245a7b61', NULL, '{"code":"L","name":"Litre","symbol":"L"}', '2026-10-27 09:49:06', NULL, '2026-10-27 09:49:06', '2026-10-27 09:49:06');
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc3-73a8-7340-ba1c-7fe897a0bf9e', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', '01a17cc3-739f-7022-b259-943336f137c6', NULL, 'unit.created', 'unit', '01a17cc3-73a8-7340-ba1c-7fe896d6b97b', NULL, '{"code":"h","name":"Heure","symbol":"h"}', '2026-10-27 09:49:06', NULL, '2026-10-27 09:49:06', '2026-10-27 09:49:06');
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc3-73ab-730c-973a-1c911a71c1ce', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', NULL, NULL, 'product.created', 'product', '01a17cc3-73aa-7055-b244-1a6216873043', NULL, '{"name":"Product alpha-bak","sku":"ALPHA-BAK-001","base_price":1000,"is_active":true}', '2026-10-27 09:49:06', NULL, '2026-10-27 09:49:06', '2026-10-27 09:49:06');

DELETE FROM "roles" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc3-730c-70b2-a002-8e83e135c0d5', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'Company Owner', 'company_owner', 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc3-733b-707f-bdb7-d3d57c167aab', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'Admin', 'administrator', 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc3-7369-717c-81ec-a3ce8536622b', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'Branch Manager', 'branch_manager', 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc3-7370-7360-9d6b-460bc3b2c77d', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'Store Manager', 'store_manager', 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc3-7374-7186-8165-c8f5fc9765bf', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'Caissier', 'cashier', 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc3-7377-71c2-9fb8-9b5aae640f30', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'Stock Manager', 'inventory_manager', 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc3-737d-739d-bd2c-d9ad2844037b', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'Manager', 'manager', 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc3-7381-71f4-9b9b-50b8bb5f757f', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'Comptable', 'accountant', 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc3-7384-7004-8d97-e3fc69114e00', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'Serveur', 'serveur', 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc3-7387-72f1-9886-91cf5ea8b61a', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'Réceptionniste', 'receptionist', 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc3-7388-7030-97eb-075c77870b7b', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'Sales Agent', 'sales_agent', 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc3-738d-718d-89f0-93c611f9406a', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'Auditor', 'auditor', 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06');

DELETE FROM "saas_invoices" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "saas_payments" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "saas_subscription_events" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "saas_subscriptions" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "sale_discounts" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "sale_installments" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "sale_invoices" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "sale_items" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "sale_payments" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "sale_receipts" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "sale_refunds" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "sale_return_items" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "sale_returns" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "sale_taxes" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "sales" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "serial_numbers" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "service_appointments" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "service_offerings" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "stock_adjustment_items" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "stock_adjustments" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "stock_balances" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "stock_transfer_items" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "stock_transfers" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "store_products" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "stores" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';
INSERT INTO "stores" ("id", "tenant_id", "branch_id", "name", "code", "is_active", "created_at", "updated_at", "deleted_at", "kind", "location_id", "is_main", "qr_approval_mode") VALUES ('01a17cc3-739f-7022-b259-943336f137c6', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', '01a17cc3-739e-7226-8abc-28605be73ff6', 'Store', 'ALPHA-BAK01', 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06', NULL, 'store', NULL, 0, 'manual');

DELETE FROM "supplier_contacts" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "supplier_payments" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "supplier_transactions" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "suppliers" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';
INSERT INTO "suppliers" ("id", "tenant_id", "name", "code", "email", "phone", "is_active", "created_at", "updated_at", "deleted_at", "legal_name", "tax_id", "address", "payment_terms_days", "credit_limit", "currency_code", "notes", "metadata", "party_id") VALUES ('01a17cc3-73ae-718a-af92-a13f62d8de52', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'Supplier alpha-bak', 'ALPHA-BAK-SUP', NULL, NULL, 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06', NULL, NULL, NULL, NULL, 30, NULL, 'USD', NULL, NULL, NULL);

DELETE FROM "sync_events" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "sync_failures" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "table_qr_tokens" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "tax_classes" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "tax_groups" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "tax_rules" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "taxes" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "transactions" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';

DELETE FROM "units" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';
INSERT INTO "units" ("id", "tenant_id", "code", "name", "symbol", "is_fractional", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc3-73a0-72db-995f-9aa8637cd8b2', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'piece', 'Pièce', 'pc', 0, 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06', NULL, '01a17cc3-739f-7022-b259-943336f137c6');
INSERT INTO "units" ("id", "tenant_id", "code", "name", "symbol", "is_fractional", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc3-73a2-72a7-aa47-cc397dcf44dd', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'kg', 'Kilogramme', 'kg', 1, 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06', NULL, '01a17cc3-739f-7022-b259-943336f137c6');
INSERT INTO "units" ("id", "tenant_id", "code", "name", "symbol", "is_fractional", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc3-73a4-73e7-bbfc-8b241219d52c', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'g', 'Gramme', 'g', 1, 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06', NULL, '01a17cc3-739f-7022-b259-943336f137c6');
INSERT INTO "units" ("id", "tenant_id", "code", "name", "symbol", "is_fractional", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc3-73a6-72ed-9f7a-8ef5245a7b61', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'L', 'Litre', 'L', 1, 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06', NULL, '01a17cc3-739f-7022-b259-943336f137c6');
INSERT INTO "units" ("id", "tenant_id", "code", "name", "symbol", "is_fractional", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc3-73a8-7340-ba1c-7fe896d6b97b', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'h', 'Heure', 'h', 1, 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06', NULL, '01a17cc3-739f-7022-b259-943336f137c6');

DELETE FROM "users" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';
INSERT INTO "users" ("id", "name", "email", "email_verified_at", "password", "phone", "pin", "is_active", "remember_token", "created_at", "updated_at", "tenant_id", "api_token", "two_factor_secret", "two_factor_confirmed_at", "two_factor_recovery_codes", "phone_verified_at", "party_id") VALUES ('01a17cc3-7392-714f-b58a-c7516da2c45f', 'User alpha-bak', 'alpha-bak@test.local', '2026-10-27 09:49:06', '$2y$04$g9sthLJOACZS6d9I8XgyTuDHkqbTUoCQEjqegbPKgCDnsD3msrjnq', NULL, NULL, 1, NULL, '2026-10-27 09:49:06', '2026-10-27 09:49:06', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', NULL, NULL, NULL, NULL, NULL, NULL);

DELETE FROM "warehouses" WHERE "tenant_id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';
INSERT INTO "warehouses" ("id", "tenant_id", "branch_id", "name", "code", "is_active", "created_at", "updated_at", "deleted_at", "location_id") VALUES ('01a17cc3-73a9-7181-999e-5218fa0ae750', '01a17cc3-7305-733f-a2db-b0a5627c0f8f', '01a17cc3-739e-7226-8abc-28605be73ff6', 'Warehouse', 'ALPHA-BAK-WH', 1, '2026-10-27 09:49:06', '2026-10-27 09:49:06', NULL, NULL);

DELETE FROM "tenants" WHERE "id" = '01a17cc3-7305-733f-a2db-b0a5627c0f8f';
INSERT INTO "tenants" ("id", "name", "slug", "status", "settings", "created_at", "updated_at", "deleted_at", "legal_name", "trade_name", "logo_url", "address", "phone", "email", "website", "country_code", "currency_code", "timezone", "locale", "tax_regime", "tax_id", "registration_number", "subscription") VALUES ('01a17cc3-7305-733f-a2db-b0a5627c0f8f', 'Tenant alpha-bak', 'alpha-bak', 'active', NULL, '2026-10-27 09:49:06', '2026-10-27 09:49:06', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'BI', 'FBU', 'Africa/Bujumbura', 'fr', NULL, NULL, NULL, NULL);

COMMIT;
PRAGMA foreign_keys=ON;
