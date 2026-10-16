import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/core/i18n/app_locale.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

void main() {
  tearDown(() => LocaleController.instance.bind('fr'));

  test('French returns the source text', () {
    LocaleController.instance.bind('fr');
    expect(tr('Accueil'), 'Accueil');
    expect(trf('Chambre {0} · {1}', ['12', 'Jean']), 'Chambre 12 · Jean');
  });

  test('English and Kiswahili translate Accueil', () {
    LocaleController.instance.bind('en');
    expect(tr('Accueil'), 'Home');
    LocaleController.instance.bind('sw');
    expect(tr('Accueil'), 'Mwanzo');
  });

  test('trf keeps placeholders', () {
    LocaleController.instance.bind('en');
    expect(trf('Chambre {0} · {1}', ['7', 'Amina']), 'Room 7 · Amina');
  });
}
