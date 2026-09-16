import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../config/terminal_config_repository.dart';
import '../theme/app_colors.dart';

class AppCalculator {
  AppCalculator._();

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Calculatrice',
      barrierColor: const Color(0x140F172A),
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
      message: 'Calculatrice',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: () => AppCalculator.show(context),
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(Icons.calculate_outlined, size: 16, color: AppColors.brand700),
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
          elevation: 16,
          shadowColor: const Color(0x29101828),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width, maxHeight: math.min(640, size.height - 40)),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF7F9FB),
                      border: Border(top: BorderSide(color: AppColors.brand600, width: 3)),
                    ),
                    child: Row(
                      children: [
                        Text('Calculatrice', style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 18),
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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_expression.isEmpty ? '0' : _expression, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppColors.textMuted)),
              Text(_display, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.ibmPlexMono(fontSize: 22, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        if (_mode == 'scientific') ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(_angle == 'deg' ? 'DEG' : 'RAD', () => setState(() => _angle = _angle == 'deg' ? 'rad' : 'deg')),
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
        const SizedBox(height: 6),
        Row(
          children: [
            Text('M ${formatCalcNumber(_memory)}', style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppColors.textSecondary)),
            const Spacer(),
            _mini('MC', () => setState(() => _memory = 0)),
            _mini('MR', () => setState(() => _append(formatCalcNumber(_memory)))),
            _mini('M+', () => setState(() => _memory += double.tryParse(_display) ?? 0)),
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
          _result('Bénéfice', _money(_num(_price.text) - _num(_cost.text))),
          _result('Marge sur coût', '${_num(_cost.text) > 0 ? ((_num(_price.text) - _num(_cost.text)) / _num(_cost.text) * 100).toStringAsFixed(2) : '0.00'}%'),
          _result('Taux de marge', '${_num(_price.text) > 0 ? ((_num(_price.text) - _num(_cost.text)) / _num(_price.text) * 100).toStringAsFixed(2) : '0.00'}%'),
        ] else if (_biz == 'tax') ...[
          _field(_cost, 'Montant HT'),
          _field(_taxRate, 'Taux de taxe %'),
          _result('Taxe', _money(_num(_cost.text) * _num(_taxRate.text) / 100)),
          _result('Montant TTC', _money(_num(_cost.text) + _num(_cost.text) * _num(_taxRate.text) / 100)),
        ] else if (_biz == 'discount') ...[
          _field(_listPrice, 'Prix'),
          _field(_discountRate, 'Remise %'),
          _result('Économie', _money(_num(_listPrice.text) * _num(_discountRate.text) / 100)),
          _result('Prix remisé', _money(_num(_listPrice.text) - _num(_listPrice.text) * _num(_discountRate.text) / 100)),
        ] else ...[
          _field(_due, 'Total dû'),
          _field(_tendered, 'Montant reçu'),
          _result('Monnaie', _money(_num(_tendered.text) - _num(_due.text))),
        ],
      ],
    );
  }

  Widget _tabs(List<String> values, String current, ValueChanged<String> onChanged, Map<String, String> labels) {
    return Row(
      children: [
        for (final value in values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => onChanged(value),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: current == value ? AppColors.brand50 : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: current == value ? AppColors.brand200 : Colors.transparent),
                  ),
                  child: Text(
                    labels[value] ?? value,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w600, color: current == value ? AppColors.brand700 : AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
      ],
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

  Widget _result(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _mini(String label, VoidCallback onTap) {
    return TextButton(onPressed: onTap, child: Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700)));
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
      'eq' => AppColors.brand600,
      'op' => AppColors.brand50,
      'clear' => AppColors.dangerBg,
      _ => AppColors.fieldFill,
    };
    final foreground = kind == 'eq' ? Colors.white : (kind == 'clear' ? AppColors.danger : AppColors.textPrimary);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 40,
          child: Center(child: Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w600, color: foreground))),
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
