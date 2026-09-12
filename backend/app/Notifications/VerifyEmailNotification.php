<?php

namespace App\Notifications;

use Illuminate\Auth\Notifications\VerifyEmail as BaseVerifyEmail;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\URL;

class VerifyEmailNotification extends BaseVerifyEmail
{
    public function toMail($notifiable): MailMessage
    {
        $verificationUrl = $this->verificationUrl($notifiable);

        return (new MailMessage)
            ->subject('Vérification de votre adresse e-mail')
            ->line('Cliquez sur le bouton ci-dessous pour vérifier votre adresse e-mail.')
            ->action('Vérifier l\'e-mail', $verificationUrl)
            ->line('Si vous n\'avez pas créé de compte, ignorez cet e-mail.');
    }

    protected function verificationUrl($notifiable): string
    {
        $frontendUrl = rtrim((string) config('app.frontend_url', config('app.url')), '/');

        return URL::temporarySignedRoute(
            'verification.verify',
            Carbon::now()->addMinutes(Config::get('auth.verification.expire', 60)),
            [
                'id' => $notifiable->getKey(),
                'hash' => sha1($notifiable->getEmailForVerification()),
            ],
            absolute: true
        ).'&redirect='.urlencode($frontendUrl.'/verify-email');
    }
}
