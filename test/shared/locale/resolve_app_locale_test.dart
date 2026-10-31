import 'dart:ui';

import 'package:cardo/l10n/app_localizations.dart';
import 'package:cardo/shared/locale/resolve_app_locale.dart';
import 'package:flutter_test/flutter_test.dart';

const Locale _en = Locale('en');
const Locale _ru = Locale('ru');
const List<Locale> _both = <Locale>[_en, _ru];

void main() {
  group('resolveAppLocale', () {
    test('fallback is English', () {
      expect(fallbackAppLocale, _en);
    });

    test('Russian system locales give ru', () {
      expect(resolveAppLocale(const [Locale('ru')], _both), _ru);
      expect(resolveAppLocale(const [Locale('ru', 'RU')], _both), _ru);
      expect(resolveAppLocale(const [Locale('ru', 'UA')], _both), _ru);
    });

    test('English system locales give en', () {
      expect(resolveAppLocale(const [Locale('en', 'US')], _both), _en);
      expect(resolveAppLocale(const [Locale('en', 'GB')], _both), _en);
      expect(resolveAppLocale(const [Locale('en')], _both), _en);
    });

    test('unsupported languages fall back to English', () {
      expect(resolveAppLocale(const [Locale('de')], _both), _en);
      expect(
        resolveAppLocale(const [
          Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
            countryCode: 'CN',
          ),
        ], _both),
        _en,
      );
    });

    test('the first matching locale in the device order wins', () {
      expect(resolveAppLocale(const [Locale('de'), _ru], _both), _ru);
      expect(resolveAppLocale(const [_en, _ru], _both), _en);
      expect(resolveAppLocale(const [_ru, _en], _both), _ru);
      expect(
        resolveAppLocale(const [Locale('de'), Locale('fr'), _ru], _both),
        _ru,
      );
    });

    test('an exact script and country match beats a language match', () {
      const hans = Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
        countryCode: 'CN',
      );
      const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
      const bare = Locale('zh');
      const supported = <Locale>[_en, bare, hans, hant];
      expect(resolveAppLocale(const [hans], supported), hans);
      expect(resolveAppLocale(const [hant], supported), hant);
      expect(resolveAppLocale(const [Locale('zh', 'TW')], supported), bare);
    });

    test('an exact country match beats a bare language', () {
      const british = Locale('en', 'GB');
      const supported = <Locale>[_en, british];
      expect(resolveAppLocale(const [british], supported), british);
      expect(resolveAppLocale(const [Locale('en', 'US')], supported), _en);
    });

    test('null and empty device lists give English', () {
      expect(resolveAppLocale(null, _both), _en);
      expect(resolveAppLocale(const <Locale>[], _both), _en);
    });

    test('without English the first supported locale is used', () {
      const french = Locale('fr');
      expect(resolveAppLocale(const [Locale('de')], const [_ru]), _ru);
      expect(resolveAppLocale(null, const [french, _ru]), french);
      expect(resolveAppLocale(const [_ru], const [french, _ru]), _ru);
    });

    test('an empty supported list gives English', () {
      expect(resolveAppLocale(const [_ru], const <Locale>[]), _en);
      expect(resolveAppLocale(null, const <Locale>[]), _en);
    });

    test('works with the real supported locales', () {
      const supported = AppLocalizations.supportedLocales;
      expect(resolveAppLocale(const [Locale('ru', 'RU')], supported), _ru);
      expect(resolveAppLocale(const [Locale('ja')], supported), _en);
    });

    test('accepts any iterable of supported locales', () {
      expect(resolveAppLocale(const [_ru], {_en, _ru}), _ru);
      expect(resolveAppLocale(const [_ru], _both.map((l) => l)), _ru);
    });
  });
}
