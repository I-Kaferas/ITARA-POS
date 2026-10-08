<?php

namespace App\Services\Platform\Backup;

use Illuminate\Support\Facades\Storage;
use RuntimeException;
use ZipArchive;

class FileArchiver
{
    /**
     * @param  list<array{disk: string, path: string}>  $sources
     * @param  list<string>  $excludePrefixes
     * @return array{files: int, bytes: int}
     */
    public function archive(string $zipAbsolutePath, array $sources, array $excludePrefixes = []): array
    {
        $zip = new ZipArchive;
        if ($zip->open($zipAbsolutePath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) {
            throw new RuntimeException('Unable to create files archive.');
        }

        $count = 0;
        $bytes = 0;

        try {
            foreach ($sources as $source) {
                $diskName = $source['disk'];
                $prefix = ltrim($source['path'] ?? '', '/');
                $disk = Storage::disk($diskName);
                $files = $prefix === '' ? $disk->allFiles() : $disk->allFiles($prefix);

                foreach ($files as $relative) {
                    if ($this->excluded($relative, $excludePrefixes)) {
                        continue;
                    }
                    $absolute = $disk->path($relative);
                    if (! is_file($absolute)) {
                        continue;
                    }
                    $entry = $diskName.'/'.ltrim(str_replace('\\', '/', $relative), '/');
                    if (! $zip->addFile($absolute, $entry)) {
                        continue;
                    }
                    $count++;
                    $bytes += (int) filesize($absolute);
                }
            }
        } finally {
            $zip->close();
        }

        return ['files' => $count, 'bytes' => $bytes];
    }

    /**
     * @return array{files: int}
     */
    public function extract(string $zipAbsolutePath, bool $write = true): array
    {
        $zip = new ZipArchive;
        if ($zip->open($zipAbsolutePath) !== true) {
            throw new RuntimeException('Unable to open files archive.');
        }

        $files = 0;
        try {
            for ($i = 0; $i < $zip->numFiles; $i++) {
                $name = $zip->getNameIndex($i);
                if ($name === false || str_ends_with($name, '/')) {
                    continue;
                }
                $files++;
                if (! $write) {
                    continue;
                }

                [$diskName, $relative] = $this->splitEntry($name);
                $contents = $zip->getFromIndex($i);
                if ($contents === false) {
                    continue;
                }
                Storage::disk($diskName)->put($relative, $contents);
            }
        } finally {
            $zip->close();
        }

        return ['files' => $files];
    }

    /** @param  list<string>  $excludePrefixes */
    private function excluded(string $relative, array $excludePrefixes): bool
    {
        $normalized = ltrim(str_replace('\\', '/', $relative), '/');
        foreach ($excludePrefixes as $prefix) {
            $prefix = trim(str_replace('\\', '/', $prefix), '/');
            if ($prefix !== '' && ($normalized === $prefix || str_starts_with($normalized, $prefix.'/'))) {
                return true;
            }
        }

        return false;
    }

    /** @return array{0: string, 1: string} */
    private function splitEntry(string $entry): array
    {
        $entry = ltrim(str_replace('\\', '/', $entry), '/');
        $parts = explode('/', $entry, 2);
        if (count($parts) < 2) {
            throw new RuntimeException('Invalid archive entry: '.$entry);
        }

        return [$parts[0], $parts[1]];
    }
}
