<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Notifications\VerifyEmailNotification;
use Illuminate\Auth\Events\Verified;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class EmailVerificationController extends Controller
{
    public function send(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        if ($user->hasVerifiedEmail()) {
            return response()->json(['message' => 'E-mail déjà vérifié.']);
        }

        $user->notify(new VerifyEmailNotification);

        return response()->json(['message' => 'E-mail de vérification envoyé.']);
    }

    public function verify(Request $request, string $id, string $hash): JsonResponse
    {
        $user = User::query()->findOrFail($id);

        if (! hash_equals(sha1($user->getEmailForVerification()), $hash)) {
            return response()->json(['message' => 'Lien de vérification invalide.'], 403);
        }

        if ($user->hasVerifiedEmail()) {
            return response()->json(['message' => 'E-mail déjà vérifié.']);
        }

        if ($user->markEmailAsVerified()) {
            event(new Verified($user));
        }

        return response()->json(['message' => 'E-mail vérifié avec succès.']);
    }

    public function status(Request $request): JsonResponse
    {
        return response()->json([
            'email_verified' => $request->user()->hasVerifiedEmail(),
        ]);
    }
}
