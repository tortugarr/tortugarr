import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/util/locale_english_names.dart';

void main() {
  test('native name gets the English name in brackets', () {
    expect(bilingualLocaleLabel('nb', 'Norsk bokmål'), 'Norsk bokmål (Norwegian)');
    expect(bilingualLocaleLabel('tr', 'Türkçe'), 'Türkçe (Turkish)');
  });

  test('English stays plain', () {
    expect(bilingualLocaleLabel('en', 'English'), 'English');
  });

  test('system default always carries the English words', () {
    expect(bilingualSystemDefaultLabel('System default'), 'System default');
    expect(bilingualSystemDefaultLabel('Systemstandard'), 'Systemstandard (System default)');
  });

  test('every shipped locale has an English name', () {
    for (final Locale l in AppLocalizations.supportedLocales) {
      expect(kLocaleEnglishNames.containsKey(l.toLanguageTag()), isTrue,
          reason: l.toLanguageTag());
    }
  });
}
