<?php

namespace App\Services\Rbac;

class PermissionCatalog
{
    /**
     * @return array<string, array{0: string, 1: string}>
     */
    public static function definitions(): array
    {
        $permissions = config('rbac.permissions', []);

        foreach ($permissions as $slug => [$name, $group]) {
            if (! str_ends_with($slug, '.manage')) {
                continue;
            }

            $base = substr($slug, 0, -strlen('.manage'));
            $subject = preg_replace('/^Manage\s+/i', '', $name) ?: $base;

            foreach (['create' => 'Create', 'update' => 'Update', 'delete' => 'Delete'] as $action => $verb) {
                $crudSlug = $base.'.'.$action;
                if (! isset($permissions[$crudSlug])) {
                    $permissions[$crudSlug] = ["{$verb} {$subject}", $group];
                }
            }
        }

        return $permissions;
    }
}
