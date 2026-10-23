<?php

namespace App\Services\Catalog;

use App\Models\Brand;
use App\Models\Catalog;
use App\Models\Category;
use App\Models\Product;
use App\Models\Tax;
use App\Models\Tenant;
use App\Models\Unit;
use App\Services\Platform\SaasLimitGuard;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use InvalidArgumentException;

/**
 * Product import/export sheet: human headers and values (names, Oui/Non,
 * prices in currency units) mapped onto the product model, which stores
 * prices in cents and taxonomy as ids. Imports go through the catalog
 * service so barcodes, audit and type rules match the product form.
 */
class ProductSpreadsheet
{
    /** canonical key => [French header, accepted header aliases (normalised)] */
    private const COLUMNS = [
        'sku' => ['SKU', ['sku', 'reference', 'ref', 'code article']],
        'name' => ['Nom', ['name', 'nom', 'designation', 'produit', 'nom du produit']],
        'description' => ['Description', ['description']],
        'barcode' => ['Code-barres', ['barcode', 'code barres', 'code barre', 'ean']],
        'product_type' => ['Type', ['product type', 'type', 'type de produit']],
        'base_price' => ['Prix de vente', ['base price', 'prix de vente', 'prix', 'price']],
        'cost_price' => ["Prix d'achat", ['cost price', 'prix d achat', 'cout', 'prix de revient', 'cost']],
        'category' => ['Catégorie', ['category id', 'category', 'categorie']],
        'brand' => ['Marque', ['brand id', 'brand', 'marque']],
        'unit' => ['Unité', ['unit id', 'unit', 'unite']],
        'tax' => ['Taxe', ['tax id', 'tax', 'taxe', 'tva']],
        'is_active' => ['Actif', ['is active', 'actif', 'active']],
        'track_batch' => ['Suivi par lot', ['track batch', 'suivi par lot']],
        'is_serialized' => ['Numéro de série', ['is serialized', 'numero de serie', 'serialise']],
        'track_expiration' => ['Suivi péremption', ['track expiration', 'suivi peremption', 'peremption']],
        'expiration_days' => ['Jours avant péremption', ['expiration days', 'jours avant peremption']],
        'low_stock_threshold' => ['Seuil stock bas', ['low stock threshold', 'seuil stock bas', 'seuil']],
        'accompaniment_enabled' => ['Accompagnements', ['accompaniment enabled', 'accompagnements', 'accompagnement']],
    ];

    /** Old exports used these raw headers and wrote prices in cents. */
    private const LEGACY_CENT_HEADERS = ['base price', 'cost price'];

    private const TYPE_SYNONYMS = [
        'standard' => 'simple',
        'produit' => 'simple',
        'variante' => 'variant',
        'variantes' => 'variant',
        'pack' => 'bundle',
        'pesable' => 'weighable',
        'serialise' => 'serialized',
        'lot' => 'batch',
    ];

    private const BOOLEANS = [
        '1' => true, 'oui' => true, 'o' => true, 'yes' => true, 'y' => true, 'true' => true, 'vrai' => true, 'x' => true,
        '0' => false, 'non' => false, 'n' => false, 'no' => false, 'false' => false, 'faux' => false,
    ];

    /** @var array<string, array{ids: array<string, true>, keys: array<string, string>}> */
    private array $lookups = [];

    private ?string $catalogId = null;

    public function __construct(private ProductCatalogService $catalog) {}

    /** @return list<string> */
    public function headers(): array
    {
        return array_values(array_map(fn (array $column) => $column[0], self::COLUMNS));
    }

    /** @return list<string|int|null> */
    public function exportRow(Product $product): array
    {
        return [
            $product->sku,
            $product->name,
            $product->description,
            $product->primaryBarcode()?->barcode ?? $product->barcode,
            $this->typeLabel((string) $product->product_type),
            self::money($product->base_price),
            self::money($product->cost_price),
            $product->category?->name,
            $product->brand?->name,
            $product->unitModel?->name,
            $product->tax?->name,
            self::yesNo($product->is_active),
            self::yesNo($product->track_batch),
            self::yesNo($product->is_serialized),
            self::yesNo($product->track_expiration),
            $product->expiration_days,
            $product->low_stock_threshold,
            self::yesNo($product->accompaniment_enabled),
        ];
    }

