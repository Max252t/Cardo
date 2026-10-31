import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final Map<String, RegExp> _rules = <String, RegExp>{
  'Locale literal': RegExp(r'''\bLocale\(\s*['"]|languageCode:\s*['"]'''),
  'locale string': RegExp(r'''['"](ru|en)([_-][A-Za-z]{2})?['"]'''),
  'initializeDateFormatting with a locale': RegExp(
    r'''initializeDateFormatting\(\s*['"]''',
  ),
  'DateFormat with a literal locale': RegExp(
    r'''DateFormat\([^)]*,\s*['"][a-z]{2}''',
  ),
  'NumberFormat with a literal locale': RegExp(
    r'''NumberFormat[\w.]*\([^)]*['"](ru|en)''',
  ),
  'Intl.defaultLocale assignment': RegExp(r'Intl\.defaultLocale\s*='),
};

List<String> violations(Iterable<MapEntry<String, String>> sources) {
  final found = <String>[];
  for (final source in sources) {
    final lines = source.value.split('\n');
    for (var i = 0; i < lines.length; i++) {
      for (final rule in _rules.entries) {
        if (rule.value.hasMatch(lines[i])) {
          found.add('${source.key}:${i + 1} [${rule.key}] ${lines[i].trim()}');
        }
      }
    }
  }
  return found;
}

const Set<String> _allowedFiles = <String>{
  'lib/shared/locale/resolve_app_locale.dart',
};

Iterable<MapEntry<String, String>> _libSources() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => MapEntry(file.path.replaceAll(r'\', '/'), file))
      .where((entry) => !entry.key.startsWith('lib/l10n/'))
      .map((entry) => MapEntry(entry.key, entry.value.readAsStringSync()));
}

void main() {
  group('no hardcoded locale in lib outside lib/l10n', () {
    test('scans a non-trivial file set', () {
      expect(_libSources().length, greaterThan(10));
    });

    test('nothing pins a locale', () {
      expect(
        violations(
          _libSources().where((entry) => !_allowedFiles.contains(entry.key)),
        ),
        isEmpty,
      );
    });
  });

  group('locale rules catch what they should', () {
    List<String> check(String line) => violations([MapEntry('x.dart', line)]);

    test('flag hardcoded locales', () {
      expect(check("locale: const Locale('ru'),"), isNotEmpty);
      expect(check('const Locale("en", "US")'), isNotEmpty);
      expect(check("Locale.fromSubtags(languageCode: 'ru')"), isNotEmpty);
      expect(check("final tag = 'ru_RU';"), isNotEmpty);
      expect(check("final tag = 'en-GB';"), isNotEmpty);
      expect(check("initializeDateFormatting('ru');"), isNotEmpty);
      expect(check("DateFormat.yMMMd('ru').format(now)"), isNotEmpty);
      expect(check("DateFormat('d MMM', 'ru')"), isNotEmpty);
      expect(check("NumberFormat.decimalPattern('ru')"), isNotEmpty);
      expect(check("Intl.defaultLocale = 'en';"), isNotEmpty);
    });

    test('allow locale-neutral code', () {
      expect(check('final locale = Localizations.localeOf(context);'), isEmpty);
      expect(check('Locale resolveAppLocale(List<Locale>? device) {'), isEmpty);
      expect(check('DateFormat.yMMMd(locale.toString())'), isEmpty);
      expect(check("final key = 'rule';"), isEmpty);
      expect(check("const id = 'ru-board';"), isEmpty);
      expect(check('initializeDateFormatting(tag);'), isEmpty);
    });
  });
}
