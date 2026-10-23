<?php

namespace App\Support;

use chillerlan\QRCode\QRCode;
use chillerlan\QRCode\QROptions;

class QrCodeSvg
{
    public static function render(string $payload): string
    {
        $options = new QROptions([
            'outputType' => QRCode::OUTPUT_MARKUP_SVG,
            'outputBase64' => false,
            'eccLevel' => QRCode::ECC_M,
            'scale' => 6,
            'addQuietzone' => true,
        ]);

        $svg = (new QRCode($options))->render($payload);

        return is_string($svg) ? $svg : '';
    }
}