    /** @return list<list<string|int|null>> */
    public function templateRows(): array
    {
        return [
            $this->headers(),
            ['DEMO-001', 'Produit exemple', 'Description courte', '', $this->typeLabel('simple'), 1500, 1000, '', '', '', '', 'Oui', 'Non', 'Non', 'Non', null, 5, 'Non'],
            ['DEMO-002', 'Service exemple', '', '', $this->typeLabel('service'), 5000, 0, '', '', '', '', 'Oui', 'Non', 'Non', 'Non', null, null, 'Non'],
        ];
    }

    /**
     * @param  list<mixed>  $header
     * @param  list<list<mixed>>  $rows
     * @return array{created: int, updated: int, skipped: int, errors: list<string>}
     */
    public function import(Catalog $catalog, array $header, array $rows, bool $updateExisting): array
    {
        [$columns, $legacyCents] = $this->mapHeader($header);
        if (! in_array('sku', $columns, true)) {
            throw new InvalidArgumentException('Colonne « SKU » introuvable. Utilisez le modèle ou un export du catalogue.');
        }

        $this->lookups = [];
        $this->catalogId = $catalog->id;
        $created = 0;
        $updated = 0;
        $skipped = 0;
        $errors = [];
        $tenant = Tenant::query()->find($catalog->tenant_id);

        foreach ($rows as $index => $row) {
            $line = $index + 2;
            $values = [];
            foreach ($columns as $i => $key) {
                if ($key !== null) {
                    $values[$key] = trim((string) ($row[$i] ?? ''));
                }
            }
            if (implode('', $values) === '') {
                continue;
            }

            try {
                $sku = $values['sku'] ?? '';
                if ($sku === '') {
                    throw new InvalidArgumentException('le SKU est obligatoire.');
                }
                if (mb_strlen($sku) > 100) {
                    throw new InvalidArgumentException('le SKU dépasse 100 caractères.');
                }

                $existing = Product::query()
                    ->where('catalog_id', $catalog->id)
                    ->where('sku', $sku)
                    ->with('barcodes')
                    ->first();

                if ($existing && ! $updateExisting) {
                    $skipped++;

                    continue;
                }

                $data = $this->rowData($values, $legacyCents, $existing);

                if ($existing) {
                    if ($data !== []) {
                        $this->catalog->update($existing, $data);
                    }
                    $updated++;

                    continue;
                }

                if (($data['name'] ?? '') === '') {
                    throw new InvalidArgumentException('le nom est obligatoire pour un nouveau produit.');
                }
                if (! array_key_exists('base_price', $data)) {
                    throw new InvalidArgumentException('le prix de vente est obligatoire pour un nouveau produit.');
                }
                if ($tenant) {
                    try {
                        app(SaasLimitGuard::class)->assertWithin($tenant, 'products');
                    } catch (ValidationException) {
                        $skipped++;
                        $errors[] = "Ligne {$line} : limite de produits de l'abonnement atteinte.";
                        break;
                    }
                }

                $this->catalog->create($catalog, ['sku' => $sku, ...$data]);
                $created++;
            } catch (InvalidArgumentException $e) {
                $skipped++;
                $errors[] = "Ligne {$line} : ".$e->getMessage();
            } catch (ValidationException $e) {
                $skipped++;
                $errors[] = "Ligne {$line} : ".(collect($e->errors())->flatten()->first() ?? $e->getMessage());
            } catch (\Throwable $e) {
                report($e);
                $skipped++;
                $errors[] = "Ligne {$line} : enregistrement impossible.";
            }
        }

        return [
            'created' => $created,
            'updated' => $updated,
            'skipped' => $skipped,
            'errors' => array_slice($errors, 0, 50),
        ];
    }

