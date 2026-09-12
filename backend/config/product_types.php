<?php

return [

    'types' => [
        'simple' => 'Produit simple',
        'variant' => 'Produit avec variantes',
        'service' => 'Service',
        'bundle' => 'Pack / bundle',
        'weighable' => 'Produit pesable',
        'serialized' => 'Produit sérialisé',
        'batch' => 'Produit par lot',
    ],

    'barcode_types' => [
        'ean13' => 'EAN-13',
        'ean8' => 'EAN-8',
        'upc' => 'UPC',
        'code128' => 'Code 128',
        'qr' => 'QR Code',
        'internal' => 'Interne',
    ],

    'price_types' => [
        'base' => 'Prix de base',
        'retail' => 'Prix détail',
        'wholesale' => 'Prix gros',
        'promo' => 'Promotion',
    ],

];
