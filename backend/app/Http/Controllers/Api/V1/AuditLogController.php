<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuditLogController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = AuditLog::query()
            ->with(['user:id,name,email'])
            ->orderByDesc('created_at');

        if ($request->filled('action')) {
            $query->where('action', $request->string('action'));
        }

        if ($request->filled('entity_type')) {
            $query->where('entity_type', $request->string('entity_type'));
        }

        if ($request->filled('entity_id')) {
            $query->where('entity_id', $request->string('entity_id'));
        }

        if ($request->filled('user_id')) {
            $query->where('user_id', $request->string('user_id'));
        }

        if ($request->filled('from')) {
            $query->where('created_at', '>=', $request->date('from')->startOfDay());
        }

        if ($request->filled('to')) {
            $query->where('created_at', '<=', $request->date('to')->endOfDay());
        }

        return response()->json([
            'data' => $query->paginate($request->integer('per_page', 25)),
        ]);
    }

    public function show(AuditLog $auditLog): JsonResponse
    {
        return response()->json([
            'data' => $auditLog->load(['user:id,name,email']),
        ]);
    }
}
