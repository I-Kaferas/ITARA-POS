<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Tenant;
use App\Support\TenantBranding;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TenantBrandingController extends Controller
{
    public function publicShow(string $slug): JsonResponse
    {
        $tenant = Tenant::query()
            ->where('slug', $slug)
            ->where('status', 'active')
            ->first();

        if ($tenant === null) {
            return response()->json(['message' => 'Tenant introuvable.'], 404);
        }

        return response()->json(['data' => TenantBranding::from($tenant)]);
    }

    public function show(): JsonResponse
    {
        /** @var Tenant $tenant */
        $tenant = app('tenant');

        return response()->json(['data' => TenantBranding::from($tenant)]);
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'brand_name' => ['sometimes', 'nullable', 'string', 'max:120'],
            'tagline' => ['sometimes', 'nullable', 'string', 'max:255'],
            'logo_url' => ['sometimes', 'nullable', 'string', 'max:2048'],
            'primary_color' => ['sometimes', 'nullable', 'regex:/^#([0-9A-Fa-f]{6})$/'],
            'accent_color' => ['sometimes', 'nullable', 'regex:/^#([0-9A-Fa-f]{6})$/'],
            'support_email' => ['sometimes', 'nullable', 'email', 'max:190'],
            'support_phone' => ['sometimes', 'nullable', 'string', 'max:40'],
            'marketing' => ['sometimes', 'array'],
            'marketing.hero_title' => ['sometimes', 'nullable', 'string', 'max:160'],
            'marketing.hero_subtitle' => ['sometimes', 'nullable', 'string', 'max:500'],
            'marketing.cta_label' => ['sometimes', 'nullable', 'string', 'max:80'],
            'marketing.cta_url' => ['sometimes', 'nullable', 'string', 'max:2048'],
        ]);

        /** @var Tenant $tenant */
        $tenant = app('tenant');
        $tenant->settings = TenantBranding::mergeSettings(
            is_array($tenant->settings) ? $tenant->settings : [],
            $data,
        );
        $tenant->save();

        return response()->json(['data' => TenantBranding::from($tenant->fresh())]);
    }
}
