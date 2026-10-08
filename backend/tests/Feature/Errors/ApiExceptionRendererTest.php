<?php

namespace Tests\Feature\Errors;

use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Support\Facades\Route;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class ApiExceptionRendererTest extends TestCase
{
    public function test_validation_exception_returns_stable_code(): void
    {
        Route::middleware('api')->get('/api/v1/__test/validation', function () {
            throw ValidationException::withMessages([
                'email' => ['saas.limit_users'],
            ]);
        });

        $this->getJson('/api/v1/__test/validation')
            ->assertStatus(422)
            ->assertJsonPath('code', 'errors.validation')
            ->assertJsonPath('message', 'errors.validation')
            ->assertJsonPath('errors.email.0', 'saas.limit_users');
    }

    public function test_authentication_exception_returns_stable_code(): void
    {
        Route::middleware('api')->get('/api/v1/__test/auth', function () {
            throw new AuthenticationException;
        });

        $this->getJson('/api/v1/__test/auth')
            ->assertUnauthorized()
            ->assertJsonPath('code', 'errors.unauthenticated')
            ->assertJsonPath('message', 'errors.unauthenticated');
    }

    public function test_authorization_exception_returns_stable_code(): void
    {
        Route::middleware('api')->get('/api/v1/__test/forbidden', function () {
            throw new AuthorizationException;
        });

        $this->getJson('/api/v1/__test/forbidden')
            ->assertForbidden()
            ->assertJsonPath('code', 'errors.forbidden');
    }

    public function test_model_not_found_returns_stable_code(): void
    {
        Route::middleware('api')->get('/api/v1/__test/missing', function () {
            throw new ModelNotFoundException;
        });

        $this->getJson('/api/v1/__test/missing')
            ->assertNotFound()
            ->assertJsonPath('code', 'errors.not_found');
    }

    public function test_unexpected_exception_hides_technical_details(): void
    {
        Route::middleware('api')->get('/api/v1/__test/boom', function () {
            throw new \RuntimeException('SQLSTATE[HY000] Connection refused at Illuminate\\Database');
        });

        $this->getJson('/api/v1/__test/boom')
            ->assertStatus(500)
            ->assertJsonPath('code', 'errors.server')
            ->assertJsonPath('message', 'errors.server')
            ->assertJsonMissing(['message' => 'SQLSTATE[HY000] Connection refused at Illuminate\\Database']);
    }
}
