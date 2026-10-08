<?php

namespace App\DTOs\Transactions;

use App\Enums\TransactionPaymentStatus;
use App\Enums\TransactionStatus;
use App\Enums\TransactionType;
use Illuminate\Database\Eloquent\Model;

final readonly class TransactionInput
{
    /**
     * @param  array<string, mixed>|null  $metadata
     */
    public function __construct(
        public string $tenantId,
        public TransactionType $type,
        public int $amount,
        public string $currency,
        public ?string $branchId = null,
        public ?string $userId = null,
        public ?string $reference = null,
        public ?string $idempotencyKey = null,
        public ?string $date = null,
        public TransactionStatus $status = TransactionStatus::Completed,
        public ?TransactionPaymentStatus $paymentStatus = null,
        public ?Model $source = null,
        public ?array $metadata = null,
    ) {}

    /** @param  array<string, mixed>  $data */
    public static function fromArray(array $data): self
    {
        $type = $data['type'] instanceof TransactionType
            ? $data['type']
            : TransactionType::from((string) $data['type']);

        $status = isset($data['status'])
            ? ($data['status'] instanceof TransactionStatus
                ? $data['status']
                : TransactionStatus::from((string) $data['status']))
            : TransactionStatus::Completed;

        $paymentStatus = null;
        if (isset($data['payment_status'])) {
            $paymentStatus = $data['payment_status'] instanceof TransactionPaymentStatus
                ? $data['payment_status']
                : TransactionPaymentStatus::from((string) $data['payment_status']);
        }

        return new self(
            tenantId: (string) $data['tenant_id'],
            type: $type,
            amount: (int) $data['amount'],
            currency: strtoupper((string) ($data['currency'] ?? 'FBU')),
            branchId: $data['branch_id'] ?? null,
            userId: $data['user_id'] ?? null,
            reference: $data['reference'] ?? null,
            idempotencyKey: $data['idempotency_key'] ?? null,
            date: $data['date'] ?? null,
            status: $status,
            paymentStatus: $paymentStatus,
            source: $data['source'] ?? null,
            metadata: $data['metadata'] ?? null,
        );
    }
}
