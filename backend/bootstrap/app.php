<?php

use App\Exceptions\ApiExceptionRenderer;
use App\Http\Middleware\AuthenticateApiToken;
use App\Http\Middleware\EnsureModuleEnabled;
use App\Http\Middleware\EnsurePermission;
use App\Http\Middleware\RecordOfflineTransaction;
use App\Http\Middleware\ResolveStore;
use App\Http\Middleware\ResolveTenant;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Middleware\HandleCors;
use Illuminate\Http\Request;
use Illuminate\Routing\Middleware\SubstituteBindings;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
        apiPrefix: 'api',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->append(HandleCors::class);

        $middleware->alias([
            'permission' => EnsurePermission::class,
        ]);

        $middleware->appendToGroup('api', [
            RecordOfflineTransaction::class,
        ]);

        $middleware->priority([
            AuthenticateApiToken::class,
            ResolveTenant::class,
            ResolveStore::class,
            EnsureModuleEnabled::class,
            EnsurePermission::class,
            SubstituteBindings::class,
        ]);
    })
    ->withSchedule(function (Schedule $schedule): void {
        $schedule->command('realtime:flush')->everyMinute()->withoutOverlapping();
        $schedule->command('saas:reconcile')->dailyAt('01:10')->withoutOverlapping();
        $schedule->command('notifications:digest')->everyFiveMinutes()->withoutOverlapping();
        $schedule->command('backups:run')->dailyAt((string) config('backup.schedule_time', '02:30'))->withoutOverlapping();
        $schedule->command('backups:prune')->dailyAt('03:15')->withoutOverlapping();
        $schedule->command('backups:verify')->weeklyOn(1, '03:40')->withoutOverlapping();
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->render(function (\Throwable $e, Request $request) {
            return app(ApiExceptionRenderer::class)->render($e, $request);
        });
    })->create();
