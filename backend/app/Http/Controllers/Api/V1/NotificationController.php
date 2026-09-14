<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\Notifications\NotificationWatch;
use Illuminate\Http\JsonResponse;

class NotificationController extends Controller
{
    public function __construct(private readonly NotificationWatch $watch) {}

    public function index(): JsonResponse
    {
        $items = $this->watch->collect();

        return response()->json([
            'data' => $items,
            'meta' => ['count' => count($items)],
        ]);
    }
}
