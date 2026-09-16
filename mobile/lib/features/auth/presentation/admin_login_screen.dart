import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../../core/branding/branding_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../pos/presentation/widgets/pos_ui.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiUrlCtrl = TextEditingController(text: AppConfig.apiBaseUrl);
  final _slugCtrl = TextEditingController(text: 'demo');
  final _emailCtrl = TextEditingController(text: 'admin@pos.local');
  final _passwordCtrl = TextEditingController(text: 'password');
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    _slugCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final apiBase = _apiUrlCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
      final slug = _slugCtrl.text.trim().toLowerCase();
      final branding = await BrandingService().fetchPublic(slug: slug, apiBaseUrl: apiBase);
      final tenantId = branding.tenantId;
      if (tenantId.isEmpty) {
        throw Exception('Tenant introuvable pour le slug « $slug ».');
      }

      final response = await http
          .post(
            Uri.parse('$apiBase/auth/login'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'X-Tenant-ID': tenantId,
            },
            body: jsonEncode({
              'email': _emailCtrl.text.trim(),
              'password': _passwordCtrl.text,
              'device_name': 'pos-setup',
            }),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = jsonDecode(response.body);
      final body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

      if (response.statusCode != 200) {
        final message = body['message']?.toString()
            ?? (body['errors'] is Map
                ? ((body['errors'] as Map).values.first is List
                    ? ((body['errors'] as Map).values.first as List).first?.toString()
                    : null)
                : null)
            ?? 'Connexion refusée (HTTP ${response.statusCode})';
        throw Exception(message);
      }

      final access = (body['access_token'] as String? ?? '').trim();
      final refresh = (body['refresh_token'] as String? ?? '').trim();
      final user = body['user'] as Map<String, dynamic>? ?? {};
      if (access.isEmpty) throw Exception('Jeton d’accès absent');

      final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 3600;
      final repo = TerminalConfigRepository.instance;
      await repo.save(repo.config.copyWith(
        apiBaseUrl: apiBase,
        authToken: access,
        refreshToken: refresh,
        tokenExpiresAt: DateTime.now().add(Duration(seconds: expiresIn)).toIso8601String(),
        tenantId: (user['tenant_id'] as String?)?.trim().isNotEmpty == true
            ? user['tenant_id'].toString()
            : tenantId,
        tenantSlug: branding.slug,
        brandName: branding.brandName,
        brandLogoUrl: branding.logoUrl ?? '',
        brandPrimaryColor: branding.primaryColor,
        brandAccentColor: branding.accentColor,
        cashierId: user['id']?.toString() ?? '',
        cashierName: user['name']?.toString() ?? 'Admin',
        permissions: (user['permissions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        roles: (user['roles'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        isSignedIn: true,
        isConfigured: false,
      ));
      ThemeController.instance.applyFromConfig();

      if (!mounted) return;
      context.go(AppRoutes.setup);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = PosUi.isWide(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(top: 12, right: 12, child: ThemeModeButton()),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 440 : 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'ITARA POS',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ibmPlexSans(fontSize: 26, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Connexion administrateur',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ibmPlexSans(fontSize: 15, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connectez-vous d’abord avec le compte admin, puis configurez le terminal.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ibmPlexSans(fontSize: 12.5, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _apiUrlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'URL API',
                            hintText: 'http://localhost:8000/api/v1',
                            prefixIcon: Icon(Icons.cloud_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'URL requise' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _slugCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Slug tenant',
                            hintText: 'demo',
                            prefixIcon: Icon(Icons.tag_outlined),
                          ),
                          textCapitalization: TextCapitalization.none,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Slug requis' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'E-mail admin',
                            hintText: 'admin@pos.local',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          validator: (v) => (v == null || !v.contains('@')) ? 'E-mail invalide' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                          ),
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          validator: (v) => (v == null || v.isEmpty) ? 'Mot de passe requis' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.dangerBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                            ),
                            child: Text(_error!, style: GoogleFonts.ibmPlexSans(color: AppColors.danger, fontWeight: FontWeight.w600)),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                  )
                                : const Text('Se connecter'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
