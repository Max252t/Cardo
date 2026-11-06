import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _import = RegExp(r'''^\s*(import|export)\s+['"]([^'"]+)['"]''');

final RegExp _logCall = RegExp(
  r'(^|[^A-Za-z0-9_.])(print|debugPrint)\(|developer\.log\(|stderr\.write|stdout\.write',
);

final RegExp _secretWord = RegExp(
  r'token|bearer|password|secret',
  caseSensitive: false,
);

List<String> importsOf(File file) {
  return [
    for (final line in file.readAsLinesSync())
      if (_import.firstMatch(line) case final match?) match.group(2)!,
  ];
}

List<File> dartFiles(Directory root) {
  return [
    for (final entity in root.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart')) entity,
  ];
}

bool isFlutterUiImport(String target) =>
    RegExp(r'^package:(flutter|flutter_riverpod|go_router)/')
        .hasMatch(target) ||
    target == 'dart:ui';

List<String> offenders(
  Directory root,
  bool Function(String importTarget) forbidden,
) {
  final found = <String>[];
  for (final file in dartFiles(root)) {
    for (final target in importsOf(file)) {
      if (forbidden(target)) {
        found.add('${file.path.replaceAll(r'\', '/')} -> $target');
      }
    }
  }
  return found;
}

List<String> loggedSecrets(Directory root) {
  final found = <String>[];
  for (final file in dartFiles(root)) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.trimLeft().startsWith('//') &&
          _logCall.hasMatch(line) &&
          _secretWord.hasMatch(line)) {
        found.add('${file.path.replaceAll(r'\', '/')}:${i + 1}');
      }
    }
  }
  return found;
}

List<String> loggingCalls(Directory root) {
  final found = <String>[];
  for (final file in dartFiles(root)) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].trimLeft().startsWith('//') &&
          _logCall.hasMatch(lines[i])) {
        found.add('${file.path.replaceAll(r'\', '/')}:${i + 1}');
      }
    }
  }
  return found;
}

List<String> tokenInUri(Directory root) {
  final found = <String>[];
  final query = RegExp(r'''['"][^'"]*[?&](token|access_token|access)=''');
  for (final file in dartFiles(root)) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (query.hasMatch(lines[i])) {
        found.add('${file.path.replaceAll(r'\', '/')}:${i + 1}');
      }
    }
  }
  return found;
}

