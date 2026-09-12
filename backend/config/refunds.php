<?php

return [

    'reference_prefix' => env('SALE_REFUND_REFERENCE_PREFIX', 'RFD'),

    'methods' => [
        'cash' => [
            'label' => 'Cash Refund',
            'label_fr' => 'Remboursement espèces',
            'requires_cash_register' => true,
        ],
        'card' => [
            'label' => 'Card Refund',
            'label_fr' => 'Remboursement carte',
            'requires_cash_register' => false,
        ],
        'mobile_money' => [
            'label' => 'Mobile Money Refund',
            'label_fr' => 'Remboursement Mobile Money',
            'requires_cash_register' => false,
        ],
        'wallet' => [
            'label' => 'Wallet Refund',
            'label_fr' => 'Remboursement portefeuille',
            'requires_customer' => true,
        ],
        'credit' => [
            'label' => 'Store Credit',
            'label_fr' => 'Avoir magasin',
            'requires_customer' => true,
        ],
        'none' => [
            'label' => 'No Refund',
            'label_fr' => 'Sans remboursement',
        ],
    ],

];
