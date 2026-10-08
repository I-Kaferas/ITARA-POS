<?php

return [

    /*
    | Seconds to reuse read-heavy aggregates (dashboard, reports, POS overview).
    | 0 disables the cache. Tests keep this at 0 so results stay fresh.
    */
    'read_cache_seconds' => (int) env('PERFORMANCE_READ_CACHE_SECONDS', 20),

    /*
    | Hard cap for list endpoints. Clients that ask for more still receive this many.
    */
    'max_page_size' => (int) env('PERFORMANCE_MAX_PAGE_SIZE', 100),

];