void write(Directory root, String path, String content) {
  final file = File('${root.path}/$path');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

void main() {
  group('scanner self-tests', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('cardo_rt_'));

    tearDown(() => root.deleteSync(recursive: true));

    test('a Flutter UI import in a pure folder is caught', () {
      write(root, 'a/bad.dart', "import 'package:flutter/widgets.dart';\n");
      write(
        root,
        'a/riverpod.dart',
        "import 'package:flutter_riverpod/flutter_riverpod.dart';\n",
      );
      write(root, 'a/ui.dart', "import 'dart:ui';\n");
      write(
        root,
        'a/ok.dart',
        "import 'dart:async';\nimport 'package:web_socket_channel/io.dart';\n",
      );

      final found = offenders(Directory('${root.path}/a'), isFlutterUiImport);

      expect(found, hasLength(3));
      expect(found.any((entry) => entry.contains('ok.dart')), isFalse);
    });

    test('any package import in a pure folder is caught', () {
      write(root, 'a/bad.dart', "import 'package:dio/dio.dart';\n");
      write(
        root,
        'a/ok.dart',
        "import 'dart:math' as math;\nimport 'x.dart';\n",
      );

      final found = offenders(
        Directory('${root.path}/a'),
        (target) => target.startsWith('package:'),
      );

      expect(found, hasLength(1));
    });

    test('a print that mentions a token is caught', () {
      write(
        root,
        'a/bad.dart',
        "void f(String token) {\n  print('t \$token');\n}\n",
      );
      write(
        root,
        'a/bad2.dart',
        "void f(String t) {\n  debugPrint('Bearer \$t');\n}\n",
      );
      write(root, 'a/ok.dart', "void f() {\n  print('hello');\n}\n");

      final found = loggedSecrets(Directory('${root.path}/a'));

      expect(found, hasLength(2));
      expect(loggingCalls(Directory('${root.path}/a')), hasLength(3));
    });

    test('commented logging and identifiers ending in print are ignored', () {
      write(
        root,
        'a/ok.dart',
        "// print(token)\nvoid f() {\n  blueprint(token);\n  final p = fingerprint(token);\n}\n",
      );

      expect(loggedSecrets(Directory('${root.path}/a')), isEmpty);
      expect(loggingCalls(Directory('${root.path}/a')), isEmpty);
    });

    test('a token in a query string is caught', () {
      write(root, 'a/bad.dart', "final u = 'wss://h/ws?token=\$t';\n");
      write(
        root,
        'a/bad2.dart',
        "final u = 'wss://h/ws?x=1&access_token=\$t';\n",
      );
      write(root, 'a/ok.dart', "final u = 'wss://h/ws/boards/\$id';\n");

      expect(tokenInUri(Directory('${root.path}/a')), hasLength(2));
    });
  });

  group('the real tree', () {
    final lib = Directory('lib');

    test('lib/core/realtime exists, is not empty and is plain Dart', () {
      final dir = Directory('lib/core/realtime');
      final names = dartFiles(dir).map((f) => f.uri.pathSegments.last).toSet();

      expect(
        names,
        containsAll(<String>{
          'realtime_policy.dart',
          'scheduler.dart',
          'reconnect_backoff.dart',
          'connection_status.dart',
        }),
      );
      expect(
        offenders(dir, (target) => target.startsWith('package:')),
        isEmpty,
      );
      expect(offenders(dir, isFlutterUiImport), isEmpty);
    });

    test('the board domain files added for sync are plain Dart', () {
      final domain = Directory('lib/features/board/domain');
      final names = dartFiles(domain).map((f) => f.uri.pathSegments.last);

      expect(
        names,
        containsAll(<String>[
          'board_event.dart',
          'apply_event.dart',
          'seq_ordering.dart',
          'close_policy.dart',
          'op_limits.dart',
          'board_sync_state.dart',
        ]),
      );
      expect(offenders(domain, (t) => t.startsWith('package:')), isEmpty);
      expect(
        offenders(
          domain,
          (t) => t.contains('/data/') || t.contains('presentation/'),
        ),
        isEmpty,
      );
    });

    test('data/realtime exists and has no Flutter UI, Riverpod or dart:ui', () {
      final dir = Directory('lib/features/board/data/realtime');
      final names = dartFiles(dir).map((f) => f.uri.pathSegments.last).toSet();

      expect(
        names,
        containsAll(<String>{
          'board_sync_engine.dart',
          'message_codec.dart',
          'event_codec.dart',
          'protocol_issue.dart',
          'realtime_transport.dart',
          'realtime_credentials.dart',
          'board_catch_up.dart',
        }),
      );
      expect(offenders(dir, isFlutterUiImport), isEmpty);
    });

    test('data/realtime only reaches the allowed packages', () {
      final dir = Directory('lib/features/board/data/realtime');
      const allowed = <String>['package:web_socket_channel/'];

      final found = offenders(
        dir,
        (target) =>
            target.startsWith('package:') && !allowed.any(target.startsWith),
      );

      expect(found, isEmpty);
    });

    test('the fake server and the gateways have no Flutter UI either', () {
      final data = Directory('lib/features/board/data');

      expect(offenders(data, isFlutterUiImport), isEmpty);
      expect(
        offenders(data, (target) => target.contains('presentation/')),
        isEmpty,
      );
    });

    test('data/realtime never imports presentation', () {
      expect(
        offenders(
          Directory('lib/features/board/data/realtime'),
          (target) => target.contains('presentation/'),
        ),
        isEmpty,
      );
    });

    test('no token or credential reaches a log call anywhere in lib', () {
      expect(loggedSecrets(lib), isEmpty);
    });

    test('there are no print or debugPrint calls in lib at all', () {
      expect(loggingCalls(lib), isEmpty);
    });

    test('no URI string carries a token in its query', () {
      expect(tokenInUri(lib), isEmpty);
    });

    test('the Bearer header is built in exactly the expected places', () {
      final holders = <String>[
        for (final file in dartFiles(lib))
          if (file.readAsStringSync().contains('Bearer '))
            file.path.replaceAll(r'\', '/'),
      ]..sort();

      expect(holders, <String>[
        'lib/features/auth/data/auth_interceptor.dart',
        'lib/features/board/data/fake/fake_board_server.dart',
        'lib/features/board/data/realtime/board_sync_engine.dart',
      ]);
    });
  });
}
