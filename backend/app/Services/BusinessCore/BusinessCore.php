<?php

namespace App\Services\BusinessCore;

/**
 * Shared business-core map.
 *
 * Party is the single identity. Roles (Customer, Supplier, Employee, User,
 * Organization) and contexts (POS, restaurant, hotel, CRM) attach to it
 * instead of creating duplicate people/orgs.
 *
 * Catalog: Product, Service
 * Place: Location
 * Events: BusinessTransaction, BusinessPayment, BusinessDocument
 */
final class BusinessCore
{
    public const ENTITIES = [
        'party' => \App\Models\Party::class,
        'customer' => \App\Models\Customer::class,
        'supplier' => \App\Models\Supplier::class,
        'employee' => \App\Models\Employee::class,
        'product' => \App\Models\Product::class,
        'service' => \App\Models\Service::class,
        'location' => \App\Models\Location::class,
        'transaction' => \App\Models\Transaction::class,
        'payment' => \App\Models\PaymentTransaction::class,
        'document' => \App\Models\BusinessDocument::class,
        'user' => \App\Models\User::class,
        'organization' => \App\Models\Organization::class,
    ];

    public function __construct(
        public readonly PartyRegistry $parties,
        public readonly LocationRegistry $locations,
    ) {}

    /** @return array<string, class-string> */
    public function entities(): array
    {
        return self::ENTITIES;
    }
}
