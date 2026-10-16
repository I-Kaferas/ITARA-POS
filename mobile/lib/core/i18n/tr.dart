import 'app_locale.dart';
import 'translations/en.dart';
import 'translations/sw.dart';

/// Screens are written in French; the French text is the lookup key.
const _packs = <String, Map<String, String>>{'en': en, 'sw': sw};

String tr(String fr) {
  final pack = _packs[LocaleController.instance.code];
  if (pack == null) return fr;
  return pack[fr] ?? _trimmed(pack, fr) ?? fr;
}

/// [key] holds `{0}`, `{1}`… where the original text interpolated values.
String trf(String key, List<Object?> args) {
  var text = tr(key);
  for (var i = 0; i < args.length; i++) {
    text = text.replaceAll('{$i}', '${args[i] ?? ''}');
  }
  return text;
}

String? _trimmed(Map<String, String> pack, String fr) {
  final core = fr.trim();
  if (core.isEmpty || core == fr) return null;
  final hit = pack[core];
  if (hit == null) return null;
  final start = fr.indexOf(core);
  return '${fr.substring(0, start)}$hit${fr.substring(start + core.length)}';
}
