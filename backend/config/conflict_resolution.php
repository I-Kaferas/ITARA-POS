<?php

/**
 * Conflict resolution rules by domain.
 *
 * Each domain picks a strategy. Entity types are mapped to domains so sync
 * pipelines can resolve conflicts without hard-coding product rules.
 *
 * Strategies:
 * - never_overwrite_completed: completed/final sales are immutable
 * - stock_movements: never overwrite balances; accept movement deltas only
 * - master_wins: master (server) configuration always wins over slave/client
 * - manual: surface a conflict for operator resolution
 * - server_wins: silently keep the server copy
 * - client_wins: allow the incoming local copy (use sparingly)
 */
return [

    'default_domain' => 'default',

    'domains' => [
        'sales' => [
            'strategy' => 'never_overwrite_completed',
            'entity_types' => ['sale', 'sales', 'sale_item', 'sale_payment', 'payment'],
            'final_statuses' => ['completed', 'voided', 'merged'],
            'mutable_operations' => ['update', 'delete', 'void', 'overwrite'],
        ],

        'stock' => [
            'strategy' => 'stock_movements',
            'entity_types' => [
                'stock',
                'stock_balance',
                'inventory_movement',
                'stock_movement',
                'stock_adjustment',
                'stock_transfer',
            ],
            // Absolute quantity writes are rejected; movement-shaped ops apply.
            'overwrite_operations' => [
                'set_quantity',
                'overwrite',
                'overwrite_balance',
                'replace_balance',
                'set_balance',
            ],
            'movement_operations' => [
                'create',
                'movement',
                'adjust',
                'transfer',
                'receive',
                'issue',
            ],
        ],

        'configuration' => [
            'strategy' => 'master_wins',
            'entity_types' => [
                'product',
                'category',
                'price',
                'price_list',
                'user',
                'permission',
                'role',
                'tax',
                'tax_group',
                'tax_class',
                'tax_rule',
                'table',
                'zone',
                'printer',
                'printer_group',
                'printer_route',
                'restaurant_configuration',
                'hotel_settings',
                'payment_method',
                'unit',
                'currency',
            ],
        ],

        'default' => [
            'strategy' => 'manual',
            'entity_types' => [],
        ],
    ],

];
