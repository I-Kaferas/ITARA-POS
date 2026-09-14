<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

class TerminalBackupController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $root = $this->root($request);
        if (! Storage::disk('local')->exists($root)) {
            return response()->json(['data' => []]);
        }

        $rows = [];
        foreach (Storage::disk('local')->directories($root) as $dir) {
            $id = basename($dir);
            $manifest = $this->manifest($dir);
            $rows[] = [
                'id' => $id,
                'created_at' => $manifest['created_at'] ?? null,
                'platform' => $manifest['platform'] ?? null,
                'sync_events' => $manifest['sync_events'] ?? null,
                'device' => $request->header('X-Device-Name') ?: $request->header('X-Device-ID'),
            ];
        }

        usort($rows, fn (array $a, array $b) => strcmp((string) ($b['created_at'] ?? $b['id']), (string) ($a['created_at'] ?? $a['id'])));

        return response()->json(['data' => array_slice($rows, 0, 12)]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'manifest' => ['required', 'file', 'max:512'],
            'database' => ['required', 'file', 'max:51200'],
            'configuration' => ['required', 'file', 'max:512'],
            'sync_events' => ['nullable', 'file', 'max:20480'],
            'logs' => ['nullable', 'file', 'max:2048'],
        ]);

        $id = now()->format('Ymd-His').'-'.substr(bin2hex(random_bytes(3)), 0, 6);
        $dir = $this->root($request).'/'.$id;
        Storage::disk('local')->putFileAs($dir.'/database', $data['database'], 'pos_offline.sqlite');
        Storage::disk('local')->putFileAs($dir, $data['manifest'], 'manifest.json');
        Storage::disk('local')->putFileAs($dir, $data['configuration'], 'configuration.json');
        if (! empty($data['sync_events'])) {
            Storage::disk('local')->putFileAs($dir, $data['sync_events'], 'sync_events.json');
        }
        if (! empty($data['logs'])) {
            Storage::disk('local')->putFileAs($dir.'/logs', $data['logs'], 'backup.log');
        }

        return response()->json(['data' => ['id' => $id, 'stored' => true]], 201);
    }

    public function download(Request $request, string $backup, string $name): StreamedResponse
    {
        $files = [
            'manifest' => 'manifest.json',
            'database' => 'database/pos_offline.sqlite',
            'configuration' => 'configuration.json',
            'sync-events' => 'sync_events.json',
            'logs' => 'logs/backup.log',
        ];
        if (! isset($files[$name]) || ! preg_match('/^[A-Za-z0-9._-]+$/', $backup)) {
            abort(404);
        }

        $path = $this->root($request).'/'.$backup.'/'.$files[$name];
        if (! Storage::disk('local')->exists($path)) {
            abort(404);
        }

        return Storage::disk('local')->download($path, basename($files[$name]));
    }

    private function root(Request $request): string
    {
        $tenant = preg_replace('/[^A-Za-z0-9_-]/', '', (string) $request->user()?->tenant_id) ?: 'tenant';
        $device = preg_replace('/[^A-Za-z0-9_-]/', '', (string) ($request->header('X-Device-ID') ?: 'device')) ?: 'device';

        return 'terminal-backups/'.$tenant.'/'.$device;
    }

    /** @return array<string, mixed> */
    private function manifest(string $dir): array
    {
        $path = $dir.'/manifest.json';
        if (! Storage::disk('local')->exists($path)) {
            return [];
        }

        $decoded = json_decode(Storage::disk('local')->get($path), true);

        return is_array($decoded) ? $decoded : [];
    }
}
