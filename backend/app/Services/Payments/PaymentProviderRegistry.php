<?php

namespace App\Services\Payments;

use App\Enums\SalePaymentMethod;
use App\Services\Payments\Providers\BankTransferPaymentProvider;
use App\Services\Payments\Providers\CardPaymentProvider;
use App\Services\Payments\Providers\CashPaymentProvider;
use App\Services\Payments\Providers\CreditPaymentProvider;
use App\Services\Payments\Providers\MobileMoneyPaymentProvider;
use App\Services\Payments\Providers\WalletPaymentProvider;
use Illuminate\Validation\ValidationException;

class PaymentProviderRegistry
{
    /** @var array<string, PaymentProviderInterface> */
    private array $providers;

    public function __construct(
        CashPaymentProvider $cash,
        MobileMoneyPaymentProvider $mobileMoney,
        CardPaymentProvider $card,
        BankTransferPaymentProvider $bankTransfer,
        CreditPaymentProvider $credit,
        WalletPaymentProvider $wallet,
    ) {
        $this->providers = [];
        foreach ([$cash, $mobileMoney, $card, $bankTransfer, $credit, $wallet] as $provider) {
            $this->providers[$provider->method()->value] = $provider;
        }
    }

    public function resolve(SalePaymentMethod $method): PaymentProviderInterface
    {
        $provider = $this->providers[$method->value] ?? null;

        if ($provider === null) {
            throw ValidationException::withMessages([
                'payments' => ["Mode de paiement non pris en charge : {$method->value}."],
            ]);
        }

        return $provider;
    }
}
