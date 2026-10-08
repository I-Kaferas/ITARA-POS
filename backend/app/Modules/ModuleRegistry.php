<?php

namespace App\Modules;

/**
 * Single catalog for ERP modules.
 * Disabled modules are omitted from manifests and rejected before a controller runs.
 */
class ModuleRegistry
{
    /** @var list<string> */
    public const CODES = [
        'pos',
        'restaurant',
        'hotel',
        'inventory',
        'crm',
        'accounting',
        'hr',
        'procurement',
        'expenses',
        'projects',
        'documents',
        'fleet',
        'maintenance',
        'manufacturing',
        'ecommerce',
    ];

    /** @var array<string, string> */
    public const ALIASES = [
        'stock' => 'inventory',
    ];

    /**
     * Modules already used by the product. New modules stay off until a tenant turns them on.
     *
     * @var list<string>
     */
    public const DEFAULTS = [
        'pos',
        'restaurant',
        'hotel',
        'inventory',
        'crm',
        'accounting',
        'procurement',
        'expenses',
        'manufacturing',
    ];

    /**
     * Prefixes shared by more than one module. Access is granted when any owner is enabled.
     *
     * @var array<string, list<string>>
     */
    private const SHARED_API = [
        'suppliers' => ['procurement', 'inventory'],
        'supplier-payments' => ['procurement', 'inventory'],
    ];

    /**
     * @param  list<string>  $codes
     * @return list<string>
     */
    public static function normalize(array $codes): array
    {
        $normalized = [];
        foreach ($codes as $code) {
            if (! is_string($code) || $code === '') {
                continue;
            }
            $code = self::ALIASES[$code] ?? $code;
            if (! in_array($code, self::CODES, true) || in_array($code, $normalized, true)) {
                continue;
            }
            $normalized[] = $code;
        }

        return $normalized;
    }

    public static function canonical(string $code): string
    {
        return self::ALIASES[$code] ?? $code;
    }

    /** @return array<string, array<string, mixed>> */
    public static function definitions(): array
    {
        return [
            'pos' => self::module('pos', 'device-pos', ['sales.', 'sale.', 'payments.', 'payment.', 'receipts.', 'receipt.', 'promotions.', 'registers.', 'shifts.', 'pos.'], [
                self::bool('allow_price_override', true),
                self::bool('require_shift', true),
            ], ['sales', 'pos-reservations', 'pos-tables', 'pos-table-zones', 'promotions', 'receipt-formats', 'payments', 'payment-transactions', 'sale-invoices', 'registers', 'cash-registers', 'cashier-shifts'], ['/admin/pos', '/admin/sales'], '/admin/pos/overview', 'nav.group.posOps', 'modules.widgets.pos'),
            'restaurant' => self::module('restaurant', 'store-pin', ['restaurant.'], [
                self::bool('table_service', true),
            ], ['hospitality'], ['/admin/hospitality'], '/admin/hospitality', 'nav.restaurant', 'modules.widgets.restaurant'),
            'hotel' => self::module('hotel', 'bed', ['hotel.'], [
                self::bool('auto_housekeeping', true),
            ], ['hotel'], ['/admin/hotel'], '/admin/hotel/rooms', 'nav.hotel', 'modules.widgets.hotel'),
            'inventory' => self::module('inventory', 'inventory', ['inventory.', 'stock.'], [
                self::bool('allow_negative_stock', false),
            ], ['inventory', 'inventory-verifications', 'inventory-counts', 'inventory-cycle', 'stock-transfers', 'stock-adjustments', 'serial-numbers', 'store-stock'], ['/admin/inventory'], '/admin/inventory/stock', 'nav.inventoryHub', 'modules.widgets.inventory'),
            'crm' => self::module('crm', 'customers', ['crm.'], [
                self::text('pipeline_name', 'Sales'),
            ], ['crm'], ['/admin/crm'], '/admin/crm', 'nav.crm', 'modules.widgets.crm'),
            'accounting' => self::module('accounting', 'coins', ['accounting.'], [
                self::text('fiscal_year_start', '01-01'),
            ], ['accounting', 'reports/financial', 'reports/revenue', 'reports/export/revenue'], ['/admin/accounting', '/admin/reports/financial', '/admin/reports/revenue'], '/admin/accounting', 'nav.accounting', 'modules.widgets.accounting'),
            'hr' => self::module('hr', 'customers', ['hr.'], [
                self::choice('workweek', 'mon-fri', ['mon-fri', 'mon-sat', 'all']),
            ], ['hr'], ['/admin/modules/hr'], '/admin/modules/hr', 'modules.names.hr', 'modules.widgets.hr'),
            'procurement' => self::module('procurement', 'purchases', ['purchases.'], [
                self::bool('approval_required', true),
            ], ['purchases', 'purchase-requisitions', 'purchase-proformas', 'purchase-returns', 'purchase-orders', 'purchase-invoices', 'purchase-payments', 'payables'], ['/admin/purchases', '/admin/payables'], '/admin/purchases/overview', 'nav.purchasingHub', 'modules.widgets.procurement'),
            'expenses' => self::module('expenses', 'coins', ['expenses.'], [
                self::bool('receipt_required', false),
            ], ['expenses', 'expense-categories', 'recurring-expenses'], ['/admin/expenses'], '/admin/expenses/dashboard', 'nav.expenseTrackerHub', 'modules.widgets.expenses'),
            'projects' => self::module('projects', 'layers', ['projects.'], [
                self::bool('billable_default', false),
            ], ['projects'], ['/admin/modules/projects'], '/admin/modules/projects', 'modules.names.projects', 'modules.widgets.projects'),
            'documents' => self::module('documents', 'note', ['documents.'], [
                self::integer('retention_days', 365),
            ], ['documents'], ['/admin/modules/documents'], '/admin/modules/documents', 'modules.names.documents', 'modules.widgets.documents'),
            'fleet' => self::module('fleet', 'transfer', ['fleet.'], [
                self::choice('odometer_unit', 'km', ['km', 'mi']),
            ], ['fleet'], ['/admin/modules/fleet'], '/admin/modules/fleet', 'modules.names.fleet', 'modules.widgets.fleet'),
            'maintenance' => self::module('maintenance', 'adjust', ['maintenance.'], [
                self::bool('preventive_enabled', true),
            ], ['maintenance'], ['/admin/modules/maintenance'], '/admin/modules/maintenance', 'modules.names.maintenance', 'modules.widgets.maintenance'),
            'manufacturing' => self::module('manufacturing', 'package', ['manufacturing.'], [
                self::bool('lot_tracking', true),
            ], ['production'], ['/admin/production'], '/admin/production', 'nav.production', 'modules.widgets.manufacturing'),
            'ecommerce' => self::module('ecommerce', 'catalog', ['ecommerce.'], [
                self::bool('publish_catalog', false),
            ], ['ecommerce'], ['/admin/modules/ecommerce'], '/admin/modules/ecommerce', 'modules.names.ecommerce', 'modules.widgets.ecommerce'),
        ];
    }

