import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../core/branding/branding_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/terminal_bloc.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/network/network_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../sync/local_master_server.dart';
import 'bloc/authentication_bloc.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Owner sign-in asks the router to open settings instead of the selling screen.
abstract final class AuthNavigation {
  static bool openSettings = false;
}

enum AuthGateMode { staff, root }

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key, this.initialMode = AuthGateMode.staff});

  final AuthGateMode initialMode;

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final _pinCtrl = TextEditingController();
  final _pinFocus = FocusNode();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late final TextEditingController _apiCtrl;
  late final TextEditingController _slugCtrl;

  late AuthGateMode _mode;
  bool _showPad = false;
  bool _obscure = true;
  bool _rootLoading = false;
  String? _rootError;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    final config = TerminalConfigRepository.instance.config;
    _apiCtrl = TextEditingController(
      text: config.apiBaseUrl.trim().isEmpty ? AppConfig.apiBaseUrl : config.apiBaseUrl,
    );
    _slugCtrl = TextEditingController(
      text: config.tenantSlug.trim().isEmpty ? 'demo' : config.tenantSlug,
    );
    _pinCtrl.addListener(_onPinChanged);
    if (_mode == AuthGateMode.staff) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pinFocus.requestFocus();
      });
    }
  }

  void _onPinChanged() {
    if (!mounted || _mode != AuthGateMode.staff) return;
    setState(() {});
    if (_pinCtrl.text.length == 4) _submitPin();
  }

  @override
  void dispose() {
    _pinCtrl.removeListener(_onPinChanged);
    _pinCtrl.dispose();
    _pinFocus.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _apiCtrl.dispose();
    _slugCtrl.dispose();
    super.dispose();
  }

  void _setMode(AuthGateMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _rootError = null;
      _showPad = false;
    });
    if (mode == AuthGateMode.staff) {
      _pinFocus.requestFocus();
    } else {
      _pinFocus.unfocus();
    }
  }

  void _append(String digit) {
    if (_rootLoading || _pinCtrl.text.length >= 4) return;
    if (context.read<AuthenticationBloc>().state.isLoading) return;
    _pinCtrl.text = '${_pinCtrl.text}$digit';
    _pinCtrl.selection = TextSelection.collapsed(offset: _pinCtrl.text.length);
  }

  void _backspace() {
    if (_pinCtrl.text.isEmpty) return;
    if (context.read<AuthenticationBloc>().state.isLoading) return;
    _pinCtrl.text = _pinCtrl.text.substring(0, _pinCtrl.text.length - 1);
    _pinCtrl.selection = TextSelection.collapsed(offset: _pinCtrl.text.length);
  }

  void _clearPin() {
    if (context.read<AuthenticationBloc>().state.isLoading) return;
    _pinCtrl.clear();
    _pinFocus.requestFocus();
  }

  void _submitPin() {
    final pin = _pinCtrl.text;
    if (pin.length != 4) return;
    if (context.read<AuthenticationBloc>().state.isLoading) return;
    context.read<AuthenticationBloc>().add(AuthenticationPinSubmitted(pin));
  }

  Future<void> _submitRoot() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (_rootLoading) return;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _rootError = 'Enter a valid email.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _rootError = 'Password is required.');
      return;
    }

    setState(() {
      _rootLoading = true;
      _rootError = null;
    });

    try {
      final apiBase = _apiCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
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
              'email': email,
              'password': password,
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
        throw Exception(humanizeApiCode(message));
      }

      final access = (body['access_token'] as String? ?? '').trim();
      final refresh = (body['refresh_token'] as String? ?? '').trim();
      final user = body['user'] as Map<String, dynamic>? ?? {};
      if (access.isEmpty) throw Exception('Jeton d’accès absent');

      final roles = (user['roles'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
      final permissions = (user['permissions'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
      final isAdmin = user['is_super_admin'] == true ||
          roles.any((role) => role == 'administrator' || role == 'super_admin' || role == 'admin') ||
          permissions.contains('*');
      if (!isAdmin) throw Exception(AppCopy.get('adminOnly'));

      final userTenant = (user['tenant_id'] as String?)?.trim() ?? '';
      final superAdmin = user['is_super_admin'] == true;
      if (!superAdmin && userTenant.isNotEmpty && userTenant != tenantId) {
        throw Exception(AppCopy.get('tenantMismatch'));
      }

      final stores = (user['store_ids'] as List?)
              ?.map((e) => e.toString())
              .where((id) => id.trim().isNotEmpty)
              .toList() ??
          const <String>[];

      final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 3600;
      final repo = TerminalConfigRepository.instance;
      final wasConfigured = repo.isConfigured;
      final currentStore = repo.config.storeId;
      final chosenStore = stores.contains(currentStore)
          ? currentStore
          : (stores.isNotEmpty ? stores.first : currentStore);
      AuthNavigation.openSettings = true;
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
        storeId: chosenStore,
        cashierId: user['id']?.toString() ?? '',
        cashierName: user['name']?.toString() ?? 'Admin',
        cashierEmail: user['email']?.toString() ?? '',
        cashierCode: user['employee_code']?.toString() ?? '',
        permissions: permissions,
        roles: roles,
        locale: LocaleController.instance.code,
        isSignedIn: true,
      ));
      ThemeController.instance.applyFromConfig();
      if (!mounted) return;
      if (!wasConfigured) context.go(AppRoutes.cashierSettings);
    } catch (error) {
      AuthNavigation.openSettings = false;
      if (!mounted) return;
      setState(() {
        _rootError = humanizeApiCode(error.toString().replaceFirst('Exception: ', ''));
        _rootLoading = false;
      });
    }
  }


  Future<void> _editConnection() async {
    final api = TextEditingController(text: _apiCtrl.text);
    final slug = TextEditingController(text: _slugCtrl.text);
    final saved = await AppDialogs.show<bool>(
      context: context,
      title: AppCopy.get('serverConnection'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: api,
            style: AppTypography.plex(color: AppColors.textPrimary),
            decoration: InputDecoration(labelText: AppCopy.get('apiUrl')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: slug,
            style: AppTypography.plex(color: AppColors.textPrimary),
            decoration: InputDecoration(labelText: AppCopy.get('tenantSlugLabel')),
          ),
        ],
      ),
      actionsBuilder: (dialogContext) => [
        AppButton.secondary(
          label: AppCopy.get('cancel'),
          onPressed: () => Navigator.pop(dialogContext, false),
        ),
        AppButton.primary(
          label: AppCopy.get('save'),
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
    );
    if (saved == true) {
      _apiCtrl.text = api.text.trim();
      _slugCtrl.text = slug.text.trim();
    }
    api.dispose();
    slug.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final wide = MediaQuery.sizeOf(context).width >= 960;

    return BlocConsumer<AuthenticationBloc, AuthenticationState>(
      listenWhen: (prev, next) => prev.status != next.status || prev.errorMessage != next.errorMessage,
      listener: (context, state) {
        if (state.status == AuthenticationStatus.failure && _mode == AuthGateMode.staff) {
          _pinCtrl.clear();
          _pinFocus.requestFocus();
        }
      },
      builder: (context, auth) {
        final loading = auth.isLoading && _mode == AuthGateMode.staff;
        final pinError = _mode == AuthGateMode.staff && auth.status == AuthenticationStatus.failure
            ? auth.errorMessage
            : null;
        final form = _AuthForm(
          mode: _mode,
          pinCtrl: _pinCtrl,
          pinFocus: _pinFocus,
          pinLength: _pinCtrl.text.length,
          pinLoading: loading,
          pinError: pinError,
          showPad: _showPad,
          onTogglePad: () => setState(() => _showPad = !_showPad),
          onDigit: _append,
          onBack: _backspace,
          onClear: _clearPin,
          onSubmitPin: _submitPin,
          email: _emailCtrl,
          password: _passwordCtrl,
          obscure: _obscure,
          rootLoading: _rootLoading,
          rootError: _rootError,
          onToggleObscure: () => setState(() => _obscure = !_obscure),
          onSubmitRoot: _submitRoot,
          keyboardOpen: bottomInset > 0,
        );

        return Scaffold(
          backgroundColor: AppColors.canvas,
          resizeToAvoidBottomInset: false,
          body: AnimatedPadding(
            padding: EdgeInsets.only(bottom: bottomInset),
            duration: AppMotion.resolve(context, const Duration(milliseconds: 420)),
            curve: AppMotion.emphasized,
            onEnd: _revealFocusedField,
            child: SafeArea(
            child: wide
                ? Row(
                    children: [
                      const Expanded(flex: 6, child: _AuthHero()),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
                              child: Row(
                                children: [
                                  _ServerBadge(onTap: _editConnection),
                                  const Spacer(),
                                  _ModeSwitch(
                                    root: _mode == AuthGateMode.root,
                                    onChanged: (root) => _setMode(root ? AuthGateMode.root : AuthGateMode.staff),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(child: form),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Row(
                            children: [
                              Flexible(child: _ServerBadge(onTap: _editConnection)),
                              const SizedBox(width: 8),
                              _ModeSwitch(
                                root: _mode == AuthGateMode.root,
                                onChanged: (root) => _setMode(root ? AuthGateMode.root : AuthGateMode.staff),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: form),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  void _revealFocusedField() {
    if (!mounted || MediaQuery.viewInsetsOf(context).bottom == 0) return;
    FocusManager.instance.primaryFocus?.context?.findRenderObject()?.showOnScreen(
          duration: const Duration(milliseconds: 420),
          curve: AppMotion.emphasized,
        );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero();

  @override
  Widget build(BuildContext context) {
    final config = context.watch<TerminalBloc>().state.config;
    final brand = config.brandName.trim().isEmpty ? 'ITARA' : config.brandName.trim();
    return ColoredBox(
      color: AppColors.brand600,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 36, 40, 32),
        child: ListenableBuilder(
          listenable: LocaleController.instance,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _BrandMark(logoUrl: config.brandLogoUrl, initials: _initials(brand), compact: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(brand),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.plex(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            tr('ITARA POS'),
                            style: AppTypography.plex(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(width: 42, height: 3, color: AppColors.accent),
                const SizedBox(height: 18),
                Text(
                  tr(_greeting()),
                  style: AppTypography.plex(
                    color: AppColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppCopy.get('loginHeadline'),
                  style: AppTypography.plex(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppCopy.get('loginPitch'),
                  style: AppTypography.plex(color: AppColors.sidebarText, fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 28),
                _ProductPoint(index: '01', title: AppCopy.get('loginSale'), hint: AppCopy.get('loginSaleHint')),
                const SizedBox(height: 12),
                _ProductPoint(index: '02', title: AppCopy.get('loginStock'), hint: AppCopy.get('loginStockHint')),
                const SizedBox(height: 12),
                _ProductPoint(index: '03', title: AppCopy.get('loginShops'), hint: AppCopy.get('loginShopsHint')),
                const Spacer(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProductPoint extends StatelessWidget {
  const _ProductPoint({required this.index, required this.title, required this.hint});

  final String index;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.sidebarActive,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.sidebarBorder),
          ),
          child: Text(
            tr(index),
            style: AppTypography.plex(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(title), style: AppTypography.plex(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              Text(tr(hint), style: AppTypography.plex(color: AppColors.sidebarText, fontSize: 12.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.mode,
    required this.pinCtrl,
    required this.pinFocus,
    required this.pinLength,
    required this.pinLoading,
    required this.pinError,
    required this.showPad,
    required this.onTogglePad,
    required this.onDigit,
    required this.onBack,
    required this.onClear,
    required this.onSubmitPin,
    required this.email,
    required this.password,
    required this.obscure,
    required this.rootLoading,
    required this.rootError,
    required this.onToggleObscure,
    required this.onSubmitRoot,
    required this.keyboardOpen,
  });

  final AuthGateMode mode;
  final TextEditingController pinCtrl;
  final FocusNode pinFocus;
  final int pinLength;
  final bool pinLoading;
  final String? pinError;
  final bool showPad;
  final VoidCallback onTogglePad;
  final ValueChanged<String> onDigit;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final VoidCallback onSubmitPin;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final bool rootLoading;
  final String? rootError;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmitRoot;
  final bool keyboardOpen;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final config = context.watch<TerminalBloc>().state.config;
    final brand = config.brandName.trim().isEmpty ? 'ITARA' : config.brandName.trim();
    final motion = AppMotion.resolve(context, const Duration(milliseconds: 420));
    final pane = mode == AuthGateMode.staff
        ? _StaffPane(
            key: const ValueKey('staff'),
            controller: pinCtrl,
            focusNode: pinFocus,
            length: pinLength,
            loading: pinLoading,
            error: pinError,
            showPad: showPad,
            onTogglePad: onTogglePad,
            onDigit: onDigit,
            onBack: onBack,
            onClear: onClear,
            onSubmit: onSubmitPin,
          )
        : _RootPane(
            key: const ValueKey('root'),
            email: email,
            password: password,
            obscure: obscure,
            loading: rootLoading,
            error: rootError,
            onToggleObscure: onToggleObscure,
            onSubmit: onSubmitRoot,
          );

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, wide ? 36 : 12, 24, 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AnimatedSlide(
            duration: motion,
            curve: AppMotion.emphasized,
            offset: keyboardOpen && !wide ? const Offset(0, -0.06) : Offset.zero,
            child: AnimatedScale(
              duration: motion,
              curve: AppMotion.emphasized,
              scale: keyboardOpen && !wide ? 0.96 : 1,
              alignment: Alignment.topCenter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.borderXl,
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brand900.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                    ...AppColors.elevationSm,
                  ],
                ),
                child: ClipRRect(
                  borderRadius: AppRadius.borderXl,
                  child: Column(
                    children: [
                      if (!wide)
                        AnimatedContainer(
                          duration: motion,
                          curve: AppMotion.emphasized,
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(
                            22,
                            keyboardOpen ? 10 : 22,
                            22,
                            keyboardOpen ? 10 : 20,
                          ),
                          color: AppColors.brand600,
                          child: ListenableBuilder(
                            listenable: LocaleController.instance,
                            builder: (context, _) {
                              return Column(
                                children: [
                                  AnimatedCrossFade(
                                    duration: motion,
                                    firstCurve: AppMotion.exit,
                                    secondCurve: AppMotion.enter,
                                    sizeCurve: AppMotion.emphasized,
                                    crossFadeState: keyboardOpen
                                        ? CrossFadeState.showSecond
                                        : CrossFadeState.showFirst,
                                    firstChild: SizedBox(
                                      width: double.infinity,
                                      child: Column(
                                        children: [
                                          _BrandMark(
                                            logoUrl: config.brandLogoUrl,
                                            initials: _initials(brand),
                                            compact: true,
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            tr(_greeting()),
                                            style: AppTypography.plex(
                                              color: AppColors.accent,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                      ),
                                    ),
                                    secondChild: const SizedBox(width: double.infinity),
                                  ),
                                  AnimatedDefaultTextStyle(
                                    duration: motion,
                                    curve: AppMotion.emphasized,
                                    style: AppTypography.plex(
                                      color: Colors.white,
                                      fontSize: keyboardOpen ? 18 : 24,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                    child: Text(tr(brand), textAlign: TextAlign.center),
                                  ),
                                  AnimatedSize(
                                    duration: motion,
                                    curve: AppMotion.emphasized,
                                    child: keyboardOpen
                                        ? const SizedBox(width: double.infinity)
                                        : Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              AppCopy.get('loginHeadline'),
                                              textAlign: TextAlign.center,
                                              style: AppTypography.plex(
                                                color: AppColors.sidebarText,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                        child: AnimatedSwitcher(
                          duration: AppMotion.resolve(context, AppMotion.content),
                          child: pane,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerBadge extends StatelessWidget {
  const _ServerBadge({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([LocalMasterServer.instance, LocaleController.instance]),
      builder: (context, _) {
        return BlocBuilder<NetworkBloc, NetworkState>(
          builder: (context, net) {
            final running = LocalMasterServer.instance.listening || net.masterReachable || net.internetReachable;
            final label = AppCopy.get(running ? 'serverRunning' : 'serverOffline');
            final dot = running ? AppColors.success : AppColors.brand300;
            final foreground = AppColors.textPrimary;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: AppRadius.borderPill,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.borderPill,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr(label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.plex(color: foreground, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.root, required this.onChanged});

  final bool root;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: AppRadius.borderPill,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeChip(
                label: AppCopy.get('staffMode'),
                selected: !root,
                onTap: () => onChanged(false),
              ),
              _ModeChip(
                label: AppCopy.get('rootMode'),
                selected: root,
                onTap: () => onChanged(true),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brand600 : Colors.transparent,
      borderRadius: AppRadius.borderPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderPill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            tr(label),
            style: AppTypography.plex(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.logoUrl, required this.initials, this.compact = false});

  final String logoUrl;
  final String initials;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 72.0 : 84.0;
    final logo = logoUrl.trim();
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
      child: DecoratedBox(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        child: ClipOval(
          child: logo.isEmpty
              ? Center(
                  child: Text(
                    tr(initials),
                    style: AppTypography.plex(
                      color: AppColors.brand900,
                      fontSize: compact ? 22 : 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : Image.network(
                  logo,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      tr(initials),
                      style: AppTypography.plex(
                        color: AppColors.brand900,
                        fontSize: compact ? 22 : 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _StaffPane extends StatelessWidget {
  const _StaffPane({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.loading,
    required this.error,
    required this.showPad,
    required this.onTogglePad,
    required this.onDigit,
    required this.onBack,
    required this.onClear,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool loading;
  final String? error;
  final bool showPad;
  final VoidCallback onTogglePad;
  final ValueChanged<String> onDigit;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        return Column(
          children: [
            Text(
              AppCopy.get('pinTitle'),
              textAlign: TextAlign.center,
              style: AppTypography.plex(
                color: AppColors.brand600,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppCopy.get('pinHint'),
              textAlign: TextAlign.center,
              style: AppTypography.plex(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 26),
            _PinDots(length: length, hasError: error != null),
            const SizedBox(height: 18),
            _FieldShell(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !loading,
                obscureText: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: AppTypography.plex(color: AppColors.textPrimary, fontSize: 20, letterSpacing: 10, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  hintStyle: AppTypography.plex(color: AppColors.textMuted, letterSpacing: 10, fontSize: 20),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) => onSubmit(),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: AppRadius.borderLg,
                ),
                child: Text(
                  tr(error!),
                  textAlign: TextAlign.center,
                  style: AppTypography.plex(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600, height: 1.35),
                ),
              ),
            ],
            if (loading) ...[
              const SizedBox(height: 16),
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand700),
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: loading ? null : onTogglePad,
              style: TextButton.styleFrom(foregroundColor: AppColors.brand700),
              icon: Icon(showPad ? Icons.keyboard_hide_outlined : Icons.dialpad_rounded, size: 18),
              label: Text(
                AppCopy.get(showPad ? 'hideKeypad' : 'useKeypad'),
                style: AppTypography.plex(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.brand700),
              ),
            ),
            if (showPad) ...[
              const SizedBox(height: 4),
              _Pad(enabled: !loading, onDigit: onDigit, onBack: onBack, onClear: onClear),
            ],
          ],
        );
      },
    );
  }
}

class _RootPane extends StatelessWidget {
  const _RootPane({
    super.key,
    required this.email,
    required this.password,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final bool loading;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        return Column(
          children: [
            const LanguagePicker(),
            const SizedBox(height: 22),
            Text(
              AppCopy.get('settingsMode'),
              textAlign: TextAlign.center,
              style: AppTypography.plex(
                color: AppColors.brandInk,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppCopy.get('ownerHint'),
              textAlign: TextAlign.center,
              style: AppTypography.plex(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: AppRadius.borderPill),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 15, color: AppColors.violet600),
                  const SizedBox(width: 6),
                  Text(
                    AppCopy.get('ownerBadge'),
                    style: AppTypography.plex(color: AppColors.brandInk, fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _FieldShell(
              child: TextField(
                controller: email,
                enabled: !loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: AppTypography.plex(color: AppColors.textPrimary, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: AppCopy.get('emailHint'),
                  hintStyle: AppTypography.plex(color: AppColors.textMuted, fontSize: 14.5),
                  prefixIcon: Icon(Icons.mail_outline, color: AppColors.textMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _FieldShell(
              child: TextField(
                controller: password,
                enabled: !loading,
                obscureText: obscure,
                onSubmitted: (_) => onSubmit(),
                style: AppTypography.plex(color: AppColors.textPrimary, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: AppCopy.get('passwordHint'),
                  hintStyle: AppTypography.plex(color: AppColors.textMuted, fontSize: 14.5),
                  prefixIcon: Icon(Icons.lock_outline, color: AppColors.textMuted, size: 20),
                  suffixIcon: IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: AppRadius.borderLg),
                child: Text(
                  tr(error!),
                  textAlign: TextAlign.center,
                  style: AppTypography.plex(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600, height: 1.35),
                ),
              ),
            ],
            const SizedBox(height: 18),
            AppButton.primary(
              label: AppCopy.get('signIn'),
              icon: Icons.login_rounded,
              expanded: true,
              loading: loading,
              onPressed: loading ? null : onSubmit,
            ),
          ],
        );
      },
    );
  }
}

class _FieldShell extends StatelessWidget {
  const _FieldShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.length, required this.hasError});

  final int length;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final filled = index < length;
        final active = !hasError && index == length && length < 4;
        final color = hasError ? AppColors.danger : AppColors.brand700;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 7),
          width: filled ? 16 : 14,
          height: filled ? 16 : 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : Colors.transparent,
            border: Border.all(
              color: filled ? color : (active ? AppColors.accent : AppColors.borderStrong),
              width: active ? 2 : 1.6,
            ),
          ),
        );
      }),
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({
    required this.enabled,
    required this.onDigit,
    required this.onBack,
    required this.onClear,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBack;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'clear', '0', 'back'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      physics: const NeverScrollableScrollPhysics(),
      children: keys.map((key) {
        final utility = key == 'clear' || key == 'back';
        return Material(
          color: utility ? AppColors.surfaceVariant : AppColors.surface,
          elevation: 0,
          borderRadius: AppRadius.borderLg,
          child: InkWell(
            onTap: !enabled
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    if (key == 'clear') {
                      onClear();
                    } else if (key == 'back') {
                      onBack();
                    } else {
                      onDigit(key);
                    }
                  },
            borderRadius: AppRadius.borderLg,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: AppRadius.borderLg,
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: key == 'back'
                    ? const Icon(Icons.backspace_outlined, color: AppColors.brand700, size: 20)
                    : Text(
                        tr(key == 'clear' ? 'C' : key),
                        style: AppTypography.plex(
                          color: utility ? AppColors.brand700 : AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return AppCopy.get('greetMorning');
  if (hour < 18) return AppCopy.get('greetAfternoon');
  return AppCopy.get('greetEvening');
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2);
  final letters = parts.map((part) => part[0].toUpperCase()).join();
  return letters.isEmpty ? 'IT' : letters;
}
