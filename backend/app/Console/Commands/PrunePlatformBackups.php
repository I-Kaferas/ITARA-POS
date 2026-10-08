<?php

namespace App\Console\Commands;

use App\Services\Platform\Backup\BackupService;
use Illuminate\Console\Command;

class PrunePlatformBackups extends Command
{
    protected $signature = 'backups:prune';

    protected $description = 'Apply the platform backup retention policy';

    public function handle(BackupService $backups): int
    {
        $removed = $backups->prune();
        $this->info('Removed '.$removed.' backup(s).');

        return self::SUCCESS;
    }
}
