<?php

namespace App\Models;

/**
 * Business-core alias for the tenant company.
 * One organization party can own branches, stores, and catalogs.
 */
class Organization extends Company
{
    protected $table = 'companies';

    public function getMorphClass(): string
    {
        return Company::class;
    }
}
