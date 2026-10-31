import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _dartFiles({required List<String> excluded}) {
  final root = Directory('lib');
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) {
        final normalized = file.path.replaceAll(r'\', '/');
        return !excluded.any((dir) => normalized.startsWith(dir));
      })
      .toList();
}

List<File> _dartFilesIn(List<String> included) {
  return _dartFiles(excluded: const <String>[]).where((file) {
    final normalized = file.path.replaceAll(r'\', '/');
    return included.any((dir) => normalized.startsWith(dir));
  }).toList();
}

List<String> _violations(List<File> files, Map<String, RegExp> rules) {
  final found = <String>[];
  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      for (final rule in rules.entries) {
        if (rule.value.hasMatch(lines[i])) {
          found.add('${file.path}:${i + 1} [${rule.key}] ${lines[i].trim()}');
        }
      }
    }
  }
  return found;
}

void main() {
  group('lib sources exist', () {
    test('policy scans a non-trivial file set', () {
      expect(_dartFiles(excluded: const <String>[]).length, greaterThan(10));
      expect(
        _dartFiles(excluded: const <String>['lib/theme/', 'lib/l10n/']),
        isNotEmpty,
      );
    });
  });

  group('no raw design values outside lib/theme', () {
    final rules = <String, RegExp>{
      'Color(0x': RegExp(r'Color\(0x'),
      'Colors.*': RegExp(r'\bColors\.(?!transparent)'),
      'fontSize number': RegExp(r'fontSize:\s*\d'),
      'BorderRadius.circular number': RegExp(r'BorderRadius\.circular\(\s*\d'),
      'Duration literal': RegExp(r'Duration\(\s*(milliseconds|seconds):'),
      'Curves': RegExp(r'Curves\.'),
    };

    test('rules detect violations', () {
      expect(rules['Color(0x']!.hasMatch('const Color(0xFF000000)'), isTrue);
      expect(rules['Colors.*']!.hasMatch('color: Colors.red'), isTrue);
      expect(rules['Colors.*']!.hasMatch('color: Colors.transparent'), isFalse);
      expect(rules['fontSize number']!.hasMatch('fontSize: 14'), isTrue);
      expect(rules['fontSize number']!.hasMatch('fontSize: size'), isFalse);
      expect(
        rules['BorderRadius.circular number']!.hasMatch(
          'BorderRadius.circular(8)',
        ),
        isTrue,
      );
      expect(
        rules['BorderRadius.circular number']!.hasMatch(
          'BorderRadius.circular(radius)',
        ),
        isFalse,
      );
      expect(
        rules['Duration literal']!.hasMatch('Duration(milliseconds: 5)'),
        isTrue,
      );
      expect(rules['Curves']!.hasMatch('curve: Curves.easeIn'), isTrue);
    });

    test('lib outside theme and l10n is clean', () {
      final files = _dartFiles(
        excluded: const <String>['lib/theme/', 'lib/l10n/'],
      );
      expect(_violations(files, rules), isEmpty);
    });
  });

  group('directional geometry outside lib/theme', () {
    final rules = <String, RegExp>{
      'EdgeInsets': RegExp(r'\bEdgeInsets\.(?!zero\b)'),
      'Alignment': RegExp(r'\bAlignment\.'),
      'Positioned': RegExp(r'\bPositioned\('),
    };

    test('rules detect non-directional geometry', () {
      expect(rules['EdgeInsets']!.hasMatch('EdgeInsets.all(8)'), isTrue);
      expect(rules['EdgeInsets']!.hasMatch('EdgeInsets.only(left: 4)'), isTrue);
      expect(rules['EdgeInsets']!.hasMatch('EdgeInsets.zero'), isFalse);
      expect(
        rules['EdgeInsets']!.hasMatch('EdgeInsetsDirectional.all(8)'),
        isFalse,
      );
      expect(rules['Alignment']!.hasMatch('Alignment.centerLeft'), isTrue);
      expect(
        rules['Alignment']!.hasMatch('AlignmentDirectional.topEnd'),
        isFalse,
      );
      expect(rules['Alignment']!.hasMatch('CrossAxisAlignment.start'), isFalse);
      expect(
        rules['Alignment']!.hasMatch('WrapCrossAlignment.center'),
        isFalse,
      );
      expect(rules['Positioned']!.hasMatch('Positioned(left: 0)'), isTrue);
      expect(
        rules['Positioned']!.hasMatch('PositionedDirectional(start: 0)'),
        isFalse,
      );
    });

    test('lib outside theme and l10n uses directional geometry', () {
      final files = _dartFiles(
        excluded: const <String>['lib/theme/', 'lib/l10n/'],
      );
      expect(_violations(files, rules), isEmpty);
    });
  });

  group('lower layers do not import features', () {
    final rules = <String, RegExp>{
      'features import': RegExp(
        r'''^\s*(import|export)\s+['"][^'"]*features/''',
      ),
    };

    test('rule detects features imports', () {
      final rule = rules['features import']!;
      expect(rule.hasMatch("import '../../features/board/x.dart';"), isTrue);
      expect(
        rule.hasMatch("import 'package:cardo/features/board/x.dart';"),
        isTrue,
      );
      expect(rule.hasMatch("export '../features/x.dart';"), isTrue);
      expect(rule.hasMatch("import '../../theme/cardo_theme.dart';"), isFalse);
      expect(rule.hasMatch("final path = 'features/x';"), isFalse);
    });

    test('shared, core and theme never import features', () {
      final files = _dartFilesIn(const <String>[
        'lib/shared/',
        'lib/core/',
        'lib/theme/',
      ]);
      expect(files, isNotEmpty);
      expect(_violations(files, rules), isEmpty);
    });
  });

  group('feature data and domain do not import theme', () {
    final rules = <String, RegExp>{
      'theme import': RegExp(r'''^\s*(import|export)\s+['"][^'"]*theme/'''),
    };

    test('rule detects theme imports', () {
      final rule = rules['theme import']!;
      expect(
        rule.hasMatch("import '../../../theme/cardo_theme.dart';"),
        isTrue,
      );
      expect(
        rule.hasMatch("import 'package:cardo/theme/cardo_durations.dart';"),
        isTrue,
      );
      expect(rule.hasMatch("import '../domain/board_model.dart';"), isFalse);
    });

    test('lib/features/*/data and */domain never import theme', () {
      final files = _dartFiles(excluded: const <String>[]).where((file) {
        final normalized = file.path.replaceAll(r'\', '/');
        return RegExp(r'^lib/features/[^/]+/(data|domain)/')
            .hasMatch(normalized);
      }).toList();
      expect(files, isNotEmpty);
      expect(_violations(files, rules), isEmpty);
    });
  });

  group('pure layers do not import Flutter', () {
    final rules = <String, RegExp>{
      'flutter import': RegExp(
        r'''^\s*(import|export)\s+['"]package:(flutter|flutter_riverpod)(/|['"])''',
      ),
      'dart:ui import': RegExp(r'''^\s*(import|export)\s+['"]dart:ui['"]'''),
    };

    test('rules detect Flutter imports', () {
      final flutter = rules['flutter import']!;
      expect(
        flutter.hasMatch("import 'package:flutter/foundation.dart';"),
        isTrue,
      );
      expect(
        flutter.hasMatch("import 'package:flutter/material.dart';"),
        isTrue,
      );
      expect(
        flutter.hasMatch(
          "import 'package:flutter_riverpod/flutter_riverpod.dart';",
        ),
        isTrue,
      );
      expect(
        flutter.hasMatch("export 'package:flutter/widgets.dart';"),
        isTrue,
      );
      expect(
        flutter.hasMatch("import 'package:flutter_test/flutter_test.dart';"),
        isFalse,
      );
      expect(flutter.hasMatch("import 'dart:async';"), isFalse);
      expect(flutter.hasMatch("import '../domain/board_model.dart';"), isFalse);
      expect(rules['dart:ui import']!.hasMatch("import 'dart:ui';"), isTrue);
      expect(rules['dart:ui import']!.hasMatch("import 'dart:io';"), isFalse);
    });

    test('lib/features/*/domain, */data and lib/core never import Flutter', () {
      final files = _dartFiles(excluded: const <String>[]).where((file) {
        final normalized = file.path.replaceAll(r'\', '/');
        return RegExp(r'^lib/features/[^/]+/(data|domain)/')
                .hasMatch(normalized) ||
            normalized.startsWith('lib/core/');
      }).toList();
      expect(files, isNotEmpty);
      expect(_violations(files, rules), isEmpty);
    });
  });

  group('no comments in lib', () {
    final rules = <String, RegExp>{
      'line comment': RegExp(r'^\s*//'),
      'trailing comment': RegExp(r'''^[^'"]*\s//'''),
      'block comment': RegExp(r'/\*'),
    };

    test('rules detect comments', () {
      expect(rules['line comment']!.hasMatch('  // note'), isTrue);
      expect(rules['line comment']!.hasMatch('  /// doc'), isTrue);
      expect(
        rules['trailing comment']!.hasMatch('final a = 1; // note'),
        isTrue,
      );
      expect(rules['block comment']!.hasMatch('/* note */'), isTrue);
      expect(
        rules['line comment']!.hasMatch("final u = 'https://x';"),
        isFalse,
      );
      expect(
        rules['trailing comment']!.hasMatch("final u = 'https://x';"),
        isFalse,
      );
    });

    test('lib outside l10n has no comments', () {
      final files = _dartFiles(excluded: const <String>['lib/l10n/']);
      expect(_violations(files, rules), isEmpty);
    });
  });
}
