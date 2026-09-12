import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../pos/presentation/widgets/pos_ui.dart';
import '../data/pin_auth_service.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final _auth = PinAuthService();
  final _pinCtrl = TextEditingController();
  final _pinFocus = FocusNode();
  bool _loading = false;
  String? _error;

  String get _pin => _pinCtrl.text;

  @override
  void initState() {
    super.initState();
    _pinCtrl.addListener(_onPinChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pinFocus.requestFocus();
    });
  }

  void _onPinChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pinCtrl.removeListener(_onPinChanged);
    _pinCtrl.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pin.length != 4 || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await _auth.login(_pin);
      final repo = TerminalConfigRepository.instance;
      await repo.save(repo.config.copyWith(
        authToken: session.token,
        refreshToken: session.refreshToken,
        tokenExpiresAt: DateTime.now().add(Duration(seconds: session.expiresIn)).toIso8601String(),
        cashierId: session.id,
        cashierName: session.name,
        isSignedIn: true,
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _pinCtrl.clear();
        _loading = false;
      });
      _pinFocus.requestFocus();
    }
  }

  void _append(String digit) {
    if (_loading || _pin.length >= 4) return;
    setState(() => _error = null);
    _pinCtrl.text = '$_pin$digit';
    _pinCtrl.selection = TextSelection.collapsed(offset: _pinCtrl.text.length);
    if (_pinCtrl.text.length == 4) {
      _submit();
    }
  }

  void _backspace() {
    if (_loading || _pin.isEmpty) return;
    _pinCtrl.text = _pin.substring(0, _pin.length - 1);
    _pinCtrl.selection = TextSelection.collapsed(offset: _pinCtrl.text.length);
  }

  void _clear() {
    if (_loading) return;
    _pinCtrl.clear();
    _pinFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final config = TerminalConfigRepository.instance.config;
    final name = config.deviceName.trim().isEmpty ? 'Terminal POS' : config.deviceName.trim();
    final brandName = config.brandName;
    final logoUrl = config.brandLogoUrl;
    final wide = PosUi.isWide(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              top: 12,
              right: 12,
              child: ThemeModeButton(),
            ),
            // Capture clavier physique / HID sans occuper de place visible.
            Positioned(
              left: 0,
              top: 0,
              width: 1,
              height: 1,
              child: TextField(
                controller: _pinCtrl,
                focusNode: _pinFocus,
                autofocus: true,
                enabled: !_loading,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) => _submit(),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 28, 20, 24 + bottomInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 880 : 400),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _BrandPanel(
                                name: name,
                                brandName: brandName,
                                logoUrl: logoUrl,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _AuthPanel(
                                pinLength: _pin.length,
                                loading: _loading,
                                error: _error,
                                onDigit: _append,
                                onBack: _backspace,
                                onClear: _clear,
                                onSubmit: _submit,
                                showPad: true,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _BrandPanel(
                              name: name,
                              brandName: brandName,
                              logoUrl: logoUrl,
                              compact: true,
                            ),
                            const SizedBox(height: 16),
                            _AuthPanel(
                              pinLength: _pin.length,
                              loading: _loading,
                              error: _error,
                              onDigit: _append,
                              onBack: _backspace,
                              onClear: _clear,
                              onSubmit: _submit,
                              showPad: true,
                            ),
                          ],
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

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.name, this.brandName, this.logoUrl, this.compact = false});

  final String name;
  final String? brandName;
  final String? logoUrl;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final title = (brandName != null && brandName!.trim().isNotEmpty) ? brandName!.trim() : 'POS';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(compact ? 20 : 28, compact ? 22 : 36, compact ? 20 : 28, compact ? 22 : 36),
      decoration: BoxDecoration(
        color: AppColors.brand900,
        borderRadius: BorderRadius.circular(PosUi.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (logoUrl != null && logoUrl!.trim().isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    logoUrl!,
                    width: compact ? 40 : 52,
                    height: compact ? 40 : 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.storefront, color: AppColors.accent, size: compact ? 28 : 36),
                  ),
                ),
                SizedBox(width: compact ? 12 : 16),
              ],
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: compact ? 24 : 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Connexion caissier',
            style: GoogleFonts.inter(
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          SizedBox(height: compact ? 14 : 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.point_of_sale_outlined, size: 18, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 20),
            Text(
              'Saisissez votre code PIN pour ouvrir la caisse.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({
    required this.pinLength,
    required this.loading,
    required this.error,
    required this.onDigit,
    required this.onBack,
    required this.onClear,
    required this.onSubmit,
    required this.showPad,
  });

  final int pinLength;
  final bool loading;
  final String? error;
  final ValueChanged<String> onDigit;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final VoidCallback onSubmit;
  final bool showPad;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(PosUi.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Code PIN',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '4 chiffres',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 22),
          _PinDots(length: pinLength, max: 4, hasError: error != null),
          if (error != null) ...[
            const SizedBox(height: 14),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 22),
          if (showPad)
            _Pad(
              enabled: !loading,
              onDigit: onDigit,
              onBack: onBack,
              onClear: onClear,
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: PosUi.ctaHeight,
            child: FilledButton(
              onPressed: loading || pinLength != 4 ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(
                      'Se connecter',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.length, required this.max, required this.hasError});

  final int length;
  final int max;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(max, (index) {
        final filled = index < length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: filled ? 14 : 12,
          height: filled ? 14 : 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? (hasError ? AppColors.danger : AppColors.brand600)
                : Colors.transparent,
            border: Border.all(
              color: hasError
                  ? AppColors.danger.withValues(alpha: 0.55)
                  : (filled ? AppColors.brand600 : AppColors.borderStrong),
              width: 1.5,
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
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.55,
      physics: const NeverScrollableScrollPhysics(),
      children: keys.map((key) {
        final isAction = key == 'clear' || key == 'back';
        final label = switch (key) {
          'clear' => 'C',
          'back' => '⌫',
          _ => key,
        };
        return Material(
          color: isAction ? AppColors.fieldFill : AppColors.canvas,
          borderRadius: BorderRadius.circular(12),
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
            borderRadius: BorderRadius.circular(12),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: isAction ? 16 : 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
