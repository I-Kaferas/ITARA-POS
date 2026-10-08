<?php

namespace App\Models\Concerns;

use App\Enums\PartyKind;
use App\Models\Party;
use App\Services\BusinessCore\PartyRegistry;
use App\Tenancy\TenantContext;

trait SyncsWithParty
{
    public static function bootSyncsWithParty(): void
    {
        static::creating(function ($model): void {
            if ($model->getAttribute('party_id')) {
                return;
            }

            if (! app(TenantContext::class)->isBound()) {
                return;
            }

            /** @var PartyRegistry $registry */
            $registry = app(PartyRegistry::class);

            $party = $registry->findOrCreate(
                $model->partyIdentityAttributes(),
                $model->partyKind(),
            );

            $model->setAttribute('party_id', $party->id);
        });
    }

    /** @return array<string, mixed> */
    protected function partyIdentityAttributes(): array
    {
        return [
            'name' => $this->getAttribute('name') ?? $this->getAttribute('display_name'),
            'legal_name' => $this->getAttribute('legal_name'),
            'company_name' => $this->getAttribute('company_name'),
            'email' => $this->getAttribute('email'),
            'phone' => $this->getAttribute('phone'),
            'tax_id' => $this->getAttribute('tax_id'),
            'address' => $this->getAttribute('address'),
            'notes' => $this->getAttribute('notes'),
            'code' => $this->getAttribute('code'),
            'is_active' => $this->getAttribute('is_active') ?? true,
        ];
    }

    protected function partyKind(): PartyKind
    {
        return PartyKind::Person;
    }

    public function ensureParty(): Party
    {
        if ($this->getAttribute('party_id')) {
            $party = Party::query()->find($this->getAttribute('party_id'));
            if ($party) {
                return $party;
            }
        }

        return app(PartyRegistry::class)->findOrCreate(
            $this->partyIdentityAttributes(),
            $this->partyKind(),
        );
    }
}
