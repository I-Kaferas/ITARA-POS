<?php

/**
 * Locale tax packages applied as tenant data at provisioning time.
 * The TaxEngine never branches on country codes — only on these definitions
 * once copied into the tenant's taxes / classes / groups / rules tables.
 *
 * @var array<string, array<string, mixed>>
 */
return [

    /*
    |--------------------------------------------------------------------------
    | Default profile key used when a tenant has no country match
    |--------------------------------------------------------------------------
    */
    'default' => 'BI',

    /*
    |--------------------------------------------------------------------------
    | Profiles keyed by ISO 3166-1 alpha-2 (or custom tax_regime codes)
    |--------------------------------------------------------------------------
    */
    'profiles' => [

        'BI' => [
            'name' => 'Burundi (OBR)',
            'country' => 'BI',
            'currency' => 'FBU',
            'description' => 'Pack fiscal de base pour le Burundi. Les taux restent modifiables par tenant.',
            'taxes' => [
                [
                    'code' => 'TVA18',
                    'name' => 'TVA 18%',
                    'kind' => 'vat',
                    'type' => 'percentage',
                    'rate' => 18,
                    'priority' => 10,
                    'country' => 'BI',
                    'is_inclusive' => false,
                    'is_compound' => false,
                    'description' => 'Taux normal de TVA (OBR).',
                ],
                [
                    'code' => 'TVA0',
                    'name' => 'TVA taux zéro',
                    'kind' => 'zero_rated',
                    'type' => 'percentage',
                    'rate' => 0,
                    'priority' => 10,
                    'country' => 'BI',
                    'is_inclusive' => false,
                    'is_compound' => false,
                    'description' => 'Opérations taxables à 0 % (exports, produits listés).',
                ],
                [
                    'code' => 'EXO',
                    'name' => 'Exonéré',
                    'kind' => 'exempt',
                    'type' => 'percentage',
                    'rate' => 0,
                    'priority' => 10,
                    'country' => 'BI',
                    'is_inclusive' => false,
                    'is_compound' => false,
                    'description' => 'Opérations hors champ ou exonérées de TVA.',
                ],
                [
                    'code' => 'TC',
                    'name' => 'Taxe communale',
                    'kind' => 'tax',
                    'type' => 'percentage',
                    'rate' => 0,
                    'priority' => 20,
                    'country' => 'BI',
                    'is_inclusive' => false,
                    'is_compound' => false,
                    'description' => 'Taxe locale configurable (taux à définir par l’établissement).',
                ],
                [
                    'code' => 'RAS',
                    'name' => 'Retenue à la source',
                    'kind' => 'withholding',
                    'type' => 'percentage',
                    'rate' => 0,
                    'priority' => 30,
                    'country' => 'BI',
                    'is_inclusive' => false,
                    'is_compound' => false,
                    'description' => 'Retenue à la source configurable (achats / prestations).',
                ],
            ],
            'classes' => [
                [
                    'code' => 'STANDARD',
                    'name' => 'Standard',
                    'description' => 'Biens et services au taux normal.',
                ],
                [
                    'code' => 'ZERO',
                    'name' => 'Taux zéro',
                    'description' => 'Biens et services zero-rated.',
                ],
                [
                    'code' => 'EXEMPT',
                    'name' => 'Exonéré',
                    'description' => 'Biens et services exonérés.',
                ],
            ],
            'groups' => [
                [
                    'code' => 'SALE_STD',
                    'name' => 'Vente standard',
                    'description' => 'TVA normale sur ventes.',
                    'tax_codes' => ['TVA18'],
                ],
            ],
            'rules' => [
                [
                    'name' => 'Standard → TVA 18%',
                    'class_code' => 'STANDARD',
                    'tax_code' => 'TVA18',
                    'country' => 'BI',
                    'priority' => 10,
                ],
                [
                    'name' => 'Zero-rated → TVA 0%',
                    'class_code' => 'ZERO',
                    'tax_code' => 'TVA0',
                    'country' => 'BI',
                    'priority' => 10,
                ],
                [
                    'name' => 'Exempt → Exonéré',
                    'class_code' => 'EXEMPT',
                    'tax_code' => 'EXO',
                    'country' => 'BI',
                    'priority' => 10,
                ],
            ],
        ],

    ],
];
