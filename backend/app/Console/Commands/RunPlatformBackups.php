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
                $made = [
                    $backups->create(
                        is_string($type) && $type !== '' ? $type : $settings->default_type,
                        'scheduled'
                    ),
                ];
            } else {
                $made = $backups->runScheduled();
                if ($made === []) {
                    $this->info('Automatic backups are disabled.');

                    return self::SUCCESS;
                }
            }
        } catch (Throwable $e) {
            $this->error($e->getMessage());

            return self::FAILURE;
        }

        foreach ($made as $backup) {
            $company = $backup->tenant_id ? ' company '.$backup->tenant_id : ' platform';
            $this->info(sprintf(
                'Backup %s completed (%s, %s, %d bytes).',
                $backup->id,
                $backup->type,
                trim($company),
                $backup->size_bytes
            ));
        }

        return self::SUCCESS;
    }
}