    /**
     * Only filled cells are applied: an empty cell keeps the current value.
     *
     * @param  array<string, string>  $values
     * @param  array<string, bool>  $legacyCents
     * @return array<string, mixed>
     */
    private function rowData(array $values, array $legacyCents, ?Product $existing): array
    {
        $data = [];
        $filled = fn (string $key): bool => ($values[$key] ?? '') !== '';

        if ($filled('name')) {
            if (mb_strlen($values['name']) > 255) {
                throw new InvalidArgumentException('le nom dépasse 255 caractères.');
            }
            $data['name'] = $values['name'];
        }
        if ($filled('description')) {
            $data['description'] = $values['description'];
        }

        if ($filled('product_type')) {
            $type = $this->parseType($values['product_type']);
            $current = $existing?->product_type;
            $structural = ['variant', 'bundle'];
            if ($existing === null && in_array($type, $structural, true)) {
                throw new InvalidArgumentException('les produits à variantes et les packs se créent depuis le formulaire produit.');
            }
            if ($existing !== null && $type !== $current && (in_array($type, $structural, true) || in_array($current, $structural, true))) {
                throw new InvalidArgumentException('le type « variantes » ou « pack » ne peut pas être changé par import.');
            }
            $data['product_type'] = $type;
        }

        foreach (['base_price' => 'prix de vente', 'cost_price' => "prix d'achat"] as $key => $label) {
            if ($filled($key)) {
                $data[$key] = self::parseMoney($values[$key], $legacyCents[$key] ?? false, $label);
            }
        }

        foreach (['category' => 'category_id', 'brand' => 'brand_id', 'unit' => 'unit_id', 'tax' => 'tax_id'] as $key => $field) {
            if ($filled($key)) {
                $data[$field] = $this->resolveReference($key, $values[$key]);
            }
        }

        foreach (['is_active', 'track_batch', 'is_serialized', 'track_expiration', 'accompaniment_enabled'] as $key) {
            if ($filled($key)) {
                $data[$key] = self::parseBool($values[$key], self::COLUMNS[$key][0]);
            }
        }

        if ($filled('expiration_days')) {
            $data['expiration_days'] = self::parseInt($values['expiration_days'], 1, self::COLUMNS['expiration_days'][0]);
        }
        if ($filled('low_stock_threshold')) {
            $data['low_stock_threshold'] = self::parseInt($values['low_stock_threshold'], 0, self::COLUMNS['low_stock_threshold'][0]);
        }

        if ($filled('barcode')) {
            $barcode = $values['barcode'];
            if (mb_strlen($barcode) > 100) {
                throw new InvalidArgumentException('le code-barres dépasse 100 caractères.');
            }
            $this->applyBarcode($data, $barcode, $existing);
        }

        return $data;
    }

    /**
     * The barcode service replaces the whole list it receives, so an update
     * resends the product's other barcodes to keep them.
     *
     * @param  array<string, mixed>  $data
     */
    private function applyBarcode(array &$data, string $barcode, ?Product $existing): void
    {
        if ($existing === null) {
            $data['barcode'] = $barcode;

            return;
        }

        $current = $existing->primaryBarcode()?->barcode ?? $existing->barcode;
        if ($current === $barcode) {
            return;
        }

        $data['barcode'] = $barcode;
        $data['barcodes'] = [
            ['barcode' => $barcode, 'is_primary' => true],
            ...$existing->barcodes
                ->reject(fn ($row) => $row->barcode === $barcode)
                ->map(fn ($row) => ['barcode' => $row->barcode, 'type' => $row->type, 'is_primary' => false])
                ->values()
                ->all(),
        ];
    }

    /**
     * @param  list<mixed>  $header
     * @return array{0: list<string|null>, 1: array<string, bool>}
     */
    private function mapHeader(array $header): array
    {
        $aliases = [];
        foreach (self::COLUMNS as $key => [$label, $names]) {
            $aliases[self::normalize($label)] = $key;
            foreach ($names as $name) {
                $aliases[$name] = $aliases[$name] ?? $key;
            }
        }

        $columns = [];
        $legacyCents = [];
        $seen = [];
        foreach ($header as $cell) {
            $normalized = self::normalize((string) $cell);
            $key = $aliases[$normalized] ?? null;
            if ($key !== null && isset($seen[$key])) {
                $key = null;
            }
            if ($key !== null) {
                $seen[$key] = true;
                if (in_array($normalized, self::LEGACY_CENT_HEADERS, true)) {
                    $legacyCents[$key] = true;
                }
            }
            $columns[] = $key;
        }

        return [$columns, $legacyCents];
    }

    private function parseType(string $raw): string
    {
        $normalized = self::normalize($raw);
        foreach (config('product_types.types', []) as $code => $label) {
            if ($normalized === self::normalize((string) $code) || $normalized === self::normalize((string) $label)) {
                return (string) $code;
            }
        }
        if (isset(self::TYPE_SYNONYMS[$normalized])) {
            return self::TYPE_SYNONYMS[$normalized];
        }

        $labels = implode(', ', array_values(config('product_types.types', [])));

        throw new InvalidArgumentException("type « {$raw} » inconnu (valeurs possibles : {$labels}).");
    }

    private function typeLabel(string $code): string
    {
        return (string) (config("product_types.types.{$code}") ?? $code);
    }

    private function resolveReference(string $kind, string $raw): string
    {
        $lookup = $this->lookups[$kind] ??= $this->buildLookup($kind, $this->catalogId);

        if (Str::isUuid($raw) && isset($lookup['ids'][strtolower($raw)])) {
            return strtolower($raw);
        }

        $id = $lookup['keys'][self::normalize($raw)] ?? null;
        if ($id !== null) {
            return $id;
        }

        $label = mb_strtolower(self::COLUMNS[$kind][0]);

        throw new InvalidArgumentException("{$label} « {$raw} » introuvable. Créez-la d'abord ou corrigez le nom.");
    }

