<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Media Storage Disk
    |--------------------------------------------------------------------------
    |
    | Disk used for product images and other catalog media (S3 / MinIO).
    |
    */

    // Prefer the public disk locally so POS/backoffice can load images via /storage.
    'disk' => env('MEDIA_DISK', 'public'),

    /*
    |--------------------------------------------------------------------------
    | CDN Base URL
    |--------------------------------------------------------------------------
    |
    | Public CDN URL prefix served to POS terminals for offline image caching.
    | Example (MinIO): http://127.0.0.1:9000/pos-uploads
    |
    */

    'cdn_url' => rtrim(env('CDN_URL', env('AWS_URL', '')), '/'),

    /*
    |--------------------------------------------------------------------------
    | Product Image Settings
    |--------------------------------------------------------------------------
    */

    'product' => [
        'path' => '{tenant_id}/products/{product_id}',
        'max_size_kb' => (int) env('PRODUCT_IMAGE_MAX_SIZE_KB', 5120),
        'allowed_mimes' => ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
    ],

];
