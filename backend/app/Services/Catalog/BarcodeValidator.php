<?php

namespace App\Services\Catalog;

use Illuminate\Validation\ValidationException;

class BarcodeValidator
{
    /** @var list<string> */
    public static function supportedTypes(): array
    {
        return array_keys(config('product_types.barcode_types', []));
    }

    public static function validate(string $barcode, string $type): void
    {
        $barcode = trim($barcode);

        match ($type) {
            'ean13' => self::validateEan13($barcode, 13),
            'ean8' => self::validateEan13($barcode, 8),
            'upc' => self::validateUpc($barcode),
            'code128' => self::validateCode128($barcode),
            'qr' => self::validateQr($barcode),
            'internal' => self::validateInternal($barcode),
            default => throw ValidationException::withMessages([
                'type' => ['Unsupported barcode type.'],
            ]),
        };
    }

    public static function detectType(string $barcode): string
    {
        $barcode = trim($barcode);

        if (preg_match('/^\d{13}$/', $barcode) && self::hasValidEanChecksum($barcode)) {
            return 'ean13';
        }

        if (preg_match('/^\d{8}$/', $barcode) && self::hasValidEanChecksum($barcode)) {
            return 'ean8';
        }

        if (preg_match('/^\d{12}$/', $barcode) && self::hasValidEanChecksum('0'.$barcode)) {
            return 'upc';
        }

        if (strlen($barcode) > 40 || str_contains($barcode, '://')) {
            return 'qr';
        }

        if (preg_match('/^[\x20-\x7E]+$/', $barcode)) {
            return 'code128';
        }

        return 'internal';
    }

    public static function computeEanCheckDigit(string $digits): int
    {
        $sum = 0;
        $length = strlen($digits);

        for ($i = 0; $i < $length; $i++) {
            $digit = (int) $digits[$i];
            $sum += ($length - $i) % 2 === 0 ? $digit * 3 : $digit;
        }

        return (10 - ($sum % 10)) % 10;
    }

    private static function validateEan13(string $barcode, int $length): void
    {
        if (! preg_match('/^\d{'.$length.'}$/', $barcode)) {
            throw ValidationException::withMessages([
                'barcode' => ["EAN-{$length} must be exactly {$length} digits."],
            ]);
        }

        if (! self::hasValidEanChecksum($barcode)) {
            throw ValidationException::withMessages([
                'barcode' => ['Invalid EAN check digit.'],
            ]);
        }
    }

    private static function validateUpc(string $barcode): void
    {
        if (! preg_match('/^\d{12}$/', $barcode)) {
            throw ValidationException::withMessages([
                'barcode' => ['UPC must be exactly 12 digits.'],
            ]);
        }

        if (! self::hasValidEanChecksum('0'.$barcode)) {
            throw ValidationException::withMessages([
                'barcode' => ['Invalid UPC check digit.'],
            ]);
        }
    }

    private static function validateCode128(string $barcode): void
    {
        if ($barcode === '' || strlen($barcode) > 80) {
            throw ValidationException::withMessages([
                'barcode' => ['Code 128 must be 1–80 printable ASCII characters.'],
            ]);
        }

        if (! preg_match('/^[\x20-\x7E]+$/', $barcode)) {
            throw ValidationException::withMessages([
                'barcode' => ['Code 128 contains invalid characters.'],
            ]);
        }
    }

    private static function validateQr(string $barcode): void
    {
        if ($barcode === '' || strlen($barcode) > 100) {
            throw ValidationException::withMessages([
                'barcode' => ['QR code payload must be 1–100 characters.'],
            ]);
        }
    }

    private static function validateInternal(string $barcode): void
    {
        if ($barcode === '' || strlen($barcode) > 100) {
            throw ValidationException::withMessages([
                'barcode' => ['Internal barcode must be 1–100 characters.'],
            ]);
        }
    }

    private static function hasValidEanChecksum(string $barcode): bool
    {
        $body = substr($barcode, 0, -1);
        $check = (int) substr($barcode, -1);

        return self::computeEanCheckDigit($body) === $check;
    }
}
