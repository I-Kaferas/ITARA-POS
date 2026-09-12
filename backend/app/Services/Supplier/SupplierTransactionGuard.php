<?php

namespace App\Services\Supplier;

final class SupplierTransactionGuard
{
    private static int $depth = 0;

    public static function isAuthorized(): bool
    {
        return self::$depth > 0;
    }

    /**
     * @template TReturn
     *
     * @param  callable(): TReturn  $callback
     * @return TReturn
     */
    public static function runAuthorized(callable $callback): mixed
    {
        self::$depth++;

        try {
            return $callback();
        } finally {
            self::$depth--;
        }
    }
}
