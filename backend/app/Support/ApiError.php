<?php

namespace App\Support;

use Illuminate\Http\JsonResponse;

/**
 * Stable, client-translatable API error envelope.
 *
 * Prefer emitting codes like `errors.forbidden` instead of prose so the
 * SPA can show clear, localized messages to end users.
 */
final class ApiError
{
    /**
     * @param  array<string, mixed>  $extra
     */
    public static function json(string $code, int $status, array $extra = []): JsonResponse
    {
        return response()->json(array_merge([
            'code' => $code,
            'message' => $code,
        ], $extra), $status);
    }
}
