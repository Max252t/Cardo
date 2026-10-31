import 'package:cardo/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.parse invalid input', () {
    final invalid = <String, String>{
      'empty': '',
      'blank': '   ',
      'no scheme': 'api.test',
      'host and port without scheme': 'localhost:8080',
      'relative path': '/api',
      'ftp': 'ftp://api.test',
      'ws': 'ws://api.test',
      'file': 'file:///tmp/x',
      'no host': 'http://',
      'no host with port': 'http://:8080',
      'query': 'http://api.test?x=1',
      'query after path': 'http://api.test/v1?x=1',
      'empty query': 'http://api.test?',
      'fragment': 'http://api.test#top',
      'userinfo': 'http://user@api.test',
      'userinfo with password': 'https://user:pw@api.test',
    };

    for (final entry in invalid.entries) {
      test(entry.key, () {
        final config = AppConfig.parse(entry.value);

        expect(config.isValid, isFalse, reason: entry.value);
        expect(config.apiBaseUri, isNull);
        expect(config.wsBaseUri, isNull);
        expect(config.rawValue, entry.value.trim());
      });
    }
  });

  group('AppConfig.parse valid input', () {
    test('http host', () {
      final config = AppConfig.parse('http://api.test');

      expect(config.isValid, isTrue);
      expect(config.apiBaseUri, Uri.parse('http://api.test'));
    });

    test('https host', () {
      expect(AppConfig.parse('https://api.test').isValid, isTrue);
    });

    test('the port is preserved', () {
      final config = AppConfig.parse('http://localhost:8080');

      expect(config.apiBaseUri?.port, 8080);
      expect(config.apiBaseUri.toString(), 'http://localhost:8080');
    });

    test('ip hosts are accepted', () {
      expect(AppConfig.parse('http://10.0.2.2:8080').isValid, isTrue);
      expect(AppConfig.parse('http://127.0.0.1:8080').isValid, isTrue);
      expect(AppConfig.parse('http://[::1]:8080').isValid, isTrue);
    });

    test('a path prefix is kept', () {
      final config = AppConfig.parse('https://api.test/cardo');

      expect(config.apiBaseUri?.path, '/cardo');
    });

    test('a trailing slash is accepted and kept', () {
      final config = AppConfig.parse('https://api.test/');

      expect(config.isValid, isTrue);
      expect(config.apiBaseUri?.path, '/');
    });

    test('surrounding whitespace is trimmed', () {
      final config = AppConfig.parse('  http://api.test:9000 \n');

      expect(config.isValid, isTrue);
      expect(config.rawValue, 'http://api.test:9000');
    });

    test('the scheme is case-insensitive', () {
      expect(AppConfig.parse('HTTP://api.test').apiBaseUri?.scheme, 'http');
      expect(AppConfig.parse('HTTPS://api.test').apiBaseUri?.scheme, 'https');
    });
  });

  group('wsBaseUri', () {
    test('http becomes ws', () {
      expect(
        AppConfig.parse('http://api.test:8080').wsBaseUri,
        Uri.parse('ws://api.test:8080'),
      );
    });

    test('https becomes wss', () {
      expect(
        AppConfig.parse('https://api.test').wsBaseUri,
        Uri.parse('wss://api.test'),
      );
    });

    test('host, port and path are preserved', () {
      final ws = AppConfig.parse('https://api.test:8443/cardo').wsBaseUri;

      expect(ws?.scheme, 'wss');
      expect(ws?.host, 'api.test');
      expect(ws?.port, 8443);
      expect(ws?.path, '/cardo');
    });
  });

  group('identity', () {
    test('equality is by raw value', () {
      expect(
        AppConfig.parse('http://a.test'),
        AppConfig.parse(' http://a.test '),
      );
      expect(
        AppConfig.parse('http://a.test').hashCode,
        AppConfig.parse('http://a.test').hashCode,
      );
      expect(
        AppConfig.parse('http://a.test') == AppConfig.parse('http://b.test'),
        isFalse,
      );
    });

    test('the dart-define key is API_BASE_URL', () {
      expect(AppConfig.apiBaseUrlKey, 'API_BASE_URL');
    });

    test('fromEnvironment agrees with parse of its own raw value', () {
      final config = AppConfig.fromEnvironment();

      expect(config, AppConfig.parse(config.rawValue));
      expect(config.isValid, AppConfig.parse(config.rawValue).isValid);
    });
  });
}
