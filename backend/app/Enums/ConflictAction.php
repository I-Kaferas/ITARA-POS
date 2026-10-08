<?php

namespace App\Enums;

enum ConflictAction: string
{
    /** Proceed with the incoming change. */
    case Apply = 'apply';

    /** Keep the server / master copy; treat as resolved. */
    case KeepServer = 'keep_server';

    /** Reject the write and report a conflict. */
    case Reject = 'reject';

    /** Rewrite an absolute stock write as a movement delta when possible. */
    case RewriteAsMovement = 'rewrite_as_movement';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    public function isConflict(): bool
    {
        return $this === self::Reject || $this === self::RewriteAsMovement;
    }
}
