<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Mail\BusinessNotificationMail;
use App\Models\Tenant;
use App\Services\Organization\TenantProvisioningService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class PublicSignupController extends Controller
{
    public function __construct(private readonly TenantProvisioningService $provisioning) {}

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'company_name' => ['required', 'string', 'max:255'],
            'admin_name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['nullable', 'string', 'max:50'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'plan' => ['required', Rule::in(['starter', 'professional', 'business', 'enterprise'])],
        ]);

        $created = $this->provisioning->provision([
            'name' => $data['company_name'],
            'email' => $data['email'],
            'phone' => $data['phone'] ?? null,
            'status' => 'trial',
            'plan' => $data['plan'],
            'admin_name' => $data['admin_name'],
            'admin_email' => $data['email'],
            'admin_password' => $data['password'],
        ]);

        if ($created['idempotent'] ?? false) {
            throw ValidationException::withMessages([
                'company_name' => ['Une entreprise porte déjà ce nom. Choisissez un autre nom.'],
            ]);
        }

        $tenant = $created['tenant'];
        $settings = $tenant->settings ?? [];
        $settings['signup'] = [
            'awaiting_approval' => true,
            'requested_plan' => $data['plan'],
            'requested_at' => now()->toIso8601String(),
        ];
        $tenant->settings = $settings;
        $tenant->save();

        $this->sendWelcome($tenant, $data);

        return response()->json([
            'data' => [
                'tenant' => [
                    'name' => $tenant->name,
                    'slug' => $tenant->slug,
                ],
                'email' => $data['email'],
                'message' => 'Inscription enregistrée. Un e-mail confirme votre souscription et contient les identifiants de l’administrateur.',
            ],
        ], 201);
    }

    /** @param  array{company_name: string, admin_name: string, email: string, password: string, plan: string}  $data */
    private function sendWelcome(Tenant $tenant, array $data): void
    {
        $plans = [
            'starter' => 'Starter',
            'professional' => 'Professional',
            'business' => 'Business',
            'enterprise' => 'Enterprise',
        ];
        $login = rtrim((string) config('app.frontend_url'), '/').'/login?tenant='.urlencode($tenant->slug);
        $body = implode("\n", [
            'Bonjour '.$data['admin_name'].',',
            '',
            'Vous avez bien souscrit au bouquet '.($plans[$data['plan']] ?? $data['plan']).' pour l’entreprise '.$tenant->name.'.',
            'Votre demande est enregistrée. Le super administrateur validera ensuite votre bouquet.',
            '',
            'Identifiants de l’administrateur de votre espace :',
            'Entreprise : '.$tenant->name,
            'Identifiant tenant : '.$tenant->slug,
            'E-mail : '.$data['email'],
            'Mot de passe : '.$data['password'],
            '',
            'Connexion : '.$login,
        ]);

        Mail::to($data['email'])->send(new BusinessNotificationMail(
            'Votre souscription '.$tenant->name,
            $body,
        ));
    }
}
