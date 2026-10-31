import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _import = RegExp(r'''^\s*(import|export)\s+['"]([^'"]+)['"]''');

const Set<String> pureCoreDirs = <String>{
  'config',
  'result',
  'models',
  'ranking',
  'equality',
  'realtime',
};

const Set<String> infrastructureCoreDirs = <String>{'network'};

typedef Layer = bool Function(String path);
typedef Forbidden = bool Function(String importTarget);

List<String> scan(
  Directory root, {
  required Layer inLayer,
  required Forbidden forbidden,
}) {
  final found = <String>[];
  final prefix = root.path.replaceAll(r'\', '/');
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final normalized = entity.path.replaceAll(r'\', '/');
    final relative = normalized.startsWith('$prefix/')
        ? normalized.substring(prefix.length + 1)
        : normalized;
    if (!inLayer(relative)) {
      continue;
    }
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final match = _import.firstMatch(lines[i]);
      if (match != null && forbidden(match.group(2)!)) {
        found.add('$relative:${i + 1} ${lines[i].trim()}');
      }
    }
  }
  return found;
}

bool isDomain(String path) => RegExp(r'^features/[^/]+/domain/').hasMatch(path);

bool isData(String path) => RegExp(r'^features/[^/]+/data/').hasMatch(path);

bool isPureCore(String path) =>
    RegExp('^core/(${pureCoreDirs.join('|')})/').hasMatch(path);

bool isFlutterUi(String target) =>
    RegExp(r'^package:(flutter|flutter_riverpod|go_router)/')
        .hasMatch(target) ||
    target == 'dart:ui';

bool isAnyPackage(String target) => target.startsWith('package:');

bool reachesPresentationOrData(String target) =>
    target.contains('presentation/') || target.contains('/data/');

bool reachesPresentation(String target) => target.contains('presentation/');

