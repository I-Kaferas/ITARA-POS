-- ITARA-POS tenant backup
-- tenant_id: 01a17cc4-c32c-72a9-a943-6474c7bb96bc
-- driver: sqlite
-- created: 2026-10-27T09:50:34+00:00
-- scope: tenant

PRAGMA foreign_keys=OFF;
BEGIN;

DELETE FROM "user_roles" WHERE "user_id" IN ('01a17cc4-c5c8-734a-8fd6-31f3a846589b');
INSERT INTO "user_roles" ("id", "user_id", "role_id", "branch_id", "store_id", "created_at", "updated_at") VALUES ('01a17cc4-c5cb-7196-9a12-d0062fb30516', '01a17cc4-c5c8-734a-8fd6-31f3a846589b', '01a17cc4-c399-7089-b41e-f345d0b45566', NULL, NULL, '2026-10-27 09:50:32', '2026-10-27 09:50:32');

DELETE FROM "accounting_entries" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "audit_logs" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "barcodes" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "batches" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "branch_expenses" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "branches" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';
INSERT INTO "branches" ("id", "tenant_id", "company_id", "name", "code", "address", "is_active", "created_at", "updated_at", "deleted_at", "settings", "location_id") VALUES ('01a17cc4-c5e5-7109-a795-e4890b0c92ff', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', '01a17cc4-c5d5-73de-aa21-5aaccead92f0', 'Branch', 'ALPHA-BAK', NULL, 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32', NULL, NULL, NULL);