    /** @return array<string, mixed>|null */
    public static function definition(string $code): ?array
    {
        $code = self::canonical($code);

        return self::definitions()[$code] ?? null;
    }

    /**
     * Modules that own this permission. Empty means the permission is core.
     *
     * @return list<string>
     */
    public static function modulesForPermission(string $permission): array
    {
        $owners = [];
        foreach (self::definitions() as $code => $definition) {
            foreach ($definition['permission_prefixes'] as $prefix) {
                if (str_starts_with($permission, $prefix)) {
                    $owners[] = $code;
                    break;
                }
            }
        }

        return $owners;
    }

    /**
     * Modules that must be consulted for this API path.
     * Empty means the route is core and always available.
     * Several modules means any enabled owner is enough.
     *
     * @return list<string>
     */
    public static function modulesForApiPath(string $path): array
    {
        $path = trim((string) preg_replace('#^api/v1/#', '', ltrim($path, '/')), '/');
        if ($path === 'modules' || str_starts_with($path, 'modules/')) {
            return [];
        }

        if (preg_match('#^stores/[^/]+/payments(/|$)#', $path) === 1) {
            return ['pos'];
        }

        $best = [];
        $length = -1;
        foreach (self::apiPrefixMap() as $prefix => $modules) {
            if ($path === $prefix || str_starts_with($path, $prefix.'/')) {
                if (strlen($prefix) > $length) {
                    $best = $modules;
                    $length = strlen($prefix);
                }
            }
        }
        if ($best !== []) {
            return $best;
        }

        foreach (explode('/', $path) as $segment) {
            if (isset(self::apiPrefixMap()[$segment])) {
                return self::apiPrefixMap()[$segment];
            }
        }

        return [];
    }

    /**
     * @return list<string>
     */
    public static function permissionSlugs(string $code): array
    {
        $definition = self::definition($code);
        if ($definition === null) {
            return [];
        }

        $slugs = [];
        foreach (array_keys(config('rbac.permissions', [])) as $slug) {
            foreach ($definition['permission_prefixes'] as $prefix) {
                if (str_starts_with($slug, $prefix)) {
                    $slugs[] = $slug;
                    break;
                }
            }
        }

        return $slugs;
    }

    /** @return array<string, list<string>> */
    private static function apiPrefixMap(): array
    {
        $map = self::SHARED_API;
        foreach (self::definitions() as $code => $definition) {
            foreach ($definition['api'] as $prefix) {
                $map[$prefix] ??= [];
                if (! in_array($code, $map[$prefix], true)) {
                    $map[$prefix][] = $code;
                }
            }
        }

        return $map;
    }

    /**
     * @param  list<string>  $permissionPrefixes
     * @param  list<array<string, mixed>>  $settings
     * @param  list<string>  $api
     * @param  list<string>  $web
     * @return array<string, mixed>
     */
    private static function module(
        string $code,
        string $icon,
        array $permissionPrefixes,
        array $settings,
        array $api,
        array $web,
        string $to,
        string $labelKey,
        string $widgetKey,
    ): array {
        return [
            'code' => $code,
            'icon' => $icon,
            'permission_prefixes' => $permissionPrefixes,
            'settings' => $settings,
            'api' => $api,
            'web' => $web,
            'navigation' => [
                ['name' => $code, 'to' => $to, 'label_key' => $labelKey, 'icon' => $icon],
            ],
            'widgets' => [
                ['code' => $code.'.home', 'label_key' => $widgetKey, 'icon' => $icon, 'to' => $to],
            ],
        ];
    }

    /** @return array{key: string, type: string, default: bool} */
    private static function bool(string $key, bool $default): array
    {
        return ['key' => $key, 'type' => 'boolean', 'default' => $default];
    }

    /** @return array{key: string, type: string, default: string} */
    private static function text(string $key, string $default): array
    {
        return ['key' => $key, 'type' => 'string', 'default' => $default];
    }

    /**
     * @param  list<string>  $options
     * @return array{key: string, type: string, default: string, options: list<string>}
     */
    private static function choice(string $key, string $default, array $options): array
    {
        return ['key' => $key, 'type' => 'string', 'default' => $default, 'options' => $options];
    }

    /** @return array{key: string, type: string, default: int} */
    private static function integer(string $key, int $default): array
    {
        return ['key' => $key, 'type' => 'integer', 'default' => $default];
    }
}
