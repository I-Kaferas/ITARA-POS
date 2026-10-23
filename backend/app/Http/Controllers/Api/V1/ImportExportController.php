<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Catalog;
use App\Models\Product;
use App\Services\Catalog\ProductSpreadsheet;
use App\Support\SimpleXlsx;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use InvalidArgumentException;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ImportExportController extends Controller
{
    public function __construct(private ProductSpreadsheet $sheet) {}

    public function exportProducts(Request $request): Response
    {
        $catalogId = $request->string('catalog_id')->toString() ?: null;

        $query = Product::query()
            ->with(['barcodes', 'category:id,name', 'brand:id,name', 'unitModel:id,name', 'tax:id,name'])
            ->orderBy('sku');
        if ($catalogId) {
            $query->where('catalog_id', $catalogId);
        }

        if ($request->string('format')->toString() === 'xlsx') {
            $rows = [$this->sheet->headers()];
            foreach ($query->lazy(200) as $product) {
                $rows[] = $this->sheet->exportRow($product);
            }

            return $this->xlsxResponse($rows, 'products-export.xlsx');
        }

        return response()->streamDownload(function () use ($query) {
            $out = fopen('php://output', 'w');
            fwrite($out, "\xEF\xBB\xBF");
            fputcsv($out, $this->sheet->headers(), ';');

            foreach ($query->lazy(200) as $product) {
                fputcsv($out, $this->sheet->exportRow($product), ';');
            }

            fclose($out);
        }, 'products-export.csv', [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }

    public function importProducts(Request $request): JsonResponse
    {
        $data = $request->validate([
            'catalog_id' => ['required', 'uuid', 'exists:catalogs,id'],
            'file' => ['required', 'file', 'max:10240'],
            'update_existing' => ['boolean'],
        ]);

        $extension = strtolower((string) $request->file('file')?->getClientOriginalExtension());
        if (! in_array($extension, ['csv', 'txt', 'xlsx'], true)) {
            return response()->json(['message' => 'Utilisez un fichier Excel (.xlsx) ou CSV.'], 422);
        }

        $catalog = Catalog::query()->findOrFail($data['catalog_id']);
        $path = $request->file('file')->getRealPath();
        if ($path === false) {
            return response()->json(['message' => 'Fichier illisible.'], 422);
        }

        try {
            $table = $extension === 'xlsx' ? SimpleXlsx::readRows($path) : $this->readCsv($path);
        } catch (\Throwable $exception) {
            return response()->json(['message' => $exception->getMessage()], 422);
        }

        $header = array_shift($table) ?: [];
        if ($header === []) {
            return response()->json(['message' => 'Fichier vide.'], 422);
        }

        try {
            $result = $this->sheet->import($catalog, $header, $table, $request->boolean('update_existing', true));
        } catch (InvalidArgumentException $exception) {
            return response()->json(['message' => $exception->getMessage()], 422);
        }

        return response()->json(['data' => $result]);
    }

    public function productTemplate(): Response
    {
        return $this->xlsxResponse($this->sheet->templateRows(), 'products-import-template.xlsx');
    }

    /** @param  list<list<string|int|float|null>>  $rows */
    private function xlsxResponse(array $rows, string $filename): Response
    {
        return response(SimpleXlsx::binary($rows), 200, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'Content-Disposition' => 'attachment; filename="'.$filename.'"',
        ]);
    }

    /**
     * Excel saves CSV with ";" in French locales and often in Windows-1252.
     *
     * @return list<list<string|null>>
     */
    private function readCsv(string $path): array
    {
        $content = (string) file_get_contents($path);
        $content = preg_replace('/^\xEF\xBB\xBF/', '', $content) ?? $content;
        if (! mb_check_encoding($content, 'UTF-8')) {
            $content = mb_convert_encoding($content, 'UTF-8', 'Windows-1252');
        }

        $firstLine = strtok($content, "\r\n") ?: '';
        $delimiter = substr_count($firstLine, ';') > substr_count($firstLine, ',') ? ';' : ',';

        $handle = fopen('php://temp', 'r+');
        fwrite($handle, $content);
        rewind($handle);

        $rows = [];
        while (($row = fgetcsv($handle, null, $delimiter)) !== false) {
            $rows[] = $row === [null] ? [] : $row;
        }
        fclose($handle);

        return $rows;
    }
}