DELETE FROM "brands" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "business_documents" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "cash_movements" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "cash_register_sessions" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "cash_registers" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "cashier_shifts" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "catalog_attributes" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "catalogs" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';
INSERT INTO "catalogs" ("id", "tenant_id", "company_id", "name", "description", "is_default", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc4-c5e2-729a-aa97-c0c786d3e374', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', '01a17cc4-c5d5-73de-aa21-5aaccead92f0', 'Catalogue', NULL, 1, 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32', NULL, NULL);

DELETE FROM "categories" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "companies" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';
INSERT INTO "companies" ("id", "tenant_id", "name", "legal_name", "tax_id", "currency_code", "address", "settings", "is_active", "created_at", "updated_at", "deleted_at", "trade_name", "legal_form", "registration_number", "phone", "email", "website", "logo_url", "locale", "timezone", "party_id") VALUES ('01a17cc4-c5d5-73de-aa21-5aaccead92f0', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'Company alpha-bak', NULL, NULL, 'FBU', NULL, NULL, 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'fr', 'Africa/Bujumbura', NULL);

DELETE FROM "company_payment_methods" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "crm_accounts" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "crm_activities" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "crm_campaign_members" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "crm_campaigns" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "crm_leads" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "crm_opportunities" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "crm_pipeline_stages" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "currencies" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';
INSERT INTO "currencies" ("id", "tenant_id", "code", "name", "symbol", "decimal_places", "exchange_rate", "is_default", "is_active", "created_at", "updated_at", "deleted_at") VALUES ('01a17cc4-c5e1-7009-9d9a-b4947d34332d', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'FBU', 'Franc Burundais', 'FBu', 0, 1, 1, 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32', NULL);

DELETE FROM "currency_exchange_rates" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "customer_addresses" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "customer_payments" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "customer_transactions" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "customers" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';
INSERT INTO "customers" ("id", "tenant_id", "name", "email", "phone", "is_active", "created_at", "updated_at", "deleted_at", "code", "company_name", "tax_id", "date_of_birth", "gender", "credit_limit", "payment_terms_days", "loyalty_points", "loyalty_tier", "notes", "metadata", "crm_role", "job_title", "crm_account_id", "party_id") VALUES ('01a17cc4-c61d-71ae-980b-ef3688bffdf4', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'Customer alpha-bak', 'customer-alpha-bak@test.local', NULL, 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32', NULL, 'CLI-0001', NULL, NULL, NULL, NULL, NULL, 0, 0, 'standard', NULL, NULL, 'client', NULL, NULL, NULL);

DELETE FROM "desk_documents" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "devices" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "employees" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "expense_categories" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "gallery_images" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "goods_receipt_items" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "goods_receipts" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "inbox_notifications" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "inventory_alerts" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "inventory_count_items" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "inventory_counts" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "inventory_movements" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "inventory_verification_findings" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "inventory_verification_plans" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "inventory_verification_runs" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "locations" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "merchant_qr_codes" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "notification_channel_settings" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "notification_deliveries" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "notification_preferences" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "numbering_rules" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "numbering_sequences" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "offline_transactions" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "parties" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "party_contexts" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "payment_transactions" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "platform_audit_logs" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "pos_reservations" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "pos_table_events" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "pos_table_zones" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "pos_tables" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "prices" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "product_accompaniment_links" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "product_bundle_items" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "product_images" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "product_sale_units" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "product_variants" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "products" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';
INSERT INTO "products" ("id", "tenant_id", "catalog_id", "category_id", "sku", "name", "description", "barcode", "unit", "base_price", "cost_price", "is_active", "metadata", "created_at", "updated_at", "deleted_at", "product_type", "brand_id", "unit_id", "tax_id", "is_serialized", "track_batch", "track_expiration", "expiration_days", "low_stock_threshold", "bottle_volume_ml", "inventory_class", "count_frequency", "last_counted_at", "next_count_at", "accompaniment_enabled", "tax_class_id") VALUES ('01a17cc4-c616-7240-992e-b229222161b6', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', '01a17cc4-c5e2-729a-aa97-c0c786d3e374', NULL, 'ALPHA-BAK-001', 'Product alpha-bak', NULL, NULL, 'piece', 1000, 0, 1, NULL, '2026-10-27 09:50:32', '2026-10-27 09:50:32', NULL, 'simple', NULL, NULL, NULL, 0, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL);

DELETE FROM "promotions" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "purchase_invoices" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "purchase_order_items" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "purchase_orders" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "purchase_payments" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "purchase_proforma_items" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "purchase_proformas" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "purchase_requisition_items" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "purchase_requisitions" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "purchases" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "push_subscriptions" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "qr_order_items" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "qr_orders" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "qr_table_sessions" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "realtime_outbox" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc4-c603-711e-9c54-3ebf7c438c99', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', '01a17cc4-c5e6-72dc-9ad8-fa89a0d34682', NULL, 'unit.created', 'unit', '01a17cc4-c5ec-70f2-909f-4a9cf66f7245', NULL, '{"code":"piece","name":"Pi\u00e8ce","symbol":"pc"}', '2026-10-27 09:50:32', NULL, '2026-10-27 09:50:32', '2026-10-27 09:50:32');
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc4-c607-720b-8b8d-7ed978d10e94', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', '01a17cc4-c5e6-72dc-9ad8-fa89a0d34682', NULL, 'unit.created', 'unit', '01a17cc4-c606-715e-98d3-2526b28eca8c', NULL, '{"code":"kg","name":"Kilogramme","symbol":"kg"}', '2026-10-27 09:50:32', NULL, '2026-10-27 09:50:32', '2026-10-27 09:50:32');
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc4-c60b-73ce-b34a-f28142437735', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', '01a17cc4-c5e6-72dc-9ad8-fa89a0d34682', NULL, 'unit.created', 'unit', '01a17cc4-c60a-7345-b81a-1c2b15cce03b', NULL, '{"code":"g","name":"Gramme","symbol":"g"}', '2026-10-27 09:50:32', NULL, '2026-10-27 09:50:32', '2026-10-27 09:50:32');
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc4-c60f-70b4-9310-4b0307f8fe3e', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', '01a17cc4-c5e6-72dc-9ad8-fa89a0d34682', NULL, 'unit.created', 'unit', '01a17cc4-c60e-731d-bf98-c1afae65df67', NULL, '{"code":"L","name":"Litre","symbol":"L"}', '2026-10-27 09:50:32', NULL, '2026-10-27 09:50:32', '2026-10-27 09:50:32');
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc4-c612-71e6-96eb-bdb93c15cbc4', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', '01a17cc4-c5e6-72dc-9ad8-fa89a0d34682', NULL, 'unit.created', 'unit', '01a17cc4-c611-717f-9734-2bc3be77ac69', NULL, '{"code":"h","name":"Heure","symbol":"h"}', '2026-10-27 09:50:32', NULL, '2026-10-27 09:50:32', '2026-10-27 09:50:32');
INSERT INTO "realtime_outbox" ("id", "tenant_id", "store_id", "user_id", "event_name", "entity_type", "entity_id", "status", "payload", "occurred_at", "broadcast_at", "created_at", "updated_at") VALUES ('01a17cc4-c617-708d-a60c-360c09743b7f', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', NULL, NULL, 'product.created', 'product', '01a17cc4-c616-7240-992e-b229222161b6', NULL, '{"name":"Product alpha-bak","sku":"ALPHA-BAK-001","base_price":1000,"is_active":true}', '2026-10-27 09:50:32', NULL, '2026-10-27 09:50:32', '2026-10-27 09:50:32');

DELETE FROM "roles" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-c339-71d2-9050-16c359bf2800', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'Company Owner', 'company_owner', 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-c399-7089-b41e-f345d0b45566', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'Admin', 'administrator', 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-c3e0-732f-807e-39e3d4f97b7c', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'Branch Manager', 'branch_manager', 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-c3eb-70f5-9274-1d514b18d27d', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'Store Manager', 'store_manager', 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-c3f1-7141-bdda-6e682f367751', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'Caissier', 'cashier', 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-c3f8-7048-89ee-e8514862da56', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'Stock Manager', 'inventory_manager', 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-c3fd-7090-a582-2ef379001c32', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'Manager', 'manager', 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-c403-73f3-a4f0-f6fdddbd6a4d', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'Comptable', 'accountant', 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-c409-7285-9888-cab0996ed730', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'Serveur', 'serveur', 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-c40c-7112-8f21-9c8d3f676b71', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'Réceptionniste', 'receptionist', 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-c40f-71ad-9bdc-1cb12b2ab150', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'Sales Agent', 'sales_agent', 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32');
INSERT INTO "roles" ("id", "tenant_id", "name", "slug", "is_system", "created_at", "updated_at") VALUES ('01a17cc4-c411-7255-b5a2-6f9746d64229', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'Auditor', 'auditor', 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32');

DELETE FROM "saas_invoices" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "saas_payments" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "saas_subscription_events" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "saas_subscriptions" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "sale_discounts" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "sale_installments" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "sale_invoices" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "sale_items" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "sale_payments" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "sale_receipts" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "sale_refunds" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "sale_return_items" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "sale_returns" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "sale_taxes" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "sales" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "serial_numbers" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "service_appointments" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "service_offerings" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "stock_adjustment_items" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "stock_adjustments" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "stock_balances" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "stock_transfer_items" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "stock_transfers" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "store_products" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "stores" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';
INSERT INTO "stores" ("id", "tenant_id", "branch_id", "name", "code", "is_active", "created_at", "updated_at", "deleted_at", "kind", "location_id", "is_main", "qr_approval_mode") VALUES ('01a17cc4-c5e6-72dc-9ad8-fa89a0d34682', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', '01a17cc4-c5e5-7109-a795-e4890b0c92ff', 'Store', 'ALPHA-BAK01', 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32', NULL, 'store', NULL, 0, 'manual');

DELETE FROM "supplier_contacts" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "supplier_payments" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "supplier_transactions" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "suppliers" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';
INSERT INTO "suppliers" ("id", "tenant_id", "name", "code", "email", "phone", "is_active", "created_at", "updated_at", "deleted_at", "legal_name", "tax_id", "address", "payment_terms_days", "credit_limit", "currency_code", "notes", "metadata", "party_id") VALUES ('01a17cc4-c621-700c-912d-116d19949e5b', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'Supplier alpha-bak', 'ALPHA-BAK-SUP', NULL, NULL, 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32', NULL, NULL, NULL, NULL, 30, NULL, 'USD', NULL, NULL, NULL);

DELETE FROM "sync_events" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "sync_failures" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "table_qr_tokens" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "tax_classes" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "tax_groups" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "tax_rules" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "taxes" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "transactions" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';

DELETE FROM "units" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';
INSERT INTO "units" ("id", "tenant_id", "code", "name", "symbol", "is_fractional", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc4-c5ec-70f2-909f-4a9cf66f7245', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'piece', 'Pièce', 'pc', 0, 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32', NULL, '01a17cc4-c5e6-72dc-9ad8-fa89a0d34682');
INSERT INTO "units" ("id", "tenant_id", "code", "name", "symbol", "is_fractional", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc4-c606-715e-98d3-2526b28eca8c', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'kg', 'Kilogramme', 'kg', 1, 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32', NULL, '01a17cc4-c5e6-72dc-9ad8-fa89a0d34682');
INSERT INTO "units" ("id", "tenant_id", "code", "name", "symbol", "is_fractional", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc4-c60a-7345-b81a-1c2b15cce03b', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'g', 'Gramme', 'g', 1, 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32', NULL, '01a17cc4-c5e6-72dc-9ad8-fa89a0d34682');
INSERT INTO "units" ("id", "tenant_id", "code", "name", "symbol", "is_fractional", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc4-c60e-731d-bf98-c1afae65df67', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'L', 'Litre', 'L', 1, 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32', NULL, '01a17cc4-c5e6-72dc-9ad8-fa89a0d34682');
INSERT INTO "units" ("id", "tenant_id", "code", "name", "symbol", "is_fractional", "is_active", "created_at", "updated_at", "deleted_at", "store_id") VALUES ('01a17cc4-c611-717f-9734-2bc3be77ac69', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'h', 'Heure', 'h', 1, 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32', NULL, '01a17cc4-c5e6-72dc-9ad8-fa89a0d34682');

DELETE FROM "users" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';
INSERT INTO "users" ("id", "name", "email", "email_verified_at", "password", "phone", "pin", "is_active", "remember_token", "created_at", "updated_at", "tenant_id", "api_token", "two_factor_secret", "two_factor_confirmed_at", "two_factor_recovery_codes", "phone_verified_at", "party_id") VALUES ('01a17cc4-c5c8-734a-8fd6-31f3a846589b', 'User alpha-bak', 'alpha-bak@test.local', '2026-10-27 09:50:32', '$2y$04$IVpmle5U9jBSTXMmMhm/LeG4YdY9pprb.86REva3Qj8p3RXmqtENW', NULL, NULL, 1, NULL, '2026-10-27 09:50:32', '2026-10-27 09:50:32', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', NULL, NULL, NULL, NULL, NULL, NULL);

DELETE FROM "warehouses" WHERE "tenant_id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';
INSERT INTO "warehouses" ("id", "tenant_id", "branch_id", "name", "code", "is_active", "created_at", "updated_at", "deleted_at", "location_id") VALUES ('01a17cc4-c615-703f-83db-55988749d2a4', '01a17cc4-c32c-72a9-a943-6474c7bb96bc', '01a17cc4-c5e5-7109-a795-e4890b0c92ff', 'Warehouse', 'ALPHA-BAK-WH', 1, '2026-10-27 09:50:32', '2026-10-27 09:50:32', NULL, NULL);

DELETE FROM "tenants" WHERE "id" = '01a17cc4-c32c-72a9-a943-6474c7bb96bc';
INSERT INTO "tenants" ("id", "name", "slug", "status", "settings", "created_at", "updated_at", "deleted_at", "legal_name", "trade_name", "logo_url", "address", "phone", "email", "website", "country_code", "currency_code", "timezone", "locale", "tax_regime", "tax_id", "registration_number", "subscription") VALUES ('01a17cc4-c32c-72a9-a943-6474c7bb96bc', 'Tenant alpha-bak', 'alpha-bak', 'active', NULL, '2026-10-27 09:50:32', '2026-10-27 09:50:32', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'BI', 'FBU', 'Africa/Bujumbura', 'fr', NULL, NULL, NULL, NULL);

COMMIT;
PRAGMA foreign_keys=ON;
