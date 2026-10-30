<?php

namespace App\Services\Payments\Providers;

use App\DTOs\Payments\PaymentContext;
use App\DTOs\Payments\PaymentLineInput;
use App\DTOs\Payments\PaymentLineResult;
use App\Enums\SalePaymentMethod;
use App\Models\PaymentTransaction;
use App\Services\Audit\AuditLogService;
use App\Services\Desk\HospitalityDesk;
use Illuminate\Validation\ValidationException;

class RoomChargePaymentProvider extends AbstractPaymentProvider
{
    public function __construct(
        private readonly HospitalityDesk $desk,
        private readonly AuditLogService $audit,
    ) {}

    public function method(): SalePaymentMethod
    {
        return SalePaymentMethod::Room;
    }

    public function validate(PaymentLineInput $line, PaymentContext $context): void
    {
        parent::validate($line, $context);

        $reservationId = trim((string) ($line->metadata['reservation_id'] ?? ''));
        if ($reservationId === '') {
            throw ValidationException::withMessages([
                'reservation_id' => ['Choisissez le séjour à facturer.'],
            ]);
        }
    }

    public function initiate(
        PaymentLineInput $line,
        PaymentContext $context,
        PaymentTransaction $transaction,
    ): PaymentLineResult {
        $sale = $context->sale;
        if ($sale === null) {
            throw ValidationException::withMessages([
                'sale_id' => ['La vente à imputer est introuvable.'],
            ]);
        }
        $reservationId = trim((string) ($line->metadata['reservation_id'] ?? ''));
        $hotelStoreId = trim((string) ($line->metadata['hotel_store_id'] ?? '')) ?: null;

        $this->desk->postSaleCharge(
            $context->store,
            $sale,
            $reservationId,
            $line->appliedAmount(),
            $hotelStoreId,
        );

        $this->audit->log(
            action: 'sale.charged_to_stay',
            entity: $sale,
            userId: $context->processedBy?->id,
            payload: [
                'reservation_id' => $reservationId,
                'hotel_store_id' => $hotelStoreId ?? $context->store->id,
                'amount' => $line->appliedAmount(),
                'reference' => $sale->reference,
            ],
        );

        return $this->complete(
            transaction: $transaction,
            providerReference: $this->generateReference('STY'),
            metadata: [
                'reservation_id' => $reservationId,
                'hotel_store_id' => $hotelStoreId ?? $context->store->id,
            ],
        );
    }
}
