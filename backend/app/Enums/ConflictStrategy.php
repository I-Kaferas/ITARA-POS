<?php

namespace App\Enums;

enum ConflictStrategy: string
{
    /** Completed / final sales must never be overwritten. */
    case NeverOverwriteCompleted = 'never_overwrite_completed';

    /** Stock levels change only through movements, never absolute overwrites. */
    case StockMovements = 'stock_movements';

    /** Master (server) configuration always wins over slave / client copies. */
    case MasterWins = 'master_wins';

    /** Surface the conflict for an operator to resolve. */
    case Manual = 'manual';

    /** Silently keep the server copy. */
    case ServerWins = 'server_wins';

    /** Allow the incoming client / slave copy. */
    case ClientWins = 'client_wins';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
