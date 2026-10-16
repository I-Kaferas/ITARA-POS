import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../domain/screen_lock_controller.dart';

const _accent = Color(0xFF7C5CFF);
const _pinLength = 4;

/// Full-screen lock drawn above the whole app (no Navigator/Overlay here),
/// so it only uses widgets that need a [Material] ancestor.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _focus = FocusNode(debugLabel: 'lock-screen');
  Timer? _clock;
  Timer? _idle;
  DateTime _now = DateTime.now();
  bool _signIn = false;
  bool _checking = false;
  String _pin = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _idle?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _reveal() {
    _idle?.cancel();
    _idle = Timer(const Duration(seconds: 30), () {
      if (mounted && !_checking) setState(() => _back());
    });
    if (!_signIn) setState(() => _signIn = true);
    _focus.requestFocus();
  }

  void _back() {
    _signIn = false;
    _pin = '';
    _error = null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (!_signIn) {
      _reveal();
      return KeyEventResult.handled;
    }
    _reveal();
    if (key == LogicalKeyboardKey.escape) {
      setState(_back);
    } else if (key == LogicalKeyboardKey.backspace) {
      _erase();
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      unawaited(_submit());
    } else {
      final char = event.character;
      if (char != null && RegExp(r'^\d$').hasMatch(char)) _type(char);
    }
    return KeyEventResult.handled;
  }

  void _type(String digit) {
    if (_checking || _pin.length >= _pinLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == _pinLength) unawaited(_submit());
  }

  void _erase() {
    if (_checking || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_checking || _pin.length < _pinLength) return;
    setState(() => _checking = true);
    final error = await ScreenLockController.instance.unlock(_pin);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _pin = '';
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = TerminalConfigRepository.instance.config;
    final name = config.cashierName.trim().isEmpty ? tr('Caissier') : config.cashierName.trim();
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _reveal,
          child: Stack(
            fit: StackFit.expand,
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xE60B1020), Color(0xF0181036), Color(0xE60B1020)],
                    ),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
                child: _signIn
                    ? _SignInPanel(
                        key: const ValueKey('sign-in'),
                        name: name,
                        device: config.deviceName.trim(),
                        pinLength: _pin.length,
                        checking: _checking,
                        error: _error,
                        onDigit: (d) {
                          _reveal();
                          _type(d);
                        },
                        onErase: () {
                          _reveal();
                          _erase();
                        },
                        onSwitchUser: () => unawaited(ScreenLockController.instance.switchUser()),
                      )
                    : _ClockPanel(key: const ValueKey('clock'), now: _now, name: name),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClockPanel extends StatelessWidget {
  const _ClockPanel({super.key, required this.now, required this.name});

  final DateTime now;
  final String name;

  static const _days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  @override
  Widget build(BuildContext context) {
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final date = tr('${_days[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}');
    return Column(
      children: [
        const Spacer(flex: 2),
        Text(
          time,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 112,
            height: 1,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          date[0].toUpperCase() + date.substring(1),
          style: GoogleFonts.ibmPlexSans(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white70),
        ),
        const Spacer(flex: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 16, color: Colors.white60),
            const SizedBox(width: 8),
            Text(
              trf('Session de {0} verrouillée', [name]),
              style: GoogleFonts.ibmPlexSans(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          tr('Cliquez ou appuyez sur une touche pour déverrouiller'),
          style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white54),
        ),
        const SizedBox(height: 36),
      ],
    );
  }
}

class _SignInPanel extends StatelessWidget {
  const _SignInPanel({
    super.key,
    required this.name,
    required this.device,
    required this.pinLength,
    required this.checking,
    required this.error,
    required this.onDigit,
    required this.onErase,
    required this.onSwitchUser,
  });

  final String name;
  final String device;
  final int pinLength;
  final bool checking;
  final String? error;
  final ValueChanged<String> onDigit;
  final VoidCallback onErase;
  final VoidCallback onSwitchUser;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 112,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [_accent, Color(0xFF5B3DF5)]),
                border: Border.all(color: Colors.white24, width: 3),
              ),
              child: Text(
                name[0].toUpperCase(),
                style: GoogleFonts.ibmPlexSans(fontSize: 46, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: GoogleFonts.ibmPlexSans(fontSize: 26, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            if (device.isNotEmpty)
              Text(device, style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white60)),
            const SizedBox(height: 22),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _pinLength; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < pinLength ? Colors.white : Colors.transparent,
                      border: Border.all(color: error != null ? const Color(0xFFFF6B6B) : Colors.white70, width: 2),
                    ),
                  ),
              ],
            ),
            SizedBox(
              height: 40,
              child: Center(
                child: checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        error != null ? tr(error!) : tr('Saisissez votre PIN'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 13.5,
                          color: error != null ? const Color(0xFFFF8A8A) : Colors.white60,
                        ),
                      ),
              ),
            ),
            SizedBox(
              width: 264,
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                    _Key(label: d, onTap: () => onDigit(d)),
                  const SizedBox.shrink(),
                  _Key(label: '0', onTap: () => onDigit('0')),
                  _Key(icon: Icons.backspace_outlined, onTap: onErase),
                ],
              ),
            ),
            const SizedBox(height: 22),
            TextButton.icon(
              onPressed: onSwitchUser,
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              icon: const Icon(Icons.switch_account_outlined, size: 18),
              label: Text(tr('Changer d’utilisateur'), style: GoogleFonts.ibmPlexSans(fontSize: 13.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 22)
              : Text(
                  label!,
                  style: GoogleFonts.ibmPlexSans(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
                ),
        ),
      ),
    );
  }
}
