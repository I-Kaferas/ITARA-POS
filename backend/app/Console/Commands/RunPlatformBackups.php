<?php

namespace App\Console\Commands;

use App\Services\Platform\Backup\BackupService;
use Illuminate\Console\Command;
use Throwable;

class RunPlatformBackups extends Command
{
    protected $signature = 'backups:run {--type= : database|files|full} {--force : Run even when auto_enabled is false}';

    protected $description = 'Create a platform backup (database, files, or full) and apply retention';

    public function handle(BackupService $backups): int
    {
        $type = $this->option('type');
        $force = (bool) $this->option('force');

        try {
            if ($type || $force) {
                $settings = $backups->settings();
                $backup = $backups->create(
                    is_string($type) && $type !== '' ? $type : $settings->default_type,
                    'scheduled'
                );
            } else {
                $backup = $backups->runScheduled();
                if ($backup === null) {
                    $this->info('Automatic backups are disabled.');

                    return self::SUCCESS;
                }
            }
        } catch (Throwable $e) {
            $this->error($e->getMessage());

            return self::FAILURE;
        }

        $this->info(sprintf(
            'Backup %s completed (%s, %d bytes).',
            $backup->id,
            $backup->type,
            $backup->size_bytes
        ));

        return self::SUCCESS;
    }
}
