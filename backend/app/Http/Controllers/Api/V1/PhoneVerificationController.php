<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\Auth\PhoneVerificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PhoneVerificationController extends Controller
{
    public function __construct(private PhoneVerificationService $phoneVerification) {}

    public function send(Request $request): JsonResponse
    {
        $data = $request->validate([
            'phone' => ['required', 'string', 'max:50'],
        ]);

        $code = $this->phoneVerification->sendCode($request->user(), $data['phone']);

        $payload = ['message' => 'Code de vérification envoyé.'];

        if (! app()->environment('production')) {
            $payload['debug_code'] = $code;
        }

        return response()->json($payload);
    }

    public function verify(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code' => ['required', 'string', 'size:6'],
        ]);

        $this->phoneVerification->verify($request->user(), $data['code']);

        return response()->json(['message' => 'Numéro de téléphone vérifié.']);
    }
}
