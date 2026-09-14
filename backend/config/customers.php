<?php

return [

    'default_credit_limit' => (int) env('CUSTOMER_DEFAULT_CREDIT_LIMIT', 0),

    'default_payment_terms_days' => (int) env('CUSTOMER_PAYMENT_TERMS_DAYS', 0),

    /*
    | 1000 currency units spent = 1 point.
    | Amounts are stored in minor units (100 = 1.00), so 1000 F = 100000.
    */
    'loyalty_points_per_amount' => (int) env('CUSTOMER_LOYALTY_POINTS_PER_AMOUNT', 100000),

    'loyalty_points_earned_per_unit' => (int) env('CUSTOMER_LOYALTY_POINTS_EARNED', 1),

    /*
    | Reward: 1 point becomes 1.00 of store credit or a ticket discount.
    */
    'loyalty_reward_per_point' => (int) env('CUSTOMER_LOYALTY_REWARD_PER_POINT', 100),

    'loyalty_tiers' => [
        'standard' => ['min_points' => 0, 'label' => 'Standard'],
        'silver' => ['min_points' => 500, 'label' => 'Silver'],
        'gold' => ['min_points' => 2000, 'label' => 'Gold'],
        'platinum' => ['min_points' => 5000, 'label' => 'Platinum'],
    ],

];
