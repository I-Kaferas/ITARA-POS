<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\PurchaseOrder;
use App\Models\Sale;
use App\Models\StockBalance;
use App\Services\Reports\ReportService;
use App\Services\Reports\StoreStockReportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReportController extends Controller
{
    public function __construct(
        private readonly ReportService $reports,
        private readonly StoreStockReportService $storeStock,
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

    public function storeStock(Request $request): JsonResponse
    {
        [$from, $to] = $this->dateRange($request);

        return response()->json([
            'data' => $this->storeStock->summarize(
                $request->string('store_id')->toString() ?: null,
                $from,
                $to,
                max(1, (int) $request->integer('idle_days', 30)),
            ),
            'meta' => [
                'from' => $from?->toDateString(),
                'to' => $to?->toDateString(),
            ],
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

    public function revenue(Request $request): JsonResponse
    {
        [$from, $to] = $this->dateRange($request);

        return response()->json([
            'data' => $this->reports->revenueSummary(
                $request->string('store_id')->toString() ?: null,
                $from,
                $to,
            ),
            'meta' => [
                'from' => $from?->toDateTimeString(),
                'to' => $to?->toDateTimeString(),
            ],
        ]);
    }

    public function condensed(Request $request): JsonResponse
    {
        [$from, $to] = $this->dateRange($request);

        return response()->json([
            'data' => $this->reports->condensedSummary(
                $request->string('store_id')->toString() ?: null,
                $from,
                $to,
            ),
            'meta' => [
                'from' => $from?->toDateString(),
                'to' => $to?->toDateString(),
            ],
        ]);
    }

    public function daily(Request $request): JsonResponse
    {
        $monthInput = $request->string('month')->toString()
            ?: ($request->string('from')->toString() ?: now()->format('Y-m'));
        $month = Carbon::parse(strlen($monthInput) === 7 ? $monthInput.'-01' : $monthInput)->startOfMonth();

        return response()->json([
            'data' => $this->reports->dailyCalendar(
                $request->string('store_id')->toString() ?: null,
                $month,
            ),
            'meta' => [
                'month' => $month->format('Y-m'),
            ],
        ]);
    }

    public function dailyDetail(Request $request): JsonResponse
    {
        $date = Carbon::parse($request->string('date')->toString() ?: now()->toDateString())->startOfDay();

        return response()->json([
            'data' => $this->reports->dailyDetail(
                $request->string('store_id')->toString() ?: null,
                $date,
            ),
            'meta' => [
                'date' => $date->toDateString(),
            ],
        ]);
    }

    public function purchases(Request $request): JsonResponse
    {
        [$from, $to] = $this->dateRange($request);

        return response()->json([
            'data' => $this->reports->purchasesSummary($from, $to),
            'meta' => [
                'from' => $from?->toDateString(),
                'to' => $to?->toDateString(),
            ],
        ]);
    }

    public function forecasts(Request $request): JsonResponse
    {
        return response()->json([
            'data' => $this->reports->forecastsSummary(
                $request->string('store_id')->toString() ?: null,
            ),
        ]);
    }

    public function userPerformance(Request $request): JsonResponse
    {
        [$from, $to] = $this->dateRange($request);

        return response()->json([
            'data' => $this->reports->userPerformanceSummary(
                $request->string('store_id')->toString() ?: null,
                $from,
                $to,
            ),
            'meta' => [
                'from' => $from?->toDateTimeString(),
                'to' => $to?->toDateTimeString(),
            ],
        ]);
    }

    public function userPerformanceSessionDetail(string $shift): JsonResponse
    {
        return response()->json([
            'data' => $this->reports->userPerformanceSessionDetail($shift),
        ]);
    }

    public function userPerformanceDetail(Request $request, string $user): JsonResponse
    {
        [$from, $to] = $this->dateRange($request);

        return response()->json([
            'data' => $this->reports->userPerformanceDetail(
                $user,
                $request->string('store_id')->toString() ?: null,
                $from,
                $to,
            ),
            'meta' => [
                'from' => $from?->toDateTimeString(),
                'to' => $to?->toDateTimeString(),
                'user_id' => $user,
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

    public function exportRevenue(Request $request): StreamedResponse
    {
        [$from, $to] = $this->dateRange($request);
        $summary = $this->reports->revenueSummary(
            $request->string('store_id')->toString() ?: null,
            $from,
            $to,
        );

        return $this->csvDownload('revenue-export.csv', [
            '#', 'product', 'sku', 'category', 'qty', 'cost_price', 'unit_price', 'total', 'gross_profit', 'margin_pct', 'tax', 'invoices', 'type',
        ], function () use ($summary) {
            $i = 0;
            foreach ($summary['by_product'] as $row) {
                $i++;
                yield [
                    $i,
                    $row['label'] ?? '',
                    $row['sku'] ?? '',
                    $row['category'] ?? '',
                    $row['quantity'] ?? 0,
                    $row['cost_price'] ?? '',
                    $row['unit_price'] ?? 0,
                    $row['revenue'] ?? 0,
                    $row['gross_profit'] ?? 0,
                    $row['margin_pct'] ?? 0,
                    $row['tax_total'] ?? 0,
                    $row['invoices'] ?? 0,
                    ! empty($row['is_accompaniment']) ? 'accompaniment' : 'sale',
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

    public function exportStoreStock(Request $request): StreamedResponse
    {
        [$from, $to] = $this->dateRange($request);
        $report = $this->storeStock->summarize(
            $request->string('store_id')->toString() ?: null,
            $from,
            $to,
            max(1, (int) $request->integer('idle_days', 30)),
        );

        $storeName = $report['store']['code'] ?? $report['store']['name'] ?? 'all';
        $filename = 'stock-boutique-'.preg_replace('/[^A-Za-z0-9_-]+/', '-', (string) $storeName).'.csv';

        return $this->csvDownload($filename, [
            'sku', 'product', 'category', 'unit', 'opening_qty', 'inbound_qty', 'outbound_qty',
            'closing_qty', 'min_stock', 'max_stock', 'status', 'opening_value', 'closing_value',
        ], function () use ($report) {
            foreach ($report['stock_rows'] as $row) {
                yield [
                    $row['sku'] ?? '',
                    $row['name'] ?? '',
                    $row['category'] ?? '',
                    $row['unit'] ?? '',
                    $row['opening_qty'] ?? 0,
                    $row['inbound_qty'] ?? 0,
                    $row['outbound_qty'] ?? 0,
                    $row['closing_qty'] ?? 0,
                    $row['min_stock'] ?? 0,
                    $row['max_stock'] ?? 0,
                    $row['status'] ?? '',
                    $row['opening_value'] ?? 0,
                    $row['closing_value'] ?? 0,
                ];
            }
        });
    }

    public function exportPurchases(Request $request): StreamedResponse
    {
        [$from, $to] = $this->dateRange($request);

        $query = PurchaseOrder::query()
            ->with(['supplier:id,name,code', 'warehouse:id,name'])
            ->orderByDesc('created_at');

        if ($from) {
            $query->where('created_at', '>=', $from->copy()->startOfDay());
        }
        if ($to) {
            $query->where('created_at', '<=', $to->copy()->endOfDay());
        }

        return $this->csvDownload('purchases-export.csv', [
            'order_number', 'supplier', 'warehouse', 'status', 'subtotal', 'tax', 'total', 'ordered_at', 'created_at',
        ], function () use ($query) {
            foreach ($query->cursor() as $order) {
                yield [
                    $order->order_number,
                    $order->supplier?->name,
                    $order->warehouse?->name,
                    $order->status?->value ?? $order->status,
                    $order->subtotal,
                    $order->tax_total,
                    $order->total,
                    $order->ordered_at?->toIso8601String(),
                    $order->created_at?->toIso8601String(),
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
