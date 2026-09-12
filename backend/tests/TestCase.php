<?php

namespace Tests;

use App\Tenancy\TenantContext;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    protected function tearDown(): void
    {
        if (app()->bound(TenantContext::class)) {
            app(TenantContext::class)->clear();
        }

        parent::tearDown();
    }
}
