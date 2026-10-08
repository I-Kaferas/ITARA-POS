<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\PlatformBackup;
use App\Models\User;
use App\Services\Authorization\AuthorizationService;
use App\Services\Platform\Backup\BackupService;
use App\Services\Platform\PlatformAuditLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Throwable;

class PlatformBackupController extends Controller
{
    public function __construct(
        private readonly BackupService $backups,
        private readonly AuthorizationService $authorization,
        private readonly PlatformAuditLogger $audit,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $this->assertSuperAdmin($request);

        $rows = PlatformBackup::query()
            ->orderByDesc('created_at')
            ->limit(100)
            ->get()
            ->map(fn (PlatformBackup $backup) => $this->backups->serialize($backup))
            ->values();

        return response()->json([
            'data' => $rows,
            'policy' => $this->backups->policyPayload(),
            'disaster_recovery' => $this->backups->disasterRecovery(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $data = $request->validate([
            'type' => ['nullable', Rule::in(['database', 'files', 'full'])],
        ]);

        try {
            $backup = $this->backups->create($data['type'] ?? 'full', 'manual', $request->user());
        } catch (Throwable $e) {
            return response()->json([
                'message' => $e->getMessage(),
            ], 500);
        }

        $this->audit->record($request->user(), 'backup.created', null, [
            'backup_id' => $backup->id,
            'type' => $backup->type,
            'size_bytes' => $backup->size_bytes,
        ], $request->ip());

        return response()->json(['data' => $this->backups->serialize($backup)], 201);
    }

    public function show(Request $request, PlatformBackup $backup): JsonResponse
    {
        $this->assertSuperAdmin($request);

        return response()->json(['data' => $this->backups->serialize($backup)]);
    }

    public function destroy(Request $request, PlatformBackup $backup): JsonResponse
    {
        $this->assertSuperAdmin($request);

        $id = $backup->id;
        $this->backups->delete($backup);

        $this->audit->record($request->user(), 'backup.deleted', null, [
            'backup_id' => $id,
        ], $request->ip());

        return response()->json(['data' => ['deleted' => true]]);
    }

    public function download(Request $request, PlatformBackup $backup): StreamedResponse
    {
        $this->assertSuperAdmin($request);
        abort_unless($backup->isCompleted() && $backup->path, 404);
        abort_unless(\Illuminate\Support\Facades\Storage::disk($backup->disk)->exists($backup->path), 404);

        $this->audit->record($request->user(), 'backup.downloaded', null, [
            'backup_id' => $backup->id,
        ], $request->ip());

        return \Illuminate\Support\Facades\Storage::disk($backup->disk)
            ->download($backup->path, 'backup-'.$backup->id.'.zip');
    }

    public function verify(Request $request, PlatformBackup $backup): JsonResponse
    {
        $this->assertSuperAdmin($request);

        try {
            $backup = $this->backups->verify($backup);
        } catch (Throwable $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        $this->audit->record($request->user(), 'backup.verified', null, [
            'backup_id' => $backup->id,
            'checksum' => $backup->checksum,
        ], $request->ip());

        return response()->json(['data' => $this->backups->serialize($backup)]);
    }

    public function restore(Request $request, PlatformBackup $backup): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $data = $request->validate([
            'mode' => ['nullable', Rule::in(['dry_run', 'live'])],
            'database' => ['nullable', 'boolean'],
            'files' => ['nullable', 'boolean'],
            'confirm' => ['nullable', 'string'],
        ]);

        try {
            $restore = $this->backups->restore($backup, $data, $request->user());
        } catch (Throwable $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        $this->audit->record($request->user(), 'backup.restored', null, [
            'backup_id' => $backup->id,
            'restore_id' => $restore->id,
            'mode' => $restore->mode,
            'options' => $restore->options,
        ], $request->ip());

        return response()->json([
            'data' => [
                'id' => $restore->id,
                'backup_id' => $restore->backup_id,
                'mode' => $restore->mode,
                'status' => $restore->status,
                'options' => $restore->options,
                'report' => $restore->report,
                'finished_at' => $restore->finished_at?->toIso8601String(),
            ],
        ]);
    }

    public function policy(Request $request): JsonResponse
    {
        $this->assertSuperAdmin($request);

        return response()->json(['data' => $this->backups->policyPayload()]);
    }

    public function updatePolicy(Request $request): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $data = $request->validate([
            'auto_enabled' => ['sometimes', 'boolean'],
            'schedule_time' => ['sometimes', 'date_format:H:i'],
            'default_type' => ['sometimes', Rule::in(['database', 'files', 'full'])],
            'keep_daily' => ['sometimes', 'integer', 'min:1', 'max:90'],
            'keep_weekly' => ['sometimes', 'integer', 'min:0', 'max:52'],
            'keep_monthly' => ['sometimes', 'integer', 'min:0', 'max:36'],
            'rpo_hours' => ['sometimes', 'integer', 'min:1', 'max:720'],
            'rto_minutes' => ['sometimes', 'integer', 'min:15', 'max:10080'],
        ]);

        $settings = $this->backups->updateSettings($data);
        $this->audit->record($request->user(), 'backup.policy_updated', null, $settings->toArray(), $request->ip());

        return response()->json(['data' => $this->backups->policyPayload()]);
    }

    public function disasterRecovery(Request $request): JsonResponse
    {
        $this->assertSuperAdmin($request);

        return response()->json(['data' => $this->backups->disasterRecovery()]);
    }

    public function prune(Request $request): JsonResponse
    {
        $this->assertSuperAdmin($request);
        $removed = $this->backups->prune();
        $this->audit->record($request->user(), 'backup.pruned', null, [
            'removed' => $removed,
        ], $request->ip());

        return response()->json(['data' => ['removed' => $removed]]);
    }

    private function assertSuperAdmin(Request $request): void
    {
        $user = $request->user();
        abort_unless($user instanceof User && $this->authorization->isSuperAdmin($user), 403);
    }
}
