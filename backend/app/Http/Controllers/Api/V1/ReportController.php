<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Sale;
use App\Models\StockBalance;
use App\Services\Reports\ReportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReportController extends Controller
{
    public function __construct(
        private readonly ReportService $reports,
    ) {}

    public function sales(Request $request): JsonResponse
    {
        [$from, $to] = $this->dateRange($request);

        return response()->json([
            'data' => $this->reports->salesSummary(
                $request->string('store_id')->toString() ?: null,
                $from,
                $to,
            ),
            'meta' => [
                'by_store' => $this->reports->salesByStore($from, $to),
                'from' => $from?->toDateString(),
                'to' => $to?->toDateString(),
            ],
        ]);
    }

    public function inventory(Request $request): JsonResponse
    {
        [$from, $to] = $this->dateRange($request);

        return response()->json([
            'data' => $this->reports->inventorySummary(
                $request->string('warehouse_id')->toString() ?: null,
                $from,
                $to,
            ),
        ]);
    }

    public function financial(Request $request): JsonResponse
    {
        [$from, $to] = $this->dateRange($request);

        return response()->json([
            'data' => $this->reports->financialSummary($from, $to),
            'meta' => [
                'from' => $from?->toDateString(),
                'to' => $to?->toDateString(),
            ],
        ]);
    }

    public function exportSales(Request $request): StreamedResponse
    {
        [$from, $to] = $this->dateRange($request);
        $storeId = $request->string('store_id')->toString() ?: null;

        $query = Sale::query()
            ->with(['store:id,name,code', 'customer:id,name'])
            ->where('status', 'completed')
            ->orderByDesc('completed_at');

        if ($storeId) {
            $query->where('store_id', $storeId);
        }
        if ($from) {
            $query->where('completed_at', '>=', $from->copy()->startOfDay());
        }
        if ($to) {
            $query->where('completed_at', '<=', $to->copy()->endOfDay());
        }

        return $this->csvDownload('sales-export.csv', [
            'reference', 'store', 'customer', 'status', 'payment_status', 'subtotal', 'tax', 'discount', 'total', 'paid', 'completed_at',
        ], function () use ($query) {
            foreach ($query->cursor() as $sale) {
                yield [
                    $sale->reference,
                    $sale->store?->name,
                    $sale->customer?->name,
                    $sale->status?->value ?? $sale->status,
                    $sale->payment_status?->value ?? $sale->payment_status,
                    $sale->subtotal,
                    $sale->tax_total,
                    $sale->discount_total,
                    $sale->total,
                    $sale->paid_amount,
                    $sale->completed_at?->toIso8601String(),
                ];
            }
        });
    }

    public function exportInventory(Request $request): StreamedResponse
    {
        $warehouseId = $request->string('warehouse_id')->toString() ?: null;

        $query = StockBalance::query()
            ->with(['product:id,sku,name,cost_price', 'warehouse:id,name,code'])
            ->orderBy('warehouse_id');

        if ($warehouseId) {
            $query->where('warehouse_id', $warehouseId);
        }

        return $this->csvDownload('inventory-export.csv', [
            'warehouse', 'sku', 'product', 'qty_on_hand', 'qty_available', 'unit_cost', 'value',
        ], function () use ($query) {
            foreach ($query->cursor() as $balance) {
                $cost = (int) ($balance->product?->cost_price ?? 0);
                yield [
                    $balance->warehouse?->name,
                    $balance->product?->sku,
                    $balance->product?->name,
                    $balance->quantity_on_hand,
                    $balance->quantity_available,
                    $cost,
                    $cost * (int) $balance->quantity_on_hand,
                ];
            }
        });
    }

    /**
     * @return array{0: ?Carbon, 1: ?Carbon}
     */
    private function dateRange(Request $request): array
    {
        $from = $request->filled('from') ? Carbon::parse($request->string('from')) : null;
        $to = $request->filled('to') ? Carbon::parse($request->string('to')) : null;

        return [$from, $to];
    }

    /**
     * @param  list<string>  $headers
     * @param  callable(): \Generator  $rows
     */
    private function csvDownload(string $filename, array $headers, callable $rows): StreamedResponse
    {
        return response()->streamDownload(function () use ($headers, $rows) {
            $out = fopen('php://output', 'w');
            fputcsv($out, $headers);
            foreach ($rows() as $row) {
                fputcsv($out, $row);
            }
            fclose($out);
        }, $filename, [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }
}
