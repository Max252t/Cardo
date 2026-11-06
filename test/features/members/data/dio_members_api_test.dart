import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/core/network/dio_factory.dart';
import 'package:cardo/features/members/data/dio_members_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';
import '../../../helpers/fake_http_adapter.dart';

const String _userId = 'user-2';
const String _inviteId = 'invite-1';

Map<String, Object?> _inviteJson({String? token, int uses = 1}) =>
    <String, Object?>{
      'id': _inviteId,
      'role': 'editor',
      'expires_at': iso(t0.add(const Duration(days: 7))),
      'max_uses': 5,
      'uses': uses,
      'token': ?token,
    };

void main() {
  late FakeHttpAdapter adapter;
  late DioMembersApi api;

  void serve(FakeResponse response) {
    adapter = FakeHttpAdapter((options) => response);
    api = DioMembersApi(
      createDio(Uri.parse('http://api.test'), adapter: adapter),
    );
  }

  group('members', () {
    test('listMembers maps the roster', () async {
      serve(
        FakeResponse.ok(<String, Object?>{
          'members': <Map<String, Object?>>[
            memberJson(userId: annaId, displayName: 'Anna', role: 'owner'),
            memberJson(userId: _userId, role: 'viewer'),
          ],
        }),
      );

      final result = await api.listMembers(boardId1);

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/api/boards/$boardId1/members');
      expect(result.valueOrNull?.map((m) => m.role), <BoardRole>[
        BoardRole.owner,
        BoardRole.viewer,
      ]);
      expect(result.valueOrNull?.first.joinedAt, t0);
    });

    test(
      'addMember posts the email and role and maps the 201 member',
      () async {
        serve(
          FakeResponse.ok(
            memberJson(userId: _userId, displayName: 'Bob'),
            status: 201,
          ),
        );

        final result = await api.addMember(
          boardId1,
          email: 'bob@example.com',
          role: BoardRole.editor,
        );

        expect(adapter.requests.single.method, 'POST');
        expect(adapter.requests.single.path, '/api/boards/$boardId1/members');
        expect(adapter.requests.single.body, <String, Object?>{
          'email': 'bob@example.com',
          'role': 'editor',
        });
        expect(result.valueOrNull?.name, 'Bob');
      },
    );

    test('addMember errors are typed by code', () async {
      Future<ApiFailure?> failureFor(int status, String code) async {
        serve(FakeResponse.error(status, code));
        return (await api.addMember(
          boardId1,
          email: 'x@example.com',
          role: BoardRole.viewer,
        )).failureOrNull;
      }

      expect(await failureFor(404, 'not_found'), const NotFoundFailure());
      expect(
        await failureFor(409, 'already_member'),
        const UnknownFailure(statusCode: 409, code: 'already_member'),
      );
      expect(
        await failureFor(400, 'validation_error'),
        isA<ValidationFailure>(),
      );
      expect(await failureFor(403, 'forbidden'), const ForbiddenFailure());
    });

    test('changeRole patches the encoded member path', () async {
      serve(FakeResponse.ok(memberJson(userId: 'u/1', role: 'viewer')));

      final result = await api.changeRole(boardId1, 'u/1', BoardRole.viewer);

      expect(adapter.requests.single.method, 'PATCH');
      expect(
        adapter.requests.single.path,
        '/api/boards/$boardId1/members/u%2F1',
      );
      expect(adapter.requests.single.body, <String, Object?>{'role': 'viewer'});
      expect(result.valueOrNull?.role, BoardRole.viewer);
    });

    test('removeMember accepts 204 and types 403', () async {
      serve(FakeResponse.empty(204));
      final removed = await api.removeMember(boardId1, _userId);
      expect(removed.isSuccess, isTrue);
      expect(adapter.requests.single.method, 'DELETE');
      expect(
        adapter.requests.single.path,
        '/api/boards/$boardId1/members/$_userId',
      );

      serve(FakeResponse.error(403, 'forbidden'));
      expect(
        (await api.removeMember(boardId1, _userId)).failureOrNull,
        const ForbiddenFailure(),
      );
    });

    test('a roster with an unknown role is an unknown failure', () async {
      serve(
        FakeResponse.ok(<String, Object?>{
          'members': <Map<String, Object?>>[
            memberJson(userId: _userId, role: 'admin'),
          ],
        }),
      );

      expect(
        (await api.listMembers(boardId1)).failureOrNull,
        const UnknownFailure(),
      );
    });
  });

  group('invites', () {
    test('listInvites maps invites without tokens', () async {
      serve(
        FakeResponse.ok(<String, Object?>{
          'invites': <Map<String, Object?>>[_inviteJson(uses: 2)],
        }),
      );

      final result = await api.listInvites(boardId1);

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/api/boards/$boardId1/invites');
      final invite = result.valueOrNull!.single;
      expect(invite.id, _inviteId);
      expect(invite.role, BoardRole.editor);
      expect(invite.uses, 2);
      expect(invite.maxUses, 5);
      expect(invite.expiresAt, t0.add(const Duration(days: 7)));
    });

    test(
      'createInvite sends role, ttl and max uses and returns the token',
      () async {
        serve(FakeResponse.ok(_inviteJson(token: 'tok-secret'), status: 201));

        final result = await api.createInvite(
          boardId1,
          role: BoardRole.editor,
          expiresIn: const Duration(days: 7),
          maxUses: 5,
        );

        expect(adapter.requests.single.method, 'POST');
        expect(adapter.requests.single.body, <String, Object?>{
          'role': 'editor',
          'expires_in': 604800,
          'max_uses': 5,
        });
        expect(result.valueOrNull?.token, 'tok-secret');
        expect(result.valueOrNull?.invite.id, _inviteId);
        expect('${result.valueOrNull}', isNot(contains('tok-secret')));
      },
    );

    test('createInvite omits unset limits', () async {
      serve(FakeResponse.ok(_inviteJson(token: 'tok'), status: 201));

      await api.createInvite(boardId1, role: BoardRole.viewer);

      expect(adapter.requests.single.body, <String, Object?>{'role': 'viewer'});
    });

    test('a created invite without a token is malformed', () async {
      serve(FakeResponse.ok(_inviteJson(), status: 201));

      expect(
        (await api.createInvite(
          boardId1,
          role: BoardRole.viewer,
        )).failureOrNull,
        const UnknownFailure(),
      );
    });

    test('revokeInvite deletes by id and types 403', () async {
      serve(FakeResponse.empty(204));
      expect((await api.revokeInvite(boardId1, _inviteId)).isSuccess, isTrue);
      expect(adapter.requests.single.method, 'DELETE');
      expect(
        adapter.requests.single.path,
        '/api/boards/$boardId1/invites/$_inviteId',
      );

      serve(FakeResponse.error(403, 'forbidden'));
      expect(
        (await api.revokeInvite(boardId1, _inviteId)).failureOrNull,
        const ForbiddenFailure(),
      );
    });
  });
}