    /** @return array{ids: array<string, true>, keys: array<string, string>} */
    private function buildLookup(string $kind, ?string $catalogId): array
    {
        /** @var Collection<int, object> $rows */
        $rows = match ($kind) {
            'category' => Category::query()
                ->when($catalogId, fn ($q) => $q->orderByRaw('CASE WHEN catalog_id = ? THEN 0 ELSE 1 END', [$catalogId]))
                ->orderBy('name')
                ->get(['id', 'name']),
            'brand' => Brand::query()->orderBy('name')->get(['id', 'name']),
            'unit' => Unit::query()->orderBy('name')->get(['id', 'name', 'code', 'symbol']),
            'tax' => Tax::query()->orderBy('name')->get(['id', 'name', 'code']),
        };

        $ids = [];
        $keys = [];
        foreach ($rows as $row) {
            $ids[strtolower((string) $row->id)] = true;
            foreach (['name', 'code', 'symbol'] as $attribute) {
                $value = $row->{$attribute} ?? null;
                if ($value !== null && $value !== '') {
                    $keys[self::normalize((string) $value)] ??= (string) $row->id;
                }
            }
        }

        return ['ids' => $ids, 'keys' => $keys];
    }

    /** Prices are stored in cents; the sheet shows currency units. */
    public static function money(?int $cents): int|float
    {
        $cents = (int) $cents;

        return $cents % 100 === 0 ? intdiv($cents, 100) : round($cents / 100, 2);
    }

    public static function parseMoney(string $raw, bool $alreadyCents = false, string $label = 'prix'): int
    {
        $value = preg_replace('/[\s\x{00A0}\x{202F}]+/u', '', $raw) ?? '';
        $value = preg_replace('/[^\d,.\-]/', '', $value) ?? '';

        if (str_contains($value, ',') && str_contains($value, '.')) {
            $decimal = strrpos($value, ',') > strrpos($value, '.') ? ',' : '.';
            $value = str_replace($decimal === ',' ? '.' : ',', '', $value);
            $value = str_replace(',', '.', $value);
        } elseif (str_contains($value, ',')) {
            $value = preg_match('/^\d{1,3}(,\d{3})+$/', $value) ? str_replace(',', '', $value) : str_replace(',', '.', $value);
        } elseif (preg_match('/^\d{1,3}(\.\d{3}){2,}$/', $value)) {
            $value = str_replace('.', '', $value);
        }

        if ($value === '' || ! is_numeric($value) || (float) $value < 0) {
            throw new InvalidArgumentException("{$label} « {$raw} » invalide.");
        }

        return $alreadyCents ? (int) round((float) $value) : (int) round((float) $value * 100);
    }

    private static function parseInt(string $raw, int $min, string $label): int
    {
        $value = preg_replace('/[\s\x{00A0}\x{202F}]+/u', '', $raw) ?? '';
        if (! is_numeric($value) || (float) $value < $min || floor((float) $value) != (float) $value) {
            throw new InvalidArgumentException("« {$label} » doit être un nombre entier ≥ {$min} (reçu « {$raw} »).");
        }

        return (int) $value;
    }

    private static function parseBool(string $raw, string $label): bool
    {
        $normalized = self::normalize($raw);
        if (! array_key_exists($normalized, self::BOOLEANS)) {
            throw new InvalidArgumentException("« {$label} » attend Oui ou Non (reçu « {$raw} »).");
        }

        return self::BOOLEANS[$normalized];
    }

    private static function yesNo(mixed $value): string
    {
        return $value ? 'Oui' : 'Non';
    }

    public static function normalize(string $value): string
    {
        $value = mb_strtolower(trim($value));
        $value = strtr($value, [
            'à' => 'a', 'â' => 'a', 'ä' => 'a', 'á' => 'a', 'é' => 'e', 'è' => 'e', 'ê' => 'e', 'ë' => 'e',
            'î' => 'i', 'ï' => 'i', 'í' => 'i', 'ô' => 'o', 'ö' => 'o', 'ó' => 'o', 'ù' => 'u', 'û' => 'u',
            'ü' => 'u', 'ú' => 'u', 'ç' => 'c', 'ñ' => 'n', '’' => "'",
        ]);
        $value = preg_replace('/[^a-z0-9]+/', ' ', $value) ?? '';

        return trim($value);
    }
}
