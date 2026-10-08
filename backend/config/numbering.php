<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Default document numbering rules
    |--------------------------------------------------------------------------
    |
    | Used when a tenant (or branch) has not configured an override.
    | Tokens: {prefix} {year} {month} {sequence} {branch}
    |
    */
    'defaults' => [
        'invoice' => [
            'prefix' => 'INV',
            'pattern' => '{prefix}-{year}-{sequence}',
            'padding' => 6,
            'reset_policy' => 'yearly',
            'starting_number' => 1,
        ],
        'pos' => [
            'prefix' => 'POS',
            'pattern' => '{prefix}-{year}-{sequence}',
            'padding' => 6,
            'reset_policy' => 'yearly',
            'starting_number' => 1,
        ],
        'purchase_order' => [
            'prefix' => 'PO',
            'pattern' => '{prefix}-{year}-{sequence}',
            'padding' => 6,
            'reset_policy' => 'yearly',
            'starting_number' => 1,
        ],
        'reservation' => [
            'prefix' => 'RES',
            'pattern' => '{prefix}-{year}-{sequence}',
            'padding' => 6,
            'reset_policy' => 'yearly',
            'starting_number' => 1,
        ],
        'expense' => [
            'prefix' => 'EXP',
            'pattern' => '{prefix}-{year}-{sequence}',
            'padding' => 6,
            'reset_policy' => 'yearly',
            'starting_number' => 1,
        ],
        'receipt' => [
            'prefix' => 'REC',
            'pattern' => '{prefix}-{year}-{sequence}',
            'padding' => 6,
            'reset_policy' => 'yearly',
            'starting_number' => 1,
        ],
    ],
];
