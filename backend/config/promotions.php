<?php

return [

    'types' => [
        'percentage_discount' => [
            'label' => 'Percentage discount',
            'label_fr' => 'Remise en pourcentage',
            'requires' => ['discount_percent'],
        ],
        'fixed_discount' => [
            'label' => 'Fixed discount',
            'label_fr' => 'Remise fixe',
            'requires' => ['discount_amount'],
        ],
        'buy_x_get_y' => [
            'label' => 'Buy X get Y',
            'label_fr' => 'Achetez X, Y offert',
            'requires' => ['buy_quantity', 'get_quantity'],
        ],
        'bundle' => [
            'label' => 'Bundle price',
            'label_fr' => 'Prix de lot',
            'requires' => ['bundle_price', 'items'],
        ],
        'quantity_discount' => [
            'label' => 'Quantity discount',
            'label_fr' => 'Remise quantité',
            'requires' => ['discount_percent', 'min_quantity'],
        ],
        'category_discount' => [
            'label' => 'Category discount',
            'label_fr' => 'Remise catégorie',
            'requires' => ['discount_percent', 'category_id'],
        ],
        'customer_discount' => [
            'label' => 'Customer discount',
            'label_fr' => 'Remise client',
            'requires' => ['discount_percent', 'customer_ids'],
        ],
        'time_based' => [
            'label' => 'Special price by time',
            'label_fr' => 'Prix spécial horaire',
            'requires' => ['discount_amount', 'schedule'],
        ],
    ],

    'item_roles' => ['target', 'trigger', 'reward', 'bundle'],

];
