import 'package:cardo/shared/widgets/conflict_banner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('waiting text disables both actions and is announced', (
    tester,
  ) async {
    var overwrote = 0;
    var cancelled = 0;
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      ConflictBanner(
        title: 'Title',
        text: 'Body',
        waitingText: 'Loading',
        onOverwrite: () => overwrote++,
        onCancel: () => cancelled++,
      ),
    );
    expect(find.text('Loading'), findsOneWidget);
    await tester.tap(find.text('Перезаписать'), warnIfMissed: false);
    await tester.tap(find.text('Отменить'), warnIfMissed: false);
    await tester.pump();
    expect(overwrote, 0);
    expect(cancelled, 0);
    expect(find.bySemanticsLabel(RegExp('Loading')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('without waiting text the actions work', (tester) async {
    var overwrote = 0;
    var cancelled = 0;
    await pumpApp(
      tester,
      ConflictBanner(
        title: 'Title',
        text: 'Body',
        onOverwrite: () => overwrote++,
        onCancel: () => cancelled++,
      ),
    );
    expect(find.text('Loading'), findsNothing);
    await tester.tap(find.text('Перезаписать'));
    await tester.tap(find.text('Отменить'));
    expect(overwrote, 1);
    expect(cancelled, 1);
  });
}
