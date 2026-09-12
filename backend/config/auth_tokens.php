<?php

return [

    'access_token_ttl_minutes' => (int) env('AUTH_ACCESS_TOKEN_TTL', 60),

    'refresh_token_ttl_days' => (int) env('AUTH_REFRESH_TOKEN_TTL_DAYS', 30),

    'two_factor_challenge_ttl_minutes' => (int) env('AUTH_2FA_CHALLENGE_TTL', 5),

    'phone_code_ttl_minutes' => (int) env('AUTH_PHONE_CODE_TTL', 10),

    'max_sessions_per_user' => (int) env('AUTH_MAX_SESSIONS', 10),

    'brute_force' => [
        'max_attempts' => (int) env('AUTH_MAX_LOGIN_ATTEMPTS', 5),
        'decay_minutes' => (int) env('AUTH_LOGIN_DECAY_MINUTES', 15),
        'lockout_minutes' => (int) env('AUTH_LOCKOUT_MINUTES', 15),
    ],

    'admin_roles_requiring_2fa' => [
        'super_admin',
        'company_owner',
        'administrator',
    ],

];
