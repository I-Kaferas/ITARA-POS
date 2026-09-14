<?php



namespace App\Enums;



enum SaleReturnRefundMethod: string

{

    case Cash = 'cash';

    case Card = 'card';

    case MobileMoney = 'mobile_money';

    case BankTransfer = 'bank_transfer';

    case Wallet = 'wallet';

    case Credit = 'credit';

    case None = 'none';



    /** @return list<string> */

    public static function values(): array

    {

        return array_column(self::cases(), 'value');

    }



    /** @return list<string> */

    public static function financialValues(): array

    {

        return array_values(array_filter(

            self::values(),

            fn (string $value) => $value !== self::None->value,

        ));

    }



    public function isFinancial(): bool

    {

        return $this !== self::None;

    }



    public function requiresCustomer(): bool

    {

        return match ($this) {

            self::Wallet, self::Credit => true,

            default => false,

        };

    }



    public function requiresCashRegister(): bool

    {

        return $this === self::Cash;

    }



    public function toPaymentMethod(): ?SalePaymentMethod

    {

        return match ($this) {

            self::Cash => SalePaymentMethod::Cash,

            self::Card => SalePaymentMethod::Card,

            self::MobileMoney => SalePaymentMethod::MobileMoney,

            self::BankTransfer => SalePaymentMethod::BankTransfer,

            self::Wallet => SalePaymentMethod::Wallet,

            default => null,

        };

    }



    public function label(): string

    {

        return config("refunds.methods.{$this->value}.label", $this->value);

    }

}

