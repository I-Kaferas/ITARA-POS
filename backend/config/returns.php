<?php

return [

    'reference_prefix' => env('SALE_RETURN_REFERENCE_PREFIX', 'RTN'),

    'reasons' => [
        'defective' => 'Produit défectueux',
        'wrong_item' => 'Mauvais article',
        'customer_changed_mind' => 'Changement d\'avis client',
        'expired' => 'Produit expiré',
        'other' => 'Autre',
    ],

];
