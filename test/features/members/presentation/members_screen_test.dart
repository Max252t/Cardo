import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/presentation/widgets/board_header_actions.dart';
import 'package:cardo/features/members/presentation/widgets/member_row.dart';
import 'package:cardo/features/members/presentation/widgets/role_picker.dart';
import 'package:cardo/shared/widgets/role_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../helpers/pump_members.dart';

Map<String, Object?> _member({
  String id = 'u-bob',
  String name = 'Боб',
  String role = 'editor',
}) => memberJson(userId: id, displayName: name, role: role);

void main() {
  group('owner list', () {
    testWidgets('shows people, their roles and manage controls only for '
        'non-owners', (tester) async {
      final rig = await pumpMembers(tester);
      await openMembers(tester, rig);

      expect(find.text(rig.l10n.membersTitle), findsOneWidget);
      expect(find.text('Елена'), findsWidgets);
      expect(find.text(rig.l10n.membersYou), findsOneWidget);
      expect(find.text('elena@studio.ru'), findsOneWidget);
      expect(find.text('Максим'), findsOneWidget);
      expect(find.text('Аня'), findsOneWidget);
      expect(find.byType(RoleBadge), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(MemberRow),
          matching: find.byType(RolePickerButton),
        ),
        findsOneWidget,
      );
      expect(
        find.byTooltip(rig.l10n.membersRemoveTooltip('Аня')),
        findsOneWidget,
      );
      expect(
        find.byTooltip(rig.l10n.membersRemoveTooltip('Максим')),
        findsNothing,
      );
      expect(
        find.byTooltip(rig.l10n.membersRemoveTooltip('Елена')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the summary counts people and online', (tester) async {
      final rig = await pumpMembers(tester);
      await openMembers(tester, rig);

      expect(
        find.text(
          rig.l10n.membersSummary(
            rig.l10n.membersCount(3),
            rig.l10n.membersOnlineCount(3),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('live events update the list without a REST roster', (
      tester,
    ) async {
      final rig = await pumpMembers(tester);
      await openMembers(tester, rig);
      final anya = find.byKey(const ValueKey<String>('member-u-anya'));
      expect(
        find.descendant(of: anya, matching: find.text(rig.l10n.roleEditor)),
        findsOneWidget,
      );

      rig.gateway.server.changeRole(DemoIds.anya, BoardRole.viewer);
      await settle(tester);
      expect(
        find.descendant(of: anya, matching: find.text(rig.l10n.roleViewer)),
        findsOneWidget,
      );

      rig.gateway.server.commitEvent(
        (seq, ts) => MemberAddedEvent(
          seq: seq,
          serverTs: ts,
          actorId: DemoIds.elena,
          userId: 'u-bob',
          displayName: 'Боб',
          avatarColor: '#D23A6E',
          role: BoardRole.editor,
        ),
      );
      await settle(tester);
      expect(find.text('Боб'), findsOneWidget);

      rig.gateway.server.removeMember(DemoIds.anya);
      await settle(tester);
      expect(find.text('Аня'), findsNothing);
      expect(find.byType(MemberRow), findsNWidgets(3));
      expect(rig.adapter.requests.where((r) => r.path == membersPath), isEmpty);
    });
  });

  group('add by email', () {
    testWidgets('posts email and role, confirms and clears the field', (
      tester,
    ) async {
      final rig = await pumpMembers(tester);
      rig.on('POST', membersPath, FakeResponse.ok(_member(), status: 201));
      await openMembers(tester, rig);

      await enterEmail(tester, '  bob@example.com ');
      await tapLabel(tester, rig.l10n.membersAddAction);

      final request = rig.sent('POST', membersPath).single;
      expect(request.body, <String, Object?>{
        'email': 'bob@example.com',
        'role': 'editor',
      });
      expect(find.text(rig.l10n.membersAdded('Боб')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty,
      );
    });

    testWidgets('server refusals are shown by error code', (tester) async {
      final rig = await pumpMembers(tester);
      await openMembers(tester, rig);
      await enterEmail(tester, 'bob@example.com');

      final cases = <(int, String, String)>[
        (404, 'not_found', rig.l10n.membersErrorNotFound),
        (409, 'already_member', rig.l10n.membersErrorAlreadyMember),
        (400, 'validation_error', rig.l10n.membersErrorValidation),
        (403, 'forbidden', rig.l10n.membersErrorForbidden),
      ];
      for (final (status, code, text) in cases) {
        rig.on('POST', membersPath, FakeResponse.error(status, code));
        await tapLabel(tester, rig.l10n.membersAddAction);
        expect(find.text(text), findsOneWidget, reason: code);
      }
      expect(rig.sent('POST', membersPath), hasLength(cases.length));
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'bob@example.com',
      );
    });

    testWidgets('an invalid email is blocked before any request', (
      tester,
    ) async {
      final rig = await pumpMembers(tester);
      await openMembers(tester, rig);

      await enterEmail(tester, 'not-an-email');
      await tapLabel(tester, rig.l10n.membersAddAction);

      expect(find.text(rig.l10n.fieldEmailInvalid), findsOneWidget);
      expect(rig.sent('POST', membersPath), isEmpty);
    });

    testWidgets('the add button is blocked while the request is in flight', (
      tester,
    ) async {
      final rig = await pumpMembers(tester);
      final gate = rig.hold(
        'POST',
        membersPath,
        FakeResponse.ok(_member(), status: 201),
      );
      await openMembers(tester, rig);
      await enterEmail(tester, 'bob@example.com');

      await tapLabel(tester, rig.l10n.membersAddAction);
      await tester.pump();
      final button = find.byType(FilledButton);
      expect(
        tester.widgetList<FilledButton>(button).any((b) => b.onPressed == null),
        isTrue,
      );
      expect(rig.sent('POST', membersPath), hasLength(1));
      gate.complete();
      await settle(tester);
    });
  });

  group('role change and removal', () {
    testWidgets('changing the role patches the member', (tester) async {
      final rig = await pumpMembers(tester);
      rig.on('PATCH', anyaPath, FakeResponse.ok(_member(id: DemoIds.anya)));
      await openMembers(tester, rig);

      await tester.tap(
        find.byTooltip(rig.l10n.membersRoleChange('Аня', rig.l10n.roleEditor)),
      );
      await settle(tester);
      await tester.tap(find.text(rig.l10n.roleViewer).last);
      await settle(tester);

      expect(rig.sent('PATCH', anyaPath).single.body, <String, Object?>{
        'role': 'viewer',
      });
    });

    testWidgets('a forbidden answer to a role change is shown', (tester) async {
      final rig = await pumpMembers(tester);
      rig.on('PATCH', anyaPath, FakeResponse.error(403, 'forbidden'));
      await openMembers(tester, rig);

      await tester.tap(
        find.byTooltip(rig.l10n.membersRoleChange('Аня', rig.l10n.roleEditor)),
      );
      await settle(tester);
      await tester.tap(find.text(rig.l10n.roleViewer).last);
      await settle(tester);

      expect(find.text(rig.l10n.membersErrorForbidden), findsOneWidget);
    });

    testWidgets('removal needs confirmation; cancel sends nothing', (
      tester,
    ) async {
      final rig = await pumpMembers(tester);
      rig.on('DELETE', anyaPath, FakeResponse.empty(204));
      await openMembers(tester, rig);
      final remove = find.byTooltip(rig.l10n.membersRemoveTooltip('Аня'));

      await tester.tap(remove);
      await settle(tester);
      expect(find.text(rig.l10n.membersRemoveTitle('Аня')), findsOneWidget);
      await tester.tap(find.text(rig.l10n.commonCancel));
      await settle(tester);
      expect(rig.sent('DELETE', anyaPath), isEmpty);

      await tester.tap(remove);
      await settle(tester);
      await tester.tap(find.text(rig.l10n.membersRemoveConfirm));
      await settle(tester);
      expect(rig.sent('DELETE', anyaPath), hasLength(1));
    });

    testWidgets('the board ending closes the open removal dialog too', (
      tester,
    ) async {
      final rig = await pumpMembers(tester);
      rig.on('DELETE', anyaPath, FakeResponse.empty(204));
      await openMembers(tester, rig);

      await tester.tap(find.byTooltip(rig.l10n.membersRemoveTooltip('Аня')));
      await settle(tester);
      expect(find.text(rig.l10n.membersRemoveConfirm), findsOneWidget);

      rig.gateway.server.deleteBoard();
      await settle(tester);

      expect(find.text(rig.l10n.membersRemoveConfirm), findsNothing);
      expect(find.text(rig.l10n.membersRemoveTitle('Аня')), findsNothing);
      expect(rig.sent('DELETE', anyaPath), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('invites', () {
    testWidgets('create shows the link once, copy puts it on the clipboard, '
        'revoke removes it', (tester) async {
      final rig = await pumpMembers(tester);
      rig.on(
        'GET',
        invitesPath,
        FakeResponse.ok(
          invitesJson(<Map<String, Object?>>[inviteJson(id: 'old', uses: 2)]),
        ),
      );
      rig.on(
        'POST',
        invitesPath,
        FakeResponse.ok(
          inviteJson(id: 'new', token: inviteToken, uses: 0),
          status: 201,
        ),
      );
      rig.on('DELETE', '$invitesPath/new', FakeResponse.empty(204));
      await openMembers(tester, rig);

      expect(find.text(rig.l10n.invitesTokenHint), findsOneWidget);
      expect(find.textContaining('cardo://'), findsNothing);
      expect(
        find.text(
          '${rig.l10n.roleEditor} · ${rig.l10n.invitesLeftDays(6)} · '
          '${rig.l10n.invitesUses(2, 5)}',
        ),
        findsOneWidget,
      );

      await tapLabel(tester, rig.l10n.invitesCreate);
      expect(rig.sent('POST', invitesPath).single.body, <String, Object?>{
        'role': 'editor',
        'expires_in': 604800,
        'max_uses': 5,
      });
      expect(find.text('cardo://invite/$inviteToken'), findsOneWidget);

      await tapLabel(tester, rig.l10n.invitesCopy);
      expect(rig.clipboard, <String>['cardo://invite/$inviteToken']);
      expect(find.text(rig.l10n.invitesCopied), findsOneWidget);

      final revoke = find.text(rig.l10n.invitesRevoke).first;
      await tester.ensureVisible(revoke);
      await tester.pump();
      await tester.tap(revoke);
      await settle(tester);
      expect(rig.sent('DELETE', '$invitesPath/new'), hasLength(1));
      expect(find.text('cardo://invite/$inviteToken'), findsNothing);
    });

    testWidgets('the link is not shown again after reopening', (tester) async {
      final rig = await pumpMembers(tester);
      rig.on(
        'POST',
        invitesPath,
        FakeResponse.ok(
          inviteJson(id: 'new', token: inviteToken, uses: 0),
          status: 201,
        ),
      );
      await openMembers(tester, rig);
      await tapLabel(tester, rig.l10n.invitesCreate);
      expect(find.text('cardo://invite/$inviteToken'), findsOneWidget);

      await tester.tap(find.byTooltip(rig.l10n.commonClose));
      await settle(tester);
      rig.on(
        'GET',
        invitesPath,
        FakeResponse.ok(
          invitesJson(<Map<String, Object?>>[inviteJson(id: 'new', uses: 0)]),
        ),
      );
      await openMembers(tester, rig);

      expect(find.textContaining('cardo://'), findsNothing);
      expect(find.text(rig.l10n.invitesRevoke), findsOneWidget);
    });

    testWidgets('creating can be refused by the server', (tester) async {
      final rig = await pumpMembers(tester);
      rig.on('POST', invitesPath, FakeResponse.error(403, 'forbidden'));
      await openMembers(tester, rig);

      await tapLabel(tester, rig.l10n.invitesCreate);

      expect(find.text(rig.l10n.membersErrorForbidden), findsOneWidget);
      expect(find.textContaining('cardo://'), findsNothing);
    });

    testWidgets('a failed invite list can be retried', (tester) async {
      final rig = await pumpMembers(tester);
      rig.on('GET', invitesPath, FakeResponse.error(500, 'internal'));
      await openMembers(tester, rig);
      expect(find.text(rig.l10n.invitesLoadError), findsOneWidget);

      rig.on('GET', invitesPath, FakeResponse.ok(invitesJson(const [])));
      await tapLabel(tester, rig.l10n.commonRetry);

      expect(find.text(rig.l10n.invitesLoadError), findsNothing);
      expect(find.text(rig.l10n.invitesEmpty), findsOneWidget);
    });
  });

  group('without manage rights', () {
    for (final role in <BoardRole>[BoardRole.editor, BoardRole.viewer]) {
      testWidgets('${role.wireName} sees a read-only list', (tester) async {
        final rig = await pumpMembers(tester, role: role);
        await openMembers(tester, rig);

        expect(find.text('Максим'), findsOneWidget);
        expect(find.byType(RoleBadge), findsNWidgets(3));
        expect(find.byType(TextFormField), findsNothing);
        expect(find.byType(RolePickerButton), findsNothing);
        expect(find.text(rig.l10n.invitesTitle), findsNothing);
        expect(
          find.byTooltip(rig.l10n.membersRemoveTooltip('Аня')),
          findsNothing,
        );
        expect(rig.adapter.requests, isEmpty);
      });
    }

    testWidgets('the invite button is for the owner', (tester) async {
      final rig = await pumpMembers(tester, size: expandedSize);
      expect(find.byType(InviteButton), findsOneWidget);
      expect(find.byType(MembersButton), findsOneWidget);
      expect(rig.adapter.requests, isEmpty);
    });

    testWidgets('an editor has the members button but no invite button', (
      tester,
    ) async {
      await pumpMembers(tester, size: expandedSize, role: BoardRole.editor);
      expect(find.byType(InviteButton), findsNothing);
      expect(find.byType(MembersButton), findsOneWidget);
    });
  });

  group('windows and locales', () {
    testWidgets('narrow phone at double text scale does not overflow', (
      tester,
    ) async {
      final rig = await pumpMembers(tester, size: narrowSize, textScale: 2);
      rig.on(
        'GET',
        invitesPath,
        FakeResponse.ok(invitesJson(<Map<String, Object?>>[inviteJson()])),
      );
      await openMembers(tester, rig);

      expect(find.text(rig.l10n.membersTitle), findsOneWidget);
      expect(find.text('Аня'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await enterEmail(tester, 'bob@example.com');
      rig.on('POST', invitesPath, FakeResponse.error(403, 'forbidden'));
      await tapLabel(tester, rig.l10n.invitesCreate);
      expect(tester.takeException(), isNull);
    });

    testWidgets('expanded dark theme shows a dialog, invite opens on the link '
        'section', (tester) async {
      final rig = await pumpMembers(
        tester,
        size: expandedSize,
        brightness: Brightness.dark,
      );
      rig.on(
        'POST',
        invitesPath,
        FakeResponse.ok(
          inviteJson(id: 'new', token: inviteToken, uses: 0),
          status: 201,
        ),
      );

      await tester.tap(find.byType(InviteButton));
      await settle(tester);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text(rig.l10n.invitesTitle), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text('Аня')),
        findsOneWidget,
      );
      await tapLabel(tester, rig.l10n.invitesCreate);
      expect(find.text('cardo://invite/$inviteToken'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('english texts', (tester) async {
      final rig = await pumpMembers(tester, locale: const Locale('en'));
      rig.on('POST', membersPath, FakeResponse.error(404, 'not_found'));
      await openMembers(tester, rig);

      expect(find.text('Members'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Invite link'), findsOneWidget);
      await enterEmail(tester, 'ghost@example.com');
      await tapLabel(tester, 'Add');
      expect(find.text('No user with this email'), findsOneWidget);
    });
  });
}
