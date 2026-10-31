import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

typedef Arb = Map<String, Object?>;

Arb _load(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  return (decoded as Map).cast<String, Object?>();
}

Map<String, String> messages(Arb arb) {
  return <String, String>{
    for (final entry in arb.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value! as String,
  };
}

final RegExp _placeholder = RegExp(r'\{\s*(\w+)\s*(?=[,}])');
final RegExp _branchKinds = RegExp(r'\{\s*\w+\s*,\s*(plural|select)\s*,');
final RegExp _otherBranch = RegExp(r'\bother\s*\{');

Set<String> placeholdersOf(String message) {
  return {for (final m in _placeholder.allMatches(message)) m.group(1)!};
}

bool hasOtherBranch(String message) => _otherBranch.hasMatch(message);

bool isBranching(String message) => _branchKinds.hasMatch(message);

List<String> parityProblems(Arb template, Arb translation) {
  final problems = <String>[];
  final a = messages(template);
  final b = messages(translation);
  for (final key in a.keys.where((k) => !b.containsKey(k))) {
    problems.add('missing in translation: $key');
  }
  for (final key in b.keys.where((k) => !a.containsKey(k))) {
    problems.add('extra in translation: $key');
  }
  for (final key in a.keys.where(b.containsKey)) {
    final left = placeholdersOf(a[key]!);
    final right = placeholdersOf(b[key]!);
    if (left.length != right.length || !left.containsAll(right)) {
      problems.add('placeholders differ: $key $left vs $right');
    }
    if (isBranching(a[key]!) != isBranching(b[key]!)) {
      problems.add('branching differs: $key');
    }
    if (isBranching(b[key]!) && !hasOtherBranch(b[key]!)) {
      problems.add('no other branch: $key');
    }
  }
  for (final entry in b.entries) {
    if (entry.value.trim().isEmpty) {
      problems.add('empty value: ${entry.key}');
    }
  }
  return problems;
}

void main() {
  final ru = _load('lib/l10n/app_ru.arb');
  final en = _load('lib/l10n/app_en.arb');

  group('app_ru.arb and app_en.arb', () {
    test('locale markers are correct', () {
      expect(ru['@@locale'], 'ru');
      expect(en['@@locale'], 'en');
    });

    test('have the same set of keys', () {
      expect(messages(en), isNotEmpty);
      expect(messages(en).keys.toSet(), messages(ru).keys.toSet());
    });

    test('have the same placeholders in every message', () {
      final left = messages(ru);
      final right = messages(en);
      for (final key in left.keys) {
        expect(
          placeholdersOf(right[key]!),
          placeholdersOf(left[key]!),
          reason: key,
        );
      }
    });

    test('every plural or select in en has an other branch', () {
      expect(messages(en).values.where(isBranching), isNotEmpty);
      for (final entry in messages(en).entries) {
        if (isBranching(entry.value)) {
          expect(hasOtherBranch(entry.value), isTrue, reason: entry.key);
        }
      }
    });

    test('branching messages are branching in both', () {
      final left = messages(ru);
      final right = messages(en);
      for (final key in left.keys) {
        expect(isBranching(right[key]!), isBranching(left[key]!), reason: key);
      }
    });

    test('have no empty values', () {
      for (final arb in [ru, en]) {
        for (final entry in messages(arb).entries) {
          expect(entry.value.trim(), isNotEmpty, reason: entry.key);
        }
      }
    });

    test('report no problems overall', () {
      expect(parityProblems(ru, en), isEmpty);
    });
  });

  group('parity check itself', () {
    final base = <String, Object?>{
      '@@locale': 'ru',
      'a': 'Привет, {name}',
      '@a': <String, Object?>{'description': 'x'},
      'b': '{count, plural, one{{count} штука} other{{count} штук}}',
    };
    final good = <String, Object?>{
      '@@locale': 'en',
      'a': 'Hello, {name}',
      'b': '{count, plural, =1{{count} item} other{{count} items}}',
    };

    test('accepts a faithful translation', () {
      expect(parityProblems(base, good), isEmpty);
    });

    test('fails when a key is added to the template only', () {
      final withNewKey = {...base, 'c': 'Новый ключ'};
      expect(
        parityProblems(withNewKey, good),
        contains('missing in translation: c'),
      );
    });

    test('fails when a key is added to the translation only', () {
      final withNewKey = {...good, 'c': 'New key'};
      expect(
        parityProblems(base, withNewKey),
        contains('extra in translation: c'),
      );
    });

    test('fails on differing placeholders', () {
      final broken = {...good, 'a': 'Hello, {user}'};
      expect(parityProblems(base, broken), isNotEmpty);
    });

    test('fails on a plural without other', () {
      final broken = {...good, 'b': '{count, plural, =1{{count} item}}'};
      expect(
        parityProblems(base, broken),
        contains(startsWith('no other branch: b')),
      );
    });

    test('fails on an empty value', () {
      final broken = {...good, 'a': '  '};
      expect(parityProblems(base, broken), isNotEmpty);
    });

    test('ignores metadata keys', () {
      final withMeta = {
        ...good,
        '@b': <String, Object?>{'description': 'y'},
      };
      expect(parityProblems(base, withMeta), isEmpty);
    });

    test('extracts placeholders from nested plural messages', () {
      expect(
        placeholdersOf(
          '{title}, {count, plural, =1{{count} card} other{{count} cards}}',
        ),
        {'title', 'count'},
      );
    });
  });
}
