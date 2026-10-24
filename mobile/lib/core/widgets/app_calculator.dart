import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../config/terminal_config_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

class AppCalculator {
  AppCalculator._();

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Calculatrice',
      barrierColor: AppColors.brand900.withValues(alpha: 0.28),
      pageBuilder: (context, _, _) {
        final inset = MediaQuery.viewInsetsOf(context).bottom;
        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 20, 20 + inset),
            child: const _CalculatorPanel(),
          ),
        );
      },
    );
  }
}

class CalculatorButton extends StatelessWidget {
  const CalculatorButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr('Calculatrice'),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.borderMd,
        child: InkWell(
          onTap: () => AppCalculator.show(context),
          borderRadius: AppRadius.borderMd,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(Icons.calculate_outlined, size: 16, color: AppColors.brandInk),
          ),
        ),
      ),
    );
  }
}

class _CalculatorPanel extends StatefulWidget {
  const _CalculatorPanel();

  @override
  State<_CalculatorPanel> createState() => _CalculatorPanelState();
}

class _CalculatorPanelState extends State<_CalculatorPanel> {
  static const _modes = ['standard', 'scientific', 'business'];
  static const _bizTabs = ['margin', 'tax', 'discount', 'change'];
  static const _standardKeys = [
    ['C', '⌫', '%', '÷'],
    ['7', '8', '9', '×'],
    ['4', '5', '6', '−'],
    ['1', '2', '3', '+'],
    ['±', '0', '.', '='],
  ];
  static const _scientificKeys = ['sin', 'cos', 'tan', 'log', 'ln', '√', 'x²', 'xʸ', '1/x', 'π', 'e', '(', ')', 'n!'];

  String _mode = 'standard';
  String _biz = 'margin';
  String _angle = 'deg';
  String _expression = '';
  String _display = '0';
  bool _justEvaluated = false;
  double _memory = 0;

  final _cost = TextEditingController();
  final _price = TextEditingController();
  final _taxRate = TextEditingController();
  final _discountRate = TextEditingController();
  final _listPrice = TextEditingController();
  final _due = TextEditingController();
  final _tendered = TextEditingController();

  String get _currency => TerminalConfigRepository.instance.config.currencyCode;

