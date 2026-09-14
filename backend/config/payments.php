<?php

return [
    'transaction_number_prefix' => 'PAY',
    'methods' => [
        'cash' => [
            'label' => 'Cash',
            'label_fr' => 'Espèces',
            'provider' => 'cash',
            'supports_change' => true,
        ],
        'mobile_money' => [
            'label' => 'Mobile Money',
            'label_fr' => 'Mobile Money',
            'provider' => 'mobile_money',
            'supports_change' => false,
        ],
        'card' => [
            'label' => 'Card',
            'label_fr' => 'Carte',
            'provider' => 'card',
            'supports_change' => false,
        ],
        'bank_transfer' => [
            'label' => 'Bank transfer',
            'label_fr' => 'Virement',
            'provider' => 'bank_transfer',
            'supports_change' => false,
        ],
        'credit' => [
            'label' => 'Credit',
            'label_fr' => 'Crédit',
            'provider' => 'credit',
            'supports_change' => false,
        ],
        'wallet' => [
            'label' => 'Wallet',
            'label_fr' => 'Portefeuille',
            'provider' => 'wallet',
            'supports_change' => false,
        ],
    ],
];
