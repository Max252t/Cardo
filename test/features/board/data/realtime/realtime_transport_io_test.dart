import 'dart:async';
import 'dart:io';

import 'package:cardo/features/board/data/realtime/realtime_transport.dart';
import 'package:cardo/features/board/data/realtime/realtime_transport_io.dart';
import 'package:flutter_test/flutter_test.dart';

Future<HttpServer> _serve(void Function(HttpRequest request) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  addTearDown(() => server.close(force: true));
  return server;
}

Uri _uri(HttpServer server) =>
    Uri(scheme: 'ws', host: '127.0.0.1', port: server.port, path: '/ws');

void main() {
  group('upgrade refusal over a real loopback socket', () {
    for (final status in <int>[401, 403, 404, 503]) {
      test('HTTP $status becomes RealtimeUpgradeRejected($status)', () async {
        final server = await _serve((request) {
          request.response
            ..statusCode = status
            ..write('{}');
          unawaited(request.response.close());
        });

        await expectLater(
          const IoRealtimeTransport().connect(
            _uri(server),
            headers: const <String, String>{'Authorization': 'Bearer t'},
          ),
          throwsA(
            isA<RealtimeUpgradeRejected>().having(
              (error) => error.status,
              'status',
              status,
            ),
          ),
        );
      });
    }

    test('a closed port stays a plain connection error', () async {
      final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final uri = _uri(probe);
      await probe.close(force: true);

      await expectLater(
        const IoRealtimeTransport().connect(
          uri,
          headers: const <String, String>{},
        ),
        throwsA(isNot(isA<RealtimeUpgradeRejected>())),
      );
    });
  });

  group('an accepted upgrade', () {
    test('delivers text frames and the Authorization header', () async {
      String? seen;
      final server = await _serve((request) async {
        seen = request.headers.value(HttpHeaders.authorizationHeader);
        final socket = await WebSocketTransformer.upgrade(request);
        socket.add('hello');
        unawaited(socket.close(4003, 'gone'));
      });

      final channel = await const IoRealtimeTransport().connect(
        _uri(server),
        headers: const <String, String>{'Authorization': 'Bearer secret'},
      );
      final frames = await channel.messages.toList();

      expect(frames, ['hello']);
      expect(seen, 'Bearer secret');
      expect(channel.closeCode, 4003);
    });
  });

  group('dead peer detection', () {
    test('a peer that never answers pings ends the stream', () async {
      final server = await _serve((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((_) {}).pause();
      });

      final channel = await const IoRealtimeTransport(
        pingInterval: Duration(milliseconds: 100),
      ).connect(_uri(server), headers: const <String, String>{});

      await channel.messages.drain<void>().timeout(const Duration(seconds: 5));
      expect(channel.closeCode, isNotNull);
    });

    test('the default ping interval comes from the policy', () {
      expect(
        const IoRealtimeTransport().pingInterval,
        const Duration(seconds: 20),
      );
    });
  });
}