  @override
  void dispose() {
    for (final controller in [_cost, _price, _taxRate, _discountRate, _listPrice, _due, _tendered]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _money(double value) {
    try {
      return NumberFormat.simpleCurrency(name: _currency, decimalDigits: 2).format(value);
    } catch (_) {
      return '${value.toStringAsFixed(2)} $_currency';
    }
  }

  double _num(String value) => double.tryParse(value.replaceAll(',', '.')) ?? 0;

  void _append(String token) {
    if (_justEvaluated && RegExp(r'[0-9.(]').hasMatch(token)) {
      _expression = '';
      _display = '0';
    }
    _justEvaluated = false;
    _expression += token;
    _display = _currentEntry(_expression);
  }

  String _currentEntry(String value) {
    final match = RegExp(r'(-?\d*\.?\d+)$').firstMatch(value);
    final entry = match?.group(1);
    if (entry != null && entry.isNotEmpty) return entry;
    return value.isEmpty ? '0' : value;
  }

  void _clearAll() {
    _expression = '';
    _display = '0';
    _justEvaluated = false;
  }

  void _backspace() {
    if (_expression.isEmpty) return;
    _expression = _expression.substring(0, _expression.length - 1);
    _display = _expression.isEmpty ? '0' : _currentEntry(_expression);
    _justEvaluated = false;
  }

  void _toggleSign() {
    if (_expression.isEmpty || _expression == '0') {
      _expression = '-';
      _display = '-';
      return;
    }
    if (_justEvaluated) {
      _expression = _expression.startsWith('-') ? _expression.substring(1) : '-$_expression';
      _display = _expression;
      return;
    }
    _append('-');
  }

  void _evaluate() {
    if (_expression.isEmpty) return;
    try {
      final value = evaluateExpression(_expression, _angle);
      final formatted = formatCalcNumber(value);
      _display = formatted;
      _expression = formatted;
      _justEvaluated = true;
    } catch (_) {
      _display = 'Erreur';
      _justEvaluated = true;
    }
  }

  void _press(String key) {
    setState(() {
      if (key == 'C') return _clearAll();
      if (key == '⌫') return _backspace();
      if (key == '=') return _evaluate();
      if (key == '±') return _toggleSign();
      if (key == '÷') return _append('/');
      if (key == '×') return _append('*');
      if (key == '−') return _append('-');
      if (key == 'π') return _append('pi');
      if (key == '√') return _append('sqrt(');
      if (key == 'x²') return _append('^2');
      if (key == 'xʸ') return _append('^');
      if (key == 'n!') return _append('!');
      if (key == '1/x') {
        final current = _justEvaluated ? _expression : _currentEntry(_expression);
        final base = current.isNotEmpty && current != '0' ? current : (_expression.isEmpty ? '0' : _expression);
        _expression = '1/($base)';
        return _evaluate();
      }
      if (['sin', 'cos', 'tan', 'log', 'ln'].contains(key)) return _append('$key(');
      _append(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width < 480 ? size.width - 32 : 360.0;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(context),
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Material(
          color: AppColors.surface,
          elevation: 12,
          shadowColor: AppColors.shadow,
          borderRadius: AppRadius.borderXl,
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width, maxHeight: math.min(640, size.height - 40)),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 2),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.logoGold,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: AppColors.logoGold.withValues(alpha: 0.28), blurRadius: 0, spreadRadius: 3),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(tr('Calculatrice'), style: AppTypography.plex(fontSize: 15, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Material(
                          color: AppColors.canvas,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.pop(context),
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: Icon(Icons.close, size: 16, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _tabs(_modes, _mode, (value) => setState(() => _mode = value), const {
                          'standard': 'Standard',
                          'scientific': 'Scientifique',
                          'business': 'Business',
                        }),
                        const SizedBox(height: 8),
                        if (_mode == 'business') _business() else _numeric(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_mode == 'business' || event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _press('=');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _press('⌫');
      return KeyEventResult.handled;
    }
    final label = event.character;
    if (label == null || label.isEmpty) return KeyEventResult.ignored;
    const mapped = {'/': '÷', '*': '×', '-': '−', '+': '+'};
    if (RegExp(r'[0-9.]').hasMatch(label) || label == '%' || label == '(' || label == ')') {
      _press(label);
      return KeyEventResult.handled;
    }
    if (mapped.containsKey(label)) {
      _press(mapped[label]!);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _numeric() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color.alphaBlend(AppColors.logoGold.withValues(alpha: 0.22), AppColors.brand600),
                AppColors.brand600,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tr(_expression.isEmpty ? '0' : _expression),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexMono(fontSize: 12, color: const Color(0x9EFFFFFF)),
              ),
              const SizedBox(height: 4),
              Text(
                tr(_display),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexMono(fontSize: 30, fontWeight: FontWeight.w600, color: AppColors.logoGold, letterSpacing: -0.6),
              ),
              const SizedBox(height: 8),
              Container(height: 1, color: const Color(0x1FFFFFFF)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trf('M {0}', [formatCalcNumber(_memory)]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexMono(fontSize: 11, color: const Color(0xB8FFFFFF)),
                    ),
                  ),
                  _mini('MC', () => setState(() => _memory = 0)),
                  _mini('MR', () => setState(() => _append(formatCalcNumber(_memory)))),
                  _mini('M+', () => setState(() => _memory += double.tryParse(_display) ?? 0)),
                ],
              ),
            ],
          ),
        ),
        if (_mode == 'scientific') ...[
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.7,
            children: [
              _chip(_angle == 'deg' ? 'DEG' : 'RAD', () => setState(() => _angle = _angle == 'deg' ? 'rad' : 'deg'), on: _angle == 'rad'),
              for (final key in _scientificKeys) _chip(key, () => _press(key)),
            ],
          ),
        ],
        const SizedBox(height: 8),
        for (final row in _standardKeys)
          Row(
            children: [
              for (final key in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _KeyButton(label: key, kind: _keyKind(key), onTap: () => _press(key)),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _business() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tabs(_bizTabs, _biz, (value) => setState(() => _biz = value), const {
          'margin': 'Marge',
          'tax': 'Taxe',
          'discount': 'Remise',
          'change': 'Monnaie',
        }),
        const SizedBox(height: 10),
        if (_biz == 'margin') ...[
          _field(_cost, 'Coût'),
          _field(_price, 'Prix de vente'),
          _results([
            ('Marge sur coût', '${_num(_cost.text) > 0 ? ((_num(_price.text) - _num(_cost.text)) / _num(_cost.text) * 100).toStringAsFixed(2) : '0.00'}%'),
            ('Taux de marge', '${_num(_price.text) > 0 ? ((_num(_price.text) - _num(_cost.text)) / _num(_price.text) * 100).toStringAsFixed(2) : '0.00'}%'),
            ('Bénéfice', _money(_num(_price.text) - _num(_cost.text))),
          ], hero: 'Bénéfice'),
        ] else if (_biz == 'tax') ...[
          _field(_cost, 'Montant HT'),
          _field(_taxRate, 'Taux de taxe %'),
          _results([
            ('Taxe', _money(_num(_cost.text) * _num(_taxRate.text) / 100)),
            ('Montant TTC', _money(_num(_cost.text) + _num(_cost.text) * _num(_taxRate.text) / 100)),
          ], hero: 'Montant TTC'),
        ] else if (_biz == 'discount') ...[
          _field(_listPrice, 'Prix'),
          _field(_discountRate, 'Remise %'),
          _results([
            ('Économie', _money(_num(_listPrice.text) * _num(_discountRate.text) / 100)),
            ('Prix remisé', _money(_num(_listPrice.text) - _num(_listPrice.text) * _num(_discountRate.text) / 100)),
          ], hero: 'Prix remisé'),
        ] else ...[
          _field(_due, 'Total dû'),
          _field(_tendered, 'Montant reçu'),
          _results([
            ('Monnaie', _money(_num(_tendered.text) - _num(_due.text))),
          ], hero: 'Monnaie'),
        ],
      ],
    );
  }

  Widget _tabs(List<String> values, String current, ValueChanged<String> onChanged, Map<String, String> labels) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(99)),
      child: Row(
      children: [
        for (final value in values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: InkWell(
                onTap: () => onChanged(value),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: current == value ? AppColors.brand600 : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    tr(labels[value] ?? value),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.plex(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: current == value ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }

  Widget _results(List<(String, String)> rows, {required String hero}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: EdgeInsets.only(top: row.$1 == hero ? 8 : 4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: row.$1 == hero ? Border(top: BorderSide(color: AppColors.border)) : null,
                ),
                child: Padding(
                  padding: EdgeInsets.only(top: row.$1 == hero ? 8 : 0),
                  child: Row(
                    children: [
                      Text(tr(row.$1), style: AppTypography.text(fontSize: 12, color: AppColors.textSecondary)),
                      const Spacer(),
                      Text(
                        tr(row.$2),
                        style: row.$1 == hero
                            ? GoogleFonts.ibmPlexMono(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.brand600)
                            : AppTypography.text(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap, {bool on = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.logoGold.withValues(alpha: 0.22) : AppColors.canvas,
          border: Border.all(color: on ? AppColors.logoGold : AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          tr(label),
          style: AppTypography.text(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.brand600),
        ),
      ),
    );
  }

  Widget _mini(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.logoGold.withValues(alpha: 0.16),
            border: Border.all(color: AppColors.logoGold.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(tr(label), style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.logoGold)),
        ),
      ),
    );
  }

  String _keyKind(String key) {
    if (key == '=') return 'eq';
    if ('÷×−+'.contains(key)) return 'op';
    if (key == 'C') return 'clear';
    return 'plain';
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.label, required this.onTap, required this.kind});

  final String label;
  final VoidCallback onTap;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      'eq' => AppColors.logoGold,
      'op' => AppColors.brand600,
      'clear' => AppColors.dangerBg,
      _ => AppColors.surface,
    };
    final foreground = switch (kind) {
      'eq' => AppColors.brand600,
      'op' => Colors.white,
      'clear' => AppColors.danger,
      _ => AppColors.textPrimary,
    };
    final border = switch (kind) {
      'eq' => AppColors.logoGold,
      'op' => AppColors.brand600,
      'clear' => Colors.transparent,
      _ => AppColors.border,
    };
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              tr(label),
              style: AppTypography.plex(fontSize: kind == 'eq' ? 20 : 16, fontWeight: FontWeight.w700, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

String formatCalcNumber(double value) {
  if (!value.isFinite) return 'Erreur';
  final abs = value.abs();
  if (abs != 0 && (abs >= 1e12 || abs < 1e-9)) return value.toStringAsExponential(6);
  final text = value.toStringAsPrecision(12);
  return double.parse(text).toString();
}

double evaluateExpression(String input, String angle) {
  final normalized = input.trim().replaceAll('×', '*').replaceAll('÷', '/').replaceAll('π', 'pi').replaceAll(',', '.');
  if (normalized.isEmpty) return 0;
  final value = _Parser(normalized, angle).parse();
  if (!value.isFinite) throw const FormatException();
  return value;
}

class _Parser {
  _Parser(this.source, this.angle);

  final String source;
  final String angle;
  int index = 0;

  double parse() {
    final value = _add();
    _skip();
    if (index < source.length) throw const FormatException();
    return value;
  }

  void _skip() {
    while (index < source.length && source[index] == ' ') {
      index++;
    }
  }

  double _add() {
    var left = _mul();
    for (;;) {
      _skip();
      if (index >= source.length || (source[index] != '+' && source[index] != '-')) break;
      final op = source[index++];
      final right = _mul();
      left = op == '+' ? left + right : left - right;
    }
    return left;
  }

  double _mul() {
    var left = _pow();
    for (;;) {
      _skip();
      if (index < source.length && (source[index] == '*' || source[index] == '/')) {
        final op = source[index++];
        final right = _pow();
        left = op == '*' ? left * right : left / right;
        continue;
      }
      if (_implicit()) {
        left *= _pow();
        continue;
      }
      break;
    }
    return left;
  }

  double _pow() {
    final left = _unary();
    _skip();
    if (index >= source.length || source[index] != '^') return left;
    index++;
    return math.pow(left, _pow()).toDouble();
  }

  double _unary() {
    _skip();
    if (index < source.length && source[index] == '+') {
      index++;
      return _unary();
    }
    if (index < source.length && source[index] == '-') {
      index++;
      return -_unary();
    }
    return _postfix();
  }

  double _postfix() {
    var value = _primary();
    for (;;) {
      _skip();
      if (index >= source.length) break;
      if (source[index] == '!') {
        index++;
        value = _factorial(value);
        continue;
      }
      if (source[index] == '%') {
        index++;
        value /= 100;
        continue;
      }
      break;
    }
    return value;
  }

  double _primary() {
    _skip();
    final ident = _peekIdent();
    if (ident.isNotEmpty) {
      const functions = {'sin', 'cos', 'tan', 'log', 'ln', 'sqrt', 'abs'};
      if (functions.contains(ident)) {
        index += ident.length;
        _skip();
        if (index >= source.length || source[index] != '(') throw const FormatException();
        index++;
        final arg = _add();
        _skip();
        if (index >= source.length || source[index] != ')') throw const FormatException();
        index++;
        return _apply(ident, arg);
      }
      if (ident == 'pi') {
        index += 2;
        return math.pi;
      }
      if (ident == 'e' && (index + 1 >= source.length || !_isLetter(source[index + 1]))) {
        index += 1;
        return math.e;
      }
    }
    if (index < source.length && source[index] == '(') {
      index++;
      final value = _add();
      _skip();
      if (index >= source.length || source[index] != ')') throw const FormatException();
      index++;
      return value;
    }
    final start = index;
    if (index < source.length && source[index] == '.') index++;
    while (index < source.length && _isDigit(source[index])) {
      index++;
    }
    if (index < source.length && source[index] == '.') {
      index++;
      while (index < source.length && _isDigit(source[index])) {
        index++;
      }
    }
    if (index == start) throw const FormatException();
    return double.parse(source.substring(start, index));
  }

  double _apply(String name, double value) {
    final radians = angle == 'deg' ? value * math.pi / 180 : value;
    return switch (name) {
      'sin' => math.sin(radians),
      'cos' => math.cos(radians),
      'tan' => math.tan(radians),
      'log' => math.log(value) / math.ln10,
      'ln' => math.log(value),
      'sqrt' => math.sqrt(value),
      'abs' => value.abs(),
      _ => throw const FormatException(),
    };
  }

  String _peekIdent() {
    final match = RegExp(r'^[a-z]+', caseSensitive: false).firstMatch(source.substring(index));
    return match?.group(0)?.toLowerCase() ?? '';
  }

  bool _implicit() {
    if (index >= source.length) return false;
    final ch = source[index];
    if (ch == '(' || _isDigit(ch) || ch == '.') return true;
    final ident = _peekIdent();
    return ident == 'pi' || ident == 'e' || {'sin', 'cos', 'tan', 'log', 'ln', 'sqrt', 'abs'}.contains(ident);
  }

  double _factorial(double value) {
    if (!value.isFinite || value < 0 || value != value.roundToDouble() || value > 170) return double.nan;
    var result = 1.0;
    for (var i = 2; i <= value; i++) {
      result *= i;
    }
    return result;
  }

  bool _isDigit(String char) => char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
  bool _isLetter(String char) {
    final code = char.toLowerCase().codeUnitAt(0);
    return code >= 97 && code <= 122;
  }
}
