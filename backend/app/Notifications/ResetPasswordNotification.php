<?php

namespace App\Notifications;

use Illuminate\Auth\Notifications\ResetPassword as BaseResetPassword;
use Illuminate\Notifications\Messages\MailMessage;

class ResetPasswordNotification extends BaseResetPassword
{
    public function toMail($notifiable): MailMessage
    {
        $frontendUrl = rtrim((string) config('app.frontend_url', config('app.url')), '/');
        $url = $frontendUrl.'/reset-password?token='.$this->token.'&email='.urlencode($notifiable->getEmailForPasswordReset());

        return (new MailMessage)
            ->subject('Réinitialisation de mot de passe')
            ->line('Vous recevez cet e-mail car nous avons reçu une demande de réinitialisation de mot de passe.')
            ->action('Réinitialiser le mot de passe', $url)
            ->line('Ce lien expirera dans '.config('auth.passwords.users.expire').' minutes.')
            ->line('Si vous n\'avez pas demandé de réinitialisation, ignorez cet e-mail.');
    }
}
