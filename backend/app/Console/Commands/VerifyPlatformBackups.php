<?php

namespace App\Console\Commands;

use App\Models\PlatformBackup;
use App\Services\Platform\Backup\BackupService;
use Illuminate\Console\Command;
use Throwable;

class VerifyPlatformBackups extends Command
{
    protected $signature = 'backups:verify {backup? : Backup UUID}';

    protected $description = 'Verify checksum and archive integrity of the latest or given backup';

    public function handle(BackupService $backups): int
    {
        $id = $this->argument('backup');
        $backup = $id
            ? PlatformBackup::query()->findOrFail($id)
            : PlatformBackup::query()->where('status', 'completed')->orderByDesc('finished_at')->first();

        if (! $backup) {
            $this->warn('No completed backup to verify.');

            return self::SUCCESS;
        }

        try {
            $backups->verify($backup);
        } catch (Throwable $e) {
            $this->error($e->getMessage());

            return self::FAILURE;
        }

        $this->info('Verified backup '.$backup->id);

        return self::SUCCESS;
    }
}
