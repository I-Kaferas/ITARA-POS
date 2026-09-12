<?php

return [

    'default_credit_limit' => (int) env('CUSTOMER_DEFAULT_CREDIT_LIMIT', 0),

    'default_payment_terms_days' => (int) env('CUSTOMER_PAYMENT_TERMS_DAYS', 0),

    /*
    | Points earned per currency minor unit spent (e.g. 1 point per 100 cents).
    */
    'loyalty_points_per_amount' => (int) env('CUSTOMER_LOYALTY_POINTS_PER_AMOUNT', 100),

    'loyalty_points_earned_per_unit' => (int) env('CUSTOMER_LOYALTY_POINTS_EARNED', 1),

    'loyalty_tiers' => [
        'standard' => ['min_points' => 0, 'label' => 'Standard'],
        'silver' => ['min_points' => 500, 'label' => 'Silver'],
        'gold' => ['min_points' => 2000, 'label' => 'Gold'],
        'platinum' => ['min_points' => 5000, 'label' => 'Platinum'],
    ],

];
