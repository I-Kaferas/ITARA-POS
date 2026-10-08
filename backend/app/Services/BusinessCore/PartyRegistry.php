<?php

namespace App\Services\BusinessCore;

use App\Enums\PartyContext;
use App\Enums\PartyKind;
use App\Models\CrmAccount;
use App\Models\Customer;
use App\Models\Employee;
use App\Models\Organization;
use App\Models\Party;
use App\Models\PartyContextLink;
use App\Models\Supplier;
use App\Models\User;
use App\Tenancy\TenantContext;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PartyRegistry
{
    public function __construct(private readonly TenantContext $context) {}

    /** @param  array<string, mixed>  $attributes */
    public function create(array $attributes, PartyKind $kind = PartyKind::Person): Party
    {
        return Party::query()->create([
            'tenant_id' => $this->context->requireId(),
            'kind' => $kind,
            'display_name' => $attributes['display_name'] ?? $attributes['name'] ?? 'Unnamed',
            'legal_name' => $attributes['legal_name'] ?? $attributes['company_name'] ?? null,
            'code' => $attributes['code'] ?? null,
            'email' => $attributes['email'] ?? null,
            'phone' => $attributes['phone'] ?? null,
            'tax_id' => $attributes['tax_id'] ?? null,
            'address' => $attributes['address'] ?? null,
            'notes' => $attributes['notes'] ?? null,
            'metadata' => $attributes['metadata'] ?? null,
            'is_active' => $attributes['is_active'] ?? true,
        ]);
    }

    /**
     * Resolve an existing party by shared identity fields, or create one.
     *
     * @param  array<string, mixed>  $attributes
     */
    public function findOrCreate(array $attributes, PartyKind $kind = PartyKind::Person): Party
    {
        $existing = $this->findByIdentity(
            email: isset($attributes['email']) ? (string) $attributes['email'] : null,
            phone: isset($attributes['phone']) ? (string) $attributes['phone'] : null,
            taxId: isset($attributes['tax_id']) ? (string) $attributes['tax_id'] : null,
            code: isset($attributes['code']) ? (string) $attributes['code'] : null,
        );

        if ($existing) {
            $this->syncIdentity($existing, $attributes);

            return $existing;
        }

        return $this->create($attributes, $kind);
    }

    public function findByIdentity(
        ?string $email = null,
        ?string $phone = null,
        ?string $taxId = null,
        ?string $code = null,
    ): ?Party {
        $tenantId = $this->context->requireId();
        $query = Party::query()->where('tenant_id', $tenantId);

        if ($code) {
            $match = (clone $query)->where('code', $code)->first();
            if ($match) {
                return $match;
            }
        }

        if ($taxId) {
            $match = (clone $query)->where('tax_id', $taxId)->first();
            if ($match) {
                return $match;
            }
        }

        if ($email) {
            $match = (clone $query)->whereRaw('LOWER(email) = ?', [mb_strtolower($email)])->first();
            if ($match) {
                return $match;
            }
        }

        if ($phone) {
            $normalized = preg_replace('/\s+/', '', $phone) ?: $phone;
            $match = (clone $query)
                ->where(function ($q) use ($phone, $normalized) {
                    $q->where('phone', $phone)->orWhere('phone', $normalized);
                })
                ->first();
            if ($match) {
                return $match;
            }
        }

        return null;
    }

    /** @param  array<string, mixed>  $attributes */
    public function syncIdentity(Party $party, array $attributes): Party
    {
        $map = [
            'display_name' => $attributes['display_name'] ?? $attributes['name'] ?? null,
            'legal_name' => $attributes['legal_name'] ?? $attributes['company_name'] ?? null,
            'email' => $attributes['email'] ?? null,
            'phone' => $attributes['phone'] ?? null,
            'tax_id' => $attributes['tax_id'] ?? null,
            'address' => $attributes['address'] ?? null,
            'notes' => $attributes['notes'] ?? null,
        ];

        $dirty = false;
        foreach ($map as $key => $value) {
            if ($value === null || $value === '') {
                continue;
            }
            if ($party->getAttribute($key) === null || $party->getAttribute($key) === '') {
                $party->setAttribute($key, $value);
                $dirty = true;
            }
        }

        if ($dirty) {
            $party->save();
        }

        return $party;
    }

    public function attachContext(Party $party, PartyContext $context, ?string $label = null, array $metadata = []): PartyContextLink
    {
        return PartyContextLink::query()->updateOrCreate(
            [
                'party_id' => $party->id,
                'context' => $context->value,
            ],
            [
                'tenant_id' => $party->tenant_id,
                'label' => $label ?? $context->label(),
                'metadata' => $metadata ?: null,
                'is_active' => true,
            ],
        );
    }

    /**
     * Ensure the party has a Customer role (POS / restaurant / hotel / CRM share this).
     *
     * @param  array<string, mixed>  $attributes
     */
    public function ensureCustomer(Party $party, array $attributes = [], ?PartyContext $context = PartyContext::Pos): Customer
    {
        return DB::transaction(function () use ($party, $attributes, $context) {
            $customer = Customer::query()->where('party_id', $party->id)->first();

            if (! $customer) {
                $customer = Customer::query()->create([
                    'tenant_id' => $party->tenant_id,
                    'party_id' => $party->id,
                    'name' => $attributes['name'] ?? $party->display_name,
                    'company_name' => $attributes['company_name'] ?? $party->legal_name,
                    'tax_id' => $attributes['tax_id'] ?? $party->tax_id,
                    'email' => $attributes['email'] ?? $party->email,
                    'phone' => $attributes['phone'] ?? $party->phone,
                    'code' => $attributes['code'] ?? null,
                    'notes' => $attributes['notes'] ?? $party->notes,
                    'metadata' => $attributes['metadata'] ?? null,
                    'crm_role' => $attributes['crm_role'] ?? 'client',
                    'job_title' => $attributes['job_title'] ?? null,
                    'crm_account_id' => $attributes['crm_account_id'] ?? null,
                    'credit_limit' => $attributes['credit_limit'] ?? null,
                    'payment_terms_days' => $attributes['payment_terms_days'] ?? 0,
                    'is_active' => $attributes['is_active'] ?? $party->is_active,
                ]);
            } else {
                foreach (['name', 'company_name', 'email', 'phone', 'tax_id', 'crm_role', 'job_title', 'crm_account_id'] as $field) {
                    if (array_key_exists($field, $attributes) && $attributes[$field] !== null) {
                        $customer->setAttribute($field, $attributes[$field]);
                    }
                }
                $customer->save();
            }

            if ($context) {
                $this->attachContext($party, $context);
            }

            return $customer->fresh();
        });
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function ensureSupplier(Party $party, array $attributes = []): Supplier
    {
        return DB::transaction(function () use ($party, $attributes) {
            $supplier = Supplier::query()->where('party_id', $party->id)->first();

            if (! $supplier) {
                $code = $attributes['code'] ?? null;
                if (! $code) {
                    $code = 'SUP-'.strtoupper(substr(str_replace('-', '', $party->id), 0, 8));
                }

                $supplier = Supplier::query()->create([
                    'tenant_id' => $party->tenant_id,
                    'party_id' => $party->id,
                    'name' => $attributes['name'] ?? $party->display_name,
                    'legal_name' => $attributes['legal_name'] ?? $party->legal_name,
                    'code' => $code,
                    'tax_id' => $attributes['tax_id'] ?? $party->tax_id,
                    'email' => $attributes['email'] ?? $party->email,
                    'phone' => $attributes['phone'] ?? $party->phone,
                    'address' => $attributes['address'] ?? $party->address,
                    'payment_terms_days' => $attributes['payment_terms_days'] ?? 0,
                    'credit_limit' => $attributes['credit_limit'] ?? 0,
                    'currency_code' => $attributes['currency_code'] ?? null,
                    'notes' => $attributes['notes'] ?? $party->notes,
                    'metadata' => $attributes['metadata'] ?? null,
                    'is_active' => $attributes['is_active'] ?? $party->is_active,
                ]);
            }

            $this->attachContext($party, PartyContext::Supplier);

            return $supplier->fresh();
        });
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function ensureEmployee(Party $party, array $attributes = [], ?User $user = null): Employee
    {
        return DB::transaction(function () use ($party, $attributes, $user) {
            $user ??= isset($attributes['user_id'])
                ? User::query()->find($attributes['user_id'])
                : null;

            $employee = Employee::query()->where('party_id', $party->id)->first();

            if (! $employee) {
                $employee = Employee::query()->create([
                    'tenant_id' => $party->tenant_id,
                    'party_id' => $party->id,
                    'user_id' => $user?->id,
                    'code' => $attributes['code'] ?? null,
                    'job_title' => $attributes['job_title'] ?? null,
                    'department' => $attributes['department'] ?? null,
                    'hired_on' => $attributes['hired_on'] ?? null,
                    'metadata' => $attributes['metadata'] ?? null,
                    'is_active' => $attributes['is_active'] ?? true,
                ]);
            } elseif ($user && ! $employee->user_id) {
                $employee->user_id = $user->id;
                $employee->save();
            }

            if ($user && $user->party_id !== $party->id) {
                $user->party_id = $party->id;
                $user->save();
            }

            $this->attachContext($party, PartyContext::Employee);

            return $employee->fresh(['party', 'user']);
        });
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function ensureCrmContact(Party $party, array $attributes = [], string $role = 'client'): Customer
    {
        $customer = $this->ensureCustomer($party, [
            ...$attributes,
            'crm_role' => $role,
        ], PartyContext::Crm);

        $this->attachContext($party, PartyContext::Crm);

        return $customer;
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function ensureOrganization(Party $party, array $attributes = []): Organization
    {
        if ($party->kind !== PartyKind::Organization) {
            $party->kind = PartyKind::Organization;
            $party->save();
        }

        $org = Organization::query()->where('party_id', $party->id)->first();

        if (! $org) {
            $org = Organization::query()->create([
                'tenant_id' => $party->tenant_id,
                'party_id' => $party->id,
                'name' => $attributes['name'] ?? $party->display_name,
                'trade_name' => $attributes['trade_name'] ?? null,
                'legal_name' => $attributes['legal_name'] ?? $party->legal_name,
                'tax_id' => $attributes['tax_id'] ?? $party->tax_id,
                'phone' => $attributes['phone'] ?? $party->phone,
                'email' => $attributes['email'] ?? $party->email,
                'address' => $attributes['address'] ?? $party->address,
                'currency_code' => $attributes['currency_code'] ?? 'FBU',
                'is_active' => $attributes['is_active'] ?? true,
            ]);
        }

        return $org->fresh();
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function ensureCrmAccount(Party $party, array $attributes = []): CrmAccount
    {
        if ($party->kind !== PartyKind::Organization) {
            $party->kind = PartyKind::Organization;
            $party->save();
        }

        $account = CrmAccount::query()->where('party_id', $party->id)->first();

        if (! $account) {
            $account = CrmAccount::query()->create([
                'tenant_id' => $party->tenant_id,
                'party_id' => $party->id,
                'name' => $attributes['name'] ?? $party->display_name,
                'legal_name' => $attributes['legal_name'] ?? $party->legal_name,
                'email' => $attributes['email'] ?? $party->email,
                'phone' => $attributes['phone'] ?? $party->phone,
                'tax_id' => $attributes['tax_id'] ?? $party->tax_id,
                'website' => $attributes['website'] ?? null,
                'industry' => $attributes['industry'] ?? null,
                'address' => $attributes['address'] ?? $party->address,
            ]);
        }

        return $account->fresh();
    }

    public function partyForCustomer(Customer $customer): Party
    {
        if ($customer->party_id) {
            $party = Party::query()->find($customer->party_id);
            if ($party) {
                return $party;
            }
        }

        $party = $this->findOrCreate([
            'name' => $customer->name,
            'company_name' => $customer->company_name,
            'email' => $customer->email,
            'phone' => $customer->phone,
            'tax_id' => $customer->tax_id,
            'notes' => $customer->notes,
            'code' => $customer->code,
            'is_active' => $customer->is_active,
        ]);

        $customer->party_id = $party->id;
        $customer->save();

        return $party;
    }

    public function partyForSupplier(Supplier $supplier): Party
    {
        if ($supplier->party_id) {
            $party = Party::query()->find($supplier->party_id);
            if ($party) {
                return $party;
            }
        }

        $party = $this->findOrCreate([
            'name' => $supplier->name,
            'legal_name' => $supplier->legal_name,
            'email' => $supplier->email,
            'phone' => $supplier->phone,
            'tax_id' => $supplier->tax_id,
            'address' => $supplier->address,
            'notes' => $supplier->notes,
            'code' => $supplier->code,
            'is_active' => $supplier->is_active,
        ], PartyKind::Organization);

        $supplier->party_id = $party->id;
        $supplier->save();

        return $party;
    }

    public function assertSameParty(Customer $customer, Supplier $supplier): void
    {
        $customerParty = $this->partyForCustomer($customer);
        $supplierParty = $this->partyForSupplier($supplier);

        if ($customerParty->id !== $supplierParty->id) {
            throw ValidationException::withMessages([
                'party_id' => ['Customer and supplier do not share the same party identity.'],
            ]);
        }
    }

    /** @return array<string, mixed> */
    public function dossier(Party $party): array
    {
        $party->load(['customer.account', 'supplier', 'employee.user', 'user', 'organization', 'crmAccount', 'contexts']);

        return [
            'party' => $party,
            'roles' => $party->roleNames(),
            'contexts' => $party->contexts->map(fn (PartyContextLink $link) => [
                'context' => $link->context->value,
                'label' => $link->label ?? $link->context->label(),
                'is_active' => $link->is_active,
            ])->values(),
            'customer' => $party->customer,
            'supplier' => $party->supplier,
            'employee' => $party->employee,
            'user' => $party->user,
            'organization' => $party->organization,
            'crm_account' => $party->crmAccount,
        ];
    }
}
