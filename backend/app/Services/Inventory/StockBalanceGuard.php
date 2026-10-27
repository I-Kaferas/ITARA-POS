<?php

namespace App\Services\Inventory;

/**
 * Allows StockBalance writes only from the inventory movement pipeline.
 */
final class StockBalanceGuard
{
    private static int $depth = 0;

    private static int $negativeDepth = 0;

    public static function isAuthorized(): bool
    {
        return self::$depth > 0;
    }

    public static function allowsNegative(): bool
    {
        return self::$negativeDepth > 0;
    }

    /**
     * Offline sale replay may drive a balance below zero. The shortage stays
     * visible so it can be counted later.
     *
     * @template TReturn
     *
     * @param  callable(): TReturn  $callback
     * @return TReturn
     */
    public static function allowingNegative(callable $callback): mixed
    {
        self::$negativeDepth++;

        try {
            return $callback();
        } finally {
            self::$negativeDepth--;
        }
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
