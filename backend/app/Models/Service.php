<?php

namespace App\Models;

/**
 * Business-core alias for a sellable / bookable service offering.
 */
class Service extends ServiceOffering
{
    protected $table = 'service_offerings';

    public function getMorphClass(): string
    {
        return ServiceOffering::class;
    }
}
