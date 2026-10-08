<?php

namespace App\Exceptions;

use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Throwable;

/**
 * Normalizes API exceptions into a stable JSON envelope with translatable codes.
 * Never leaks stack traces or framework noise to the client.
 */
final class ApiExceptionRenderer
{
    public function render(Throwable $e, Request $request): ?JsonResponse
    {
        if (! $request->is('api/*') && ! $request->expectsJson()) {
            return null;
        }

        if ($e instanceof ValidationException) {
            return response()->json([
                'code' => 'errors.validation',
                'message' => 'errors.validation',
                'errors' => $e->errors(),
            ], $e->status);
        }

        if ($e instanceof AuthenticationException) {
            return response()->json([
                'code' => 'errors.unauthenticated',
                'message' => 'errors.unauthenticated',
            ], 401);
        }

        if ($e instanceof AuthorizationException) {
            return response()->json([
                'code' => 'errors.forbidden',
                'message' => 'errors.forbidden',
            ], 403);
        }

        if ($e instanceof ModelNotFoundException) {
            return response()->json([
                'code' => 'errors.not_found',
                'message' => 'errors.not_found',
            ], 404);
        }

        if ($e instanceof HttpExceptionInterface) {
            $status = $e->getStatusCode();
            $code = $this->codeForStatus($status);
            $raw = trim((string) $e->getMessage());

            return response()->json([
                'code' => $code,
                'message' => $this->isSafeDomainMessage($raw) ? $raw : $code,
            ], $status);
        }

        report($e);

        return response()->json([
            'code' => 'errors.server',
            'message' => 'errors.server',
        ], 500);
    }

    private function codeForStatus(int $status): string
    {
        return match ($status) {
            400 => 'errors.bad_request',
            401 => 'errors.unauthenticated',
            403 => 'errors.forbidden',
            404 => 'errors.not_found',
            408 => 'errors.timeout',
            409 => 'errors.conflict',
            422 => 'errors.validation',
            429 => 'errors.too_many_requests',
            502, 503, 504 => 'errors.unavailable',
            default => $status >= 500 ? 'errors.server' : 'errors.generic',
        };
    }

    private function isSafeDomainMessage(string $message): bool
    {
        if ($message === '') {
            return false;
        }

        if (str_starts_with($message, 'errors.') || str_starts_with($message, 'saas.')) {
            return true;
        }

        // Reject obvious technical payloads.
        if (preg_match('/SQLSTATE|stack trace|Exception:|Illuminate\\\\|Symfony\\\\/i', $message)) {
            return false;
        }

        return strlen($message) <= 220;
    }
}
