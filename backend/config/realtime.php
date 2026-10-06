<?php

return [

    /*
    | Queue that carries broadcast jobs. Keep "default" unless a worker
    | is listening on the named queue (php artisan queue:work --queue=realtime,default).
    */
    'queue' => env('REALTIME_QUEUE', 'default'),

    'outbox_retry_minutes' => (int) env('REALTIME_OUTBOX_RETRY_MINUTES', 15),

];
