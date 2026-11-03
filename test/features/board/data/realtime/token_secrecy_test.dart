import 'package:cardo/features/board/data/realtime/realtime_credentials.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/engine_rig.dart';
import '../../helpers/manual_transport.dart';

void main() {
  test('AccessGrant and credentials never print the token', () {
    final grant = AccessGrant(
      token: 'SECRET-VALUE',
      expiresAt: DateTime.utc(2030),
    );

    expect(grant.toString(), isNot(contains('SECRET-VALUE')));
    expect(
      grant,
      AccessGrant(token: 'SECRET-VALUE', expiresAt: DateTime.utc(2030)),
    );
    expect(
      grant == AccessGrant(token: 'other', expiresAt: DateTime.utc(2030)),
      isFalse,
    );
  });

  rigTest('the token travels only in the Authorization header', (rig) async {
    final m = ManualEngine(rig);
    m.engine.start();
    await rig.run(10);
    m.channel.pushJson(serverMessage('sync.ready'));
    await rig.run(10);

    expect(m.transport.uris.single.toString(), isNot(contains('tok-')));
    expect(m.transport.uris.single.query, isEmpty);
    expect(m.transport.uris.single.userInfo, isEmpty);
    expect(m.transport.headers.single['Authorization'], 'Bearer tok-0');
    expect(m.channel.sent.single, isNot(contains('tok-')));
    await m.engine.dispose();
  });

  rigTest('signals and issues never mention the token', (rig) async {
    await rig.start();
    rig.server.expireTokens();
    await rig.run(10);
    rig.server.closeConnections(4400, 'bad');
    await rig.run(700);

    final text = [
      ...rig.signals.map((s) => s.toString()),
      ...rig.issues.map((i) => i.toString()),
    ].join('\n');
    expect(text, isNot(contains('tok-')));
    expect(text, isNot(contains('Bearer')));
  });

  rigTest('auth.refresh carries the new token only in its payload', (
    rig,
  ) async {
    final m = ManualEngine(rig);
    m.engine.start();
    await rig.run(10);
    m.channel.pushJson(serverMessage('sync.ready'));
    await rig.run(60 * 60 * 1000 - 59000);

    final refresh = m.channel.sentMessages.last;
    expect(refresh['type'], 'auth.refresh');
    expect(refresh.keys.toSet(), {'v', 'type', 'payload'});
    expect(refresh['payload'], {'access_token': 'tok-1'});
    expect(m.transport.uris.single.toString(), isNot(contains('tok-')));
    await m.engine.dispose();
  });
}