void writeFixture(Directory root, String path, String content) {
  final file = File('${root.path}/$path');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

void main() {
  group('scanner self-tests on synthetic trees', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('cardo_layers_');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test('domain: any package import is caught', () {
      writeFixture(
        root,
        'features/auth/domain/bad.dart',
        "import 'package:dio/dio.dart';\n",
      );
      writeFixture(
        root,
        'features/auth/domain/good.dart',
        "import 'user.dart';\nimport 'dart:async';\n",
      );
      writeFixture(
        root,
        'features/auth/data/ok.dart',
        "import 'package:dio/dio.dart';\n",
      );

      final found = scan(root, inLayer: isDomain, forbidden: isAnyPackage);

      expect(found, hasLength(1));
      expect(found.single, startsWith('features/auth/domain/bad.dart:1'));
    });

    test('domain: export of a package is caught too', () {
      writeFixture(
        root,
        'features/x/domain/e.dart',
        "export 'package:meta/meta.dart';\n",
      );

      expect(
        scan(root, inLayer: isDomain, forbidden: isAnyPackage),
        hasLength(1),
      );
    });

    test('domain: reaching into data or presentation is caught', () {
      writeFixture(
        root,
        'features/x/domain/a.dart',
        "import '../data/x_api.dart';\n",
      );
      writeFixture(
        root,
        'features/x/domain/b.dart',
        "import '../presentation/x.dart';\n",
      );
      writeFixture(root, 'features/x/domain/c.dart', "import 'other.dart';\n");

      final found = scan(
        root,
        inLayer: isDomain,
        forbidden: reachesPresentationOrData,
      );

      expect(found, hasLength(2));
    });

    test('pure core: packages are caught, network is not scanned', () {
      writeFixture(
        root,
        'core/config/c.dart',
        "import 'package:flutter/foundation.dart';\n",
      );
      writeFixture(
        root,
        'core/result/r.dart',
        "import 'package:meta/meta.dart';\n",
      );
      writeFixture(
        root,
        'core/network/n.dart',
        "import 'package:dio/dio.dart';\n",
      );
      writeFixture(root, 'core/ranking/ok.dart', "import 'dart:math';\n");

      final found = scan(root, inLayer: isPureCore, forbidden: isAnyPackage);

      expect(found, hasLength(2));
      expect(found.any((entry) => entry.contains('core/network')), isFalse);
    });

    test('data: Flutter UI, Riverpod, go_router and dart:ui are caught', () {
      writeFixture(
        root,
        'features/a/data/w.dart',
        "import 'package:flutter/widgets.dart';\n",
      );
      writeFixture(
        root,
        'features/a/data/m.dart',
        "import 'package:flutter/material.dart';\n",
      );
      writeFixture(
        root,
        'features/a/data/r.dart',
        "import 'package:flutter_riverpod/flutter_riverpod.dart';\n",
      );
      writeFixture(
        root,
        'features/a/data/g.dart',
        "import 'package:go_router/go_router.dart';\n",
      );
      writeFixture(root, 'features/a/data/u.dart', "import 'dart:ui';\n");

      expect(scan(root, inLayer: isData, forbidden: isFlutterUi), hasLength(5));
    });

    test('data: dio and flutter_secure_storage are allowed', () {
      writeFixture(
        root,
        'features/a/data/d.dart',
        "import 'package:dio/dio.dart';\n",
      );
      writeFixture(
        root,
        'features/a/data/s.dart',
        "import 'package:flutter_secure_storage/flutter_secure_storage.dart';\n",
      );
      writeFixture(root, 'features/a/data/c.dart', "import 'dart:convert';\n");

      expect(scan(root, inLayer: isData, forbidden: isFlutterUi), isEmpty);
    });

    test('data: importing presentation is caught', () {
      writeFixture(
        root,
        'features/a/data/p.dart',
        "import '../presentation/auth_providers.dart';\n",
      );
      writeFixture(
        root,
        'features/a/data/ok.dart',
        "import '../domain/user.dart';\n",
      );

      final found = scan(root, inLayer: isData, forbidden: reachesPresentation);

      expect(found, hasLength(1));
    });

    test('layer predicates classify paths correctly', () {
      expect(isDomain('features/auth/domain/user.dart'), isTrue);
      expect(isDomain('features/auth/data/user.dart'), isFalse);
      expect(isData('features/boards/data/boards_api.dart'), isTrue);
      expect(isData('features/boards/presentation/x.dart'), isFalse);
      expect(isPureCore('core/config/app_config.dart'), isTrue);
      expect(isPureCore('core/result/result.dart'), isTrue);
      expect(isPureCore('core/network/api_call.dart'), isFalse);
      expect(isPureCore('core/config.dart'), isFalse);
    });

    test('a nested import line is matched, a commented one is not', () {
      writeFixture(
        root,
        'features/a/domain/x.dart',
        "// import 'package:dio/dio.dart';\nfinal s = \"import 'package:dio/dio.dart'\";\n",
      );

      expect(scan(root, inLayer: isDomain, forbidden: isAnyPackage), isEmpty);
    });
  });

  group('the real lib tree', () {
    final lib = Directory('lib');

    test('every directory under lib/core is classified', () {
      final dirs = Directory('lib/core')
          .listSync()
          .whereType<Directory>()
          .map((dir) => dir.path.replaceAll(r'\', '/').split('/').last)
          .toSet();

      expect(dirs, pureCoreDirs.union(infrastructureCoreDirs));
    });

    test('the classified sets actually contain files', () {
      for (final name in pureCoreDirs) {
        final files = Directory('lib/core/$name')
            .listSync(recursive: true)
            .whereType<File>();
        expect(files, isNotEmpty, reason: name);
      }
    });

    test('domain layers are plain Dart with no package imports', () {
      expect(scan(lib, inLayer: isDomain, forbidden: isAnyPackage), isEmpty);
    });

    test('pure core is plain Dart with no package imports', () {
      expect(scan(lib, inLayer: isPureCore, forbidden: isAnyPackage), isEmpty);
    });

    test('domain never reaches data or presentation', () {
      expect(
        scan(lib, inLayer: isDomain, forbidden: reachesPresentationOrData),
        isEmpty,
      );
    });

    test('data uses no Flutter UI, Riverpod, go_router or dart:ui', () {
      expect(scan(lib, inLayer: isData, forbidden: isFlutterUi), isEmpty);
    });

    test('data never imports presentation', () {
      expect(
        scan(lib, inLayer: isData, forbidden: reachesPresentation),
        isEmpty,
      );
    });

    test('network core uses no Flutter UI', () {
      expect(
        scan(
          lib,
          inLayer: (path) => path.startsWith('core/network/'),
          forbidden: isFlutterUi,
        ),
        isEmpty,
      );
    });

    test('data directories exist for auth, board and boards', () {
      for (final feature in <String>['auth', 'board', 'boards']) {
        expect(Directory('lib/features/$feature/data').existsSync(), isTrue);
      }
    });
  });
}
