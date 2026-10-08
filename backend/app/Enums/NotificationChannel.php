<?php

namespace App\Enums;

enum NotificationChannel: string
{
    case Application = 'application';
    case Email = 'email';
    case Sms = 'sms';
    case WhatsApp = 'whatsapp';
    case Push = 'push';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    /** @return list<string> */
    public function configKeys(): array
    {
        return match ($this) {
            self::Application => [],
            self::Email => ['from_name', 'from_address'],
            self::Sms => ['endpoint', 'api_key', 'sender'],
            self::WhatsApp => ['phone_number_id', 'access_token'],
            self::Push => ['server_key'],
        };
    }

    /** @return list<string> */
    public function secretKeys(): array
    {
        return match ($this) {
            self::Sms => ['api_key'],
            self::WhatsApp => ['access_token'],
            self::Push => ['server_key'],
            default => [],
        };
    }
}
