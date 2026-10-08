<?php

namespace App\Services\Platform\Backup;

use App\Models\PlatformBackup;
use App\Models\PlatformBackupRestore;
use App\Models\PlatformBackupSetting;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;
use Throwable;
use ZipArchive;

class BackupService
{
    public function __construct(
        private readonly DatabaseDumper $database,
        private readonly FileArchiver $files,
    ) {}

    public function settings(): PlatformBackupSetting
    {
        $row = PlatformBackupSetting::query()->first();
        if ($row) {
            return $row;
        }

        return PlatformBackupSetting::query()->create([
            'auto_enabled' => (bool) config('backup.auto_enabled', true),
            'schedule_time' => (string) config('backup.schedule_time', '02:30'),
            'default_type' => (string) config('backup.default_type', 'full'),
            'keep_daily' => (int) config('backup.retention.daily', 7),
            'keep_weekly' => (int) config('backup.retention.weekly', 4),
            'keep_monthly' => (int) config('backup.retention.monthly', 6),
            'rpo_hours' => (int) config('backup.rpo_hours', 36),
            'rto_minutes' => (int) config('backup.rto_minutes', 120),
        ]);
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function updateSettings(array $data): PlatformBackupSetting
    {
        $settings = $this->settings();
        $settings->fill($data);
        $settings->save();

        return $settings->fresh();
    }

    /**
     * @return array<string, mixed>
     */
    public function policyPayload(): array
    {
        $settings = $this->settings();

        return [
            'auto_enabled' => $settings->auto_enabled,
            'schedule_time' => $settings->schedule_time,
            'default_type' => $settings->default_type,
            'retention' => [
                'daily' => $settings->keep_daily,
                'weekly' => $settings->keep_weekly,
                'monthly' => $settings->keep_monthly,
            ],
            'rpo_hours' => $settings->rpo_hours,
            'rto_minutes' => $settings->rto_minutes,
            'disk' => (string) config('backup.disk', 'local'),
            'offsite_disk' => config('backup.offsite_disk'),
            'offsite_configured' => filled(config('backup.offsite_disk')),
        ];
    }

    public function create(string $type = 'full', string $trigger = 'manual', ?User $actor = null): PlatformBackup
    {
        $type = in_array($type, ['database', 'files', 'full'], true) ? $type : 'full';
        $disk = (string) config('backup.disk', 'local');
        $root = trim((string) config('backup.path', 'platform-backups'), '/');

        $backup = PlatformBackup::query()->create([
            'type' => $type,
            'trigger' => $trigger,
            'status' => 'running',
            'disk' => $disk,
            'includes' => [
                'database' => in_array($type, ['database', 'full'], true),
                'files' => in_array($type, ['files', 'full'], true),
            ],
            'started_at' => now(),
            'created_by' => $actor?->id,
        ]);

        $relativeDir = $root.'/'.$backup->id;
        $absoluteDir = Storage::disk($disk)->path($relativeDir);
        File::ensureDirectoryExists($absoluteDir);

        try {
            $meta = [
                'app' => config('app.name'),
                'env' => config('app.env'),
                'version' => config('app.version', null),
                'php' => PHP_VERSION,
            ];

            if ($backup->includes['database'] ?? false) {
                $dbPath = $absoluteDir.'/database.sql';
                $meta['database'] = $this->database->dump($dbPath);
            }

            if ($backup->includes['files'] ?? false) {
                $filesPath = $absoluteDir.'/files.zip';
                $meta['files'] = $this->files->archive(
                    $filesPath,
                    config('backup.file_sources', []),
                    array_merge(config('backup.exclude_prefixes', []), [$root]),
                );
            }

            $manifest = [
                'id' => $backup->id,
                'type' => $backup->type,
                'trigger' => $backup->trigger,
                'created_at' => now()->toIso8601String(),
                'includes' => $backup->includes,
                'meta' => $meta,
            ];
            File::put($absoluteDir.'/manifest.json', json_encode($manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));

            $archiveRelative = $relativeDir.'/backup.zip';
            $archiveAbsolute = Storage::disk($disk)->path($archiveRelative);
            $this->packDirectory($absoluteDir, $archiveAbsolute, ['backup.zip']);

            $checksum = hash_file('sha256', $archiveAbsolute) ?: null;
            $size = (int) filesize($archiveAbsolute);

            $this->mirrorOffsite($disk, $archiveRelative);

            $backup->forceFill([
                'status' => 'completed',
                'path' => $archiveRelative,
                'size_bytes' => $size,
                'checksum' => $checksum,
                'meta' => $meta,
                'finished_at' => now(),
                'expires_at' => $this->estimateExpiry(now()),
                'error_message' => null,
            ])->save();

            $this->prune();

            return $backup->fresh();
        } catch (Throwable $e) {
            File::deleteDirectory($absoluteDir);
            $backup->forceFill([
                'status' => 'failed',
                'error_message' => Str::limit($e->getMessage(), 2000),
                'finished_at' => now(),
            ])->save();

            throw $e;
        }
    }

    public function runScheduled(): ?PlatformBackup
    {
        $settings = $this->settings();
        if (! $settings->auto_enabled) {
            return null;
        }

        return $this->create($settings->default_type, 'scheduled');
    }

    public function delete(PlatformBackup $backup): void
    {
        $this->deleteArchive($backup);
        $backup->delete();
    }

    public function prune(): int
    {
        $settings = $this->settings();
        $keep = $this->retentionKeepIds($settings);
        $removed = 0;

        PlatformBackup::query()
            ->where('status', 'completed')
            ->orderByDesc('finished_at')
            ->each(function (PlatformBackup $backup) use ($keep, &$removed): void {
                if (isset($keep[$backup->id])) {
                    return;
                }
                $this->delete($backup);
                $removed++;
            });

        PlatformBackup::query()
            ->where('status', 'failed')
            ->where('created_at', '<', now()->subDays(7))
            ->each(function (PlatformBackup $backup): void {
                $this->delete($backup);
            });

        return $removed;
    }

    public function verify(PlatformBackup $backup): PlatformBackup
    {
        if (! $backup->isCompleted() || ! $backup->path) {
            throw new RuntimeException('Only completed backups can be verified.');
        }

        $absolute = Storage::disk($backup->disk)->path($backup->path);
        if (! is_file($absolute)) {
            throw new RuntimeException('Backup archive is missing on disk.');
        }

        $checksum = hash_file('sha256', $absolute);
        if ($backup->checksum && ! hash_equals($backup->checksum, (string) $checksum)) {
            throw new RuntimeException('Backup checksum mismatch.');
        }

        $zip = new ZipArchive;
        if ($zip->open($absolute) !== true) {
            throw new RuntimeException('Backup archive is corrupt.');
        }
        $hasManifest = $zip->locateName('manifest.json') !== false;
        $zip->close();
        if (! $hasManifest) {
            throw new RuntimeException('Backup archive is missing manifest.json.');
        }

        $backup->forceFill(['verified_at' => now()])->save();

        return $backup->fresh();
    }

    /**
     * @param  array{database?: bool, files?: bool, confirm?: string}  $options
     */
    public function restore(PlatformBackup $backup, array $options, ?User $actor = null): PlatformBackupRestore
    {
        $dryRun = ($options['mode'] ?? 'dry_run') !== 'live';
        $wantDatabase = (bool) ($options['database'] ?? ($backup->includes['database'] ?? false));
        $wantFiles = (bool) ($options['files'] ?? ($backup->includes['files'] ?? false));

        if (! $dryRun && ($options['confirm'] ?? null) !== 'RESTORE') {
            throw new RuntimeException('Live restore requires confirm=RESTORE.');
        }

        $restore = PlatformBackupRestore::query()->create([
            'backup_id' => $backup->id,
            'mode' => $dryRun ? 'dry_run' : 'live',
            'status' => 'running',
            'options' => [
                'database' => $wantDatabase,
                'files' => $wantFiles,
            ],
            'started_by' => $actor?->id,
            'started_at' => now(),
        ]);

        $work = storage_path('app/private/platform-backups/.restore/'.$restore->id);
        File::ensureDirectoryExists($work);

        try {
            $this->verify($backup);
            $absolute = Storage::disk($backup->disk)->path($backup->path);
            $this->extractZip($absolute, $work);

            $report = [
                'manifest' => null,
                'database' => null,
                'files' => null,
            ];

            $manifestPath = $work.'/manifest.json';
            if (is_file($manifestPath)) {
                $report['manifest'] = json_decode((string) file_get_contents($manifestPath), true);
            }

            if ($wantDatabase) {
                $dbDump = $work.'/database.sql';
                if (! is_file($dbDump)) {
                    throw new RuntimeException('Backup does not contain database.sql.');
                }
                if ($dryRun) {
                    $report['database'] = [
                        'bytes' => filesize($dbDump),
                        'lines' => substr_count((string) file_get_contents($dbDump), "\n"),
                        'action' => 'validated',
                    ];
                } else {
                    $this->database->restore($dbDump);
                    $report['database'] = ['action' => 'restored'];
                }
            }

            if ($wantFiles) {
                $filesZip = $work.'/files.zip';
                if (! is_file($filesZip)) {
                    throw new RuntimeException('Backup does not contain files.zip.');
                }
                $report['files'] = $this->files->extract($filesZip, write: ! $dryRun);
                $report['files']['action'] = $dryRun ? 'validated' : 'restored';
            }

            $restore->forceFill([
                'status' => 'completed',
                'report' => $report,
                'finished_at' => now(),
                'error_message' => null,
            ])->save();

            return $restore->fresh();
        } catch (Throwable $e) {
            $restore->forceFill([
                'status' => 'failed',
                'error_message' => Str::limit($e->getMessage(), 2000),
                'finished_at' => now(),
            ])->save();
            throw $e;
        } finally {
            File::deleteDirectory($work);
        }
    }

    /**
     * @return array<string, mixed>
     */
    public function disasterRecovery(): array
    {
        $settings = $this->settings();
        $latest = PlatformBackup::query()
            ->where('status', 'completed')
            ->orderByDesc('finished_at')
            ->first();
        $verified = PlatformBackup::query()
            ->where('status', 'completed')
            ->whereNotNull('verified_at')
            ->orderByDesc('verified_at')
            ->first();
        $drill = PlatformBackupRestore::query()
            ->where('mode', 'dry_run')
            ->where('status', 'completed')
            ->orderByDesc('finished_at')
            ->first();

        $ageHours = $latest?->finished_at ? $latest->finished_at->diffInMinutes(now()) / 60 : null;
        $withinRpo = $ageHours !== null && $ageHours <= $settings->rpo_hours;

        $checklist = [
            [
                'key' => 'recent_backup',
                'ok' => $withinRpo,
                'detail' => $latest
                    ? 'Last backup '.$latest->finished_at?->toIso8601String()
                    : 'No completed backup',
            ],
            [
                'key' => 'integrity_verified',
                'ok' => $verified !== null && $verified->verified_at?->greaterThan(now()->subDays(7)),
                'detail' => $verified?->verified_at?->toIso8601String() ?? 'Never verified',
            ],
            [
                'key' => 'restore_drill',
                'ok' => $drill !== null && $drill->finished_at?->greaterThan(now()->subDays(30)),
                'detail' => $drill?->finished_at?->toIso8601String() ?? 'No dry-run restore in the last 30 days',
            ],
            [
                'key' => 'offsite_copy',
                'ok' => filled(config('backup.offsite_disk')),
                'detail' => filled(config('backup.offsite_disk'))
                    ? 'Offsite disk: '.config('backup.offsite_disk')
                    : 'BACKUP_OFFSITE_DISK is not configured',
            ],
            [
                'key' => 'auto_schedule',
                'ok' => (bool) $settings->auto_enabled,
                'detail' => $settings->auto_enabled
                    ? 'Automatic backups at '.$settings->schedule_time
                    : 'Automatic backups disabled',
            ],
        ];

        $ready = collect($checklist)->every(fn (array $item) => $item['ok']);

        return [
            'ready' => $ready,
            'rpo_hours' => $settings->rpo_hours,
            'rto_minutes' => $settings->rto_minutes,
            'last_backup' => $latest ? $this->serialize($latest) : null,
            'last_verified' => $verified ? $this->serialize($verified) : null,
            'last_drill' => $drill ? [
                'id' => $drill->id,
                'backup_id' => $drill->backup_id,
                'finished_at' => $drill->finished_at?->toIso8601String(),
            ] : null,
            'age_hours' => $ageHours !== null ? round($ageHours, 2) : null,
            'within_rpo' => $withinRpo,
            'checklist' => $checklist,
            'runbook' => [
                '1. Confirm the latest completed backup and verify checksum.',
                '2. Run a dry-run restore (disaster recovery drill).',
                '3. Put the application in maintenance mode.',
                '4. Live-restore database and/or files with confirm=RESTORE.',
                '5. Run migrations if the dump is data-only, then smoke-test login and POS.',
                '6. Re-enable traffic and record the incident in the platform audit log.',
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function serialize(PlatformBackup $backup): array
    {
        return [
            'id' => $backup->id,
            'type' => $backup->type,
            'trigger' => $backup->trigger,
            'status' => $backup->status,
            'disk' => $backup->disk,
            'path' => $backup->path,
            'size_bytes' => $backup->size_bytes,
            'checksum' => $backup->checksum,
            'includes' => $backup->includes,
            'meta' => $backup->meta,
            'error_message' => $backup->error_message,
            'started_at' => $backup->started_at?->toIso8601String(),
            'finished_at' => $backup->finished_at?->toIso8601String(),
            'verified_at' => $backup->verified_at?->toIso8601String(),
            'expires_at' => $backup->expires_at?->toIso8601String(),
            'created_by' => $backup->created_by,
            'created_at' => $backup->created_at?->toIso8601String(),
        ];
    }

    private function estimateExpiry(Carbon $from): Carbon
    {
        $settings = $this->settings();
        $days = max($settings->keep_daily, $settings->keep_weekly * 7, $settings->keep_monthly * 31);

        return $from->copy()->addDays($days);
    }

    /** @return array<string, true> */
    private function retentionKeepIds(PlatformBackupSetting $settings): array
    {
        $completed = PlatformBackup::query()
            ->where('status', 'completed')
            ->whereNotNull('finished_at')
            ->orderByDesc('finished_at')
            ->get();

        $keep = [];
        $daily = 0;
        $weekly = [];
        $monthly = [];

        foreach ($completed as $backup) {
            /** @var PlatformBackup $backup */
            $finished = $backup->finished_at;
            if (! $finished) {
                continue;
            }

            if ($daily < $settings->keep_daily) {
                $keep[$backup->id] = true;
                $daily++;
            }

            $weekKey = $finished->format('o-W');
            if (! isset($weekly[$weekKey]) && count($weekly) < $settings->keep_weekly) {
                $weekly[$weekKey] = true;
                $keep[$backup->id] = true;
            }

            $monthKey = $finished->format('Y-m');
            if (! isset($monthly[$monthKey]) && count($monthly) < $settings->keep_monthly) {
                $monthly[$monthKey] = true;
                $keep[$backup->id] = true;
            }
        }

        return $keep;
    }

    /** @param  list<string>  $skipNames */
    private function packDirectory(string $directory, string $zipAbsolutePath, array $skipNames = []): void
    {
        $zip = new ZipArchive;
        if ($zip->open($zipAbsolutePath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) {
            throw new RuntimeException('Unable to create backup archive.');
        }

        try {
            foreach (File::files($directory) as $file) {
                $name = $file->getFilename();
                if (in_array($name, $skipNames, true)) {
                    continue;
                }
                $zip->addFile($file->getPathname(), $name);
            }
        } finally {
            $zip->close();
        }
    }

    private function extractZip(string $zipAbsolutePath, string $destination): void
    {
        $zip = new ZipArchive;
        if ($zip->open($zipAbsolutePath) !== true) {
            throw new RuntimeException('Unable to open backup archive.');
        }
        try {
            if (! $zip->extractTo($destination)) {
                throw new RuntimeException('Unable to extract backup archive.');
            }
        } finally {
            $zip->close();
        }
    }

    private function deleteArchive(PlatformBackup $backup): void
    {
        if (! $backup->path) {
            return;
        }
        $dir = dirname($backup->path);
        Storage::disk($backup->disk)->deleteDirectory($dir);

        $offsite = config('backup.offsite_disk');
        if (filled($offsite)) {
            try {
                Storage::disk((string) $offsite)->delete($backup->path);
            } catch (Throwable) {
                // ignore offsite cleanup failures
            }
        }
    }

    private function mirrorOffsite(string $disk, string $relativePath): void
    {
        $offsite = config('backup.offsite_disk');
        if (! filled($offsite) || $offsite === $disk) {
            return;
        }

        $stream = Storage::disk($disk)->readStream($relativePath);
        if ($stream === false) {
            return;
        }
        Storage::disk((string) $offsite)->put($relativePath, $stream);
        if (is_resource($stream)) {
            fclose($stream);
        }
    }
}
