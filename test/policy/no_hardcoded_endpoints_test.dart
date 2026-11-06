import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _libFiles() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (file) => file.path.endsWith('.dart') || file.path.endsWith('.arb'),
      )
      .toList();
}

List<String> _violations(
  Iterable<File> files,
  Map<String, RegExp> rules, {
  bool Function(String path)? skip,
}) {
  final found = <String>[];
  for (final file in files) {
    final normalized = file.path.replaceAll(r'\', '/');
    if (skip != null && skip(normalized)) {
      continue;
    }
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      for (final rule in rules.entries) {
        if (rule.value.hasMatch(lines[i])) {
          found.add('$normalized:${i + 1} [${rule.key}] ${lines[i].trim()}');
        }
      }
    }
  }
  return found;
}

void main() {
  group('lib contains no hardcoded addresses', () {
    final rules = <String, RegExp>{
      'localhost': RegExp(r'localhost', caseSensitive: false),
      'android emulator host': RegExp(r'10\.0\.2\.2'),
      'loopback': RegExp(r'127\.0\.0\.1'),
      'ipv6 loopback': RegExp(r'\[::1\]'),
      'http url': RegExp(r'http://', caseSensitive: false),
      'https url': RegExp(r'https://', caseSensitive: false),
      'ws url': RegExp(r'\bwss?://', caseSensitive: false),
    };

    test('rules detect addresses', () {
      expect(
        rules['localhost']!.hasMatch("const h = 'localhost:8080';"),
        isTrue,
      );
      expect(rules['localhost']!.hasMatch("const h = 'LOCALHOST';"), isTrue);
      expect(
        rules['android emulator host']!.hasMatch("'http://10.0.2.2:8080'"),
        isTrue,
      );
      expect(rules['loopback']!.hasMatch("Uri.parse('127.0.0.1')"), isTrue);
      expect(rules['ipv6 loopback']!.hasMatch("'http://[::1]:8080'"), isTrue);
      expect(rules['http url']!.hasMatch("'http://api.example'"), isTrue);
      expect(rules['https url']!.hasMatch("'HTTPS://api.example'"), isTrue);
      expect(rules['ws url']!.hasMatch("'wss://api.example'"), isTrue);
    });

    test('rules ignore ordinary code', () {
      for (final rule in rules.values) {
        expect(
          rule.hasMatch("final scheme = base.scheme == 'https';"),
          isFalse,
        );
        expect(rule.hasMatch("'/api/boards'"), isFalse);
        expect(rule.hasMatch("return base.replace(scheme: 'ws');"), isFalse);
        expect(rule.hasMatch('Future<Dialog> showDialog(context);'), isFalse);
      }
    });

    test('the scan covers dart sources and ARB files', () {
      final paths = _libFiles()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .toList();

      expect(paths, contains('lib/main.dart'));
      expect(paths, contains('lib/core/config/app_config.dart'));
      expect(paths, contains('lib/l10n/app_en.arb'));
      expect(paths, contains('lib/l10n/app_ru.arb'));
      expect(paths, contains('lib/l10n/app_localizations_en.dart'));
    });

    test('no source, ARB text or generated localization holds an address', () {
      expect(_violations(_libFiles(), rules), isEmpty);
    });
  });

  group('lib does not log', () {
    final rules = <String, RegExp>{
      'print': RegExp(r'\bprint\('),
      'debugPrint': RegExp(r'\bdebugPrint\('),
      'developer': RegExp(r'''['"]dart:developer['"]'''),
      'developer.log': RegExp(r'\bdeveloper\.log\('),
      'log call': RegExp(r'(?<![\w.])log\('),
      'LogInterceptor': RegExp(r'\bLogInterceptor\b'),
      'stdout': RegExp(r'\b(stdout|stderr)\b'),
    };

    test('rules detect logging', () {
      expect(rules['print']!.hasMatch("print('x');"), isTrue);
      expect(rules['debugPrint']!.hasMatch("debugPrint('x');"), isTrue);
      expect(rules['developer']!.hasMatch("import 'dart:developer';"), isTrue);
      expect(rules['developer.log']!.hasMatch("developer.log('x');"), isTrue);
      expect(rules['log call']!.hasMatch("log('x');"), isTrue);
      expect(
        rules['LogInterceptor']!.hasMatch(
          'dio.interceptors.add(LogInterceptor());',
        ),
        isTrue,
      );
      expect(rules['stdout']!.hasMatch("stdout.writeln('x');"), isTrue);
    });

    test('rules ignore look-alikes', () {
      expect(rules['print']!.hasMatch('final blueprint = 1;'), isFalse);
      expect(rules['log call']!.hasMatch('showDialog(context);'), isFalse);
      expect(rules['log call']!.hasMatch('final AlertDialog(x);'), isFalse);
      expect(rules['log call']!.hasMatch('Navigator.log(x)'), isFalse);
    });

    test('lib sources never log', () {
      final files = _libFiles().where((f) => f.path.endsWith('.dart'));
      expect(
        _violations(files, rules, skip: (path) => path.startsWith('lib/l10n/')),
        isEmpty,
      );
    });
  });

  group('env template', () {
    test(
      'env/example.json declares an empty API_BASE_URL and nothing else',
      () {
        final raw = File('env/example.json').readAsStringSync();
        final json = jsonDecode(raw) as Map<String, dynamic>;

        expect(json.keys, <String>['API_BASE_URL']);
        expect(json['API_BASE_URL'], '');
      },
    );

    test('.gitignore keeps local env files out and the template in', () {
      final lines = File('.gitignore')
          .readAsLinesSync()
          .map((line) => line.trim())
          .toList();

      expect(lines, contains('env/*.json'));
      expect(lines, contains('!env/example.json'));
      expect(
        lines.indexOf('!env/example.json'),
        greaterThan(lines.indexOf('env/*.json')),
      );
    });

    test('the dart-define key used in code matches the template', () {
      final config = File('lib/core/config/app_config.dart').readAsStringSync();

      expect(config, contains("'API_BASE_URL'"));
    });
  });
}
