<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Address;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class BusinessNotificationMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public string $headline,
        public string $bodyText,
        public ?string $fromAddress = null,
        public ?string $fromName = null,
    ) {}

    public function envelope(): Envelope
    {
        $from = null;
        if ($this->fromAddress) {
            $from = new Address($this->fromAddress, $this->fromName ?: null);
        }

        return new Envelope(
            from: $from,
            subject: $this->headline,
        );
    }

    public function content(): Content
    {
        return new Content(
            htmlString: '<p>'.nl2br(e($this->bodyText)).'</p>',
        );
    }
}
