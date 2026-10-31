import 'package:cardo/features/boards/presentation/new_board_dialog.dart';
import 'package:cardo/shared/widgets/cardo_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_server.dart';
import '../../../helpers/pump_cardo_app.dart';

const String createKey = 'POST /api/boards';
const String listKey = 'GET /api/boards';

Future<AppHandle> openAndSend(
  WidgetTester tester,
  FakeServer server,
  Variant variant,
  String title,
) async {
  final app = await pumpCardoApp(tester, server: server, variant: variant);
  await tester.tap(find.text(app.l10n.boardsNew));
  await pumpFrames(tester, 6);
  await tester.enterText(find.byType(TextFormField), title);
  await tester.pump();
  await tester.tap(
    find.widgetWithText(CardoPrimaryButton, app.l10n.newBoardSubmit),
  );
  await pumpFrames(tester, 2);
  return app;
}

void main() {
  for (final variant in const <Variant>[ruPhone, ruDesktop]) {
    group('the form is dismissed while sending on $variant', () {
      testWidgets('the list is reloaded after the response', (tester) async {
        final server = FakeServer();
        final gate = server.gate(createKey);
        final app = await openAndSend(tester, server, variant, 'Late board');
        final listsBefore = server.count(listKey);
        expect(server.count(createKey), 1);

        await tester.tapAt(const Offset(4, 4));
        await pumpFrames(tester, 6);
        expect(find.byType(NewBoardForm), findsNothing);

        gate.complete();
        await pumpFrames(tester, 8);

        expect(server.count(listKey), listsBefore + 1);
        expect(find.text('Late board'), findsWidgets);
        expect(app.location, '/boards');
        expect(tester.takeException(), isNull);
      });

      testWidgets('a failed request does not reload the list', (tester) async {
        final server = FakeServer();
        final gate = server.gate(createKey);
        server.on(createKey, FakeResponse.error(500, 'internal'));
        await openAndSend(tester, server, variant, 'Broken');
        final listsBefore = server.count(listKey);

        await tester.tapAt(const Offset(4, 4));
        await pumpFrames(tester, 6);
        gate.complete();
        await pumpFrames(tester, 8);

        expect(server.count(listKey), listsBefore);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
