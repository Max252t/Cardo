import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/boards/data/boards_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';

void main() {
  group('boardInfoFromJson', () {
    test('maps a Board from the list schema with seq', () {
      final info = boardInfoFromJson(<String, Object?>{
        'id': '0190a1f2-0000-7000-8000-0000000000b1',
        'title': 'Roadmap',
        'owner_id': '0190a1f2-0000-7000-8000-000000000001',
        'seq': 12,
        'role': 'editor',
        'created_at': '2026-03-01T12:00:00Z',
        'updated_at': '2026-03-01T13:00:00+01:00',
      });

      expect(info.id, '0190a1f2-0000-7000-8000-0000000000b1');
      expect(info.title, 'Roadmap');
      expect(info.ownerId, '0190a1f2-0000-7000-8000-000000000001');
      expect(info.seq, 12);
      expect(info.role, BoardRole.editor);
      expect(info.createdAt, DateTime.utc(2026, 3, 1, 12));
      expect(info.updatedAt, DateTime.utc(2026, 3, 1, 12));
      expect(info.createdAt.isUtc, isTrue);
      expect(info.updatedAt.isUtc, isTrue);
    });

    test('BoardInfo inside a snapshot has no seq', () {
      expect(boardInfoFromJson(boardJson(seq: null)).seq, isNull);
    });

    test('an explicit seq argument wins', () {
      expect(boardInfoFromJson(boardJson(seq: 3), seq: 9).seq, 9);
    });

    for (final role in BoardRole.values) {
      test('parses role ${role.wireName}', () {
        expect(boardInfoFromJson(boardJson(role: role.wireName)).role, role);
      });
    }

    test('rejects unknown roles', () {
      for (final bad in <String>['admin', 'Owner', '']) {
        expect(
          () => boardInfoFromJson(boardJson(role: bad)),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    for (final field in <String>[
      'id',
      'title',
      'owner_id',
      'role',
      'created_at',
      'updated_at',
    ]) {
      test('requires $field', () {
        expect(
          () => boardInfoFromJson(boardJson()..remove(field)),
          throwsFormatException,
        );
      });
    }

    test('rejects a non-integer seq when present', () {
      expect(
        () => boardInfoFromJson(boardJson()..['seq'] = '7'),
        throwsFormatException,
      );
    });

    test('rejects an empty id', () {
      expect(() => boardInfoFromJson(boardJson(id: '')), throwsFormatException);
    });
  });

  group('boardListFromJson', () {
    test('maps an empty list', () {
      expect(boardListFromJson(boardListJson(const [])), isEmpty);
    });

    test('keeps the server order', () {
      final list = boardListFromJson(
        boardListJson(<Map<String, Object?>>[
          boardJson(id: 'b', title: 'B', role: 'viewer'),
          boardJson(id: 'a', title: 'A', role: 'owner'),
        ]),
      );

      expect(list.map((b) => b.id), <String>['b', 'a']);
      expect(list.map((b) => b.role), <BoardRole>[
        BoardRole.viewer,
        BoardRole.owner,
      ]);
    });

    test('requires the boards array and valid items', () {
      expect(
        () => boardListFromJson(<String, Object?>{}),
        throwsFormatException,
      );
      expect(() => boardListFromJson(null), throwsFormatException);
      expect(
        () => boardListFromJson(<String, Object?>{
          'boards': <Object?>[1],
        }),
        throwsFormatException,
      );
      expect(
        () => boardListFromJson(
          boardListJson(<Map<String, Object?>>[boardJson()..remove('role')]),
        ),
        throwsFormatException,
      );
    });
  });

  group('columnMarkerAt', () {
    List<ColumnMarker> markers(int count) => <ColumnMarker>[
      for (var i = 0; i < count; i++) columnMarkerAt(i, count),
    ];

    test('one column is the backlog', () {
      expect(markers(1), <ColumnMarker>[ColumnMarker.backlog]);
    });

    test('two columns are backlog and done', () {
      expect(markers(2), <ColumnMarker>[
        ColumnMarker.backlog,
        ColumnMarker.done,
      ]);
    });

    test('three columns add in progress', () {
      expect(markers(3), <ColumnMarker>[
        ColumnMarker.backlog,
        ColumnMarker.inProgress,
        ColumnMarker.done,
      ]);
    });

    test('four columns add review', () {
      expect(markers(4), <ColumnMarker>[
        ColumnMarker.backlog,
        ColumnMarker.inProgress,
        ColumnMarker.review,
        ColumnMarker.done,
      ]);
    });

    test('five and more columns repeat review in the middle', () {
      expect(markers(5), <ColumnMarker>[
        ColumnMarker.backlog,
        ColumnMarker.inProgress,
        ColumnMarker.review,
        ColumnMarker.review,
        ColumnMarker.done,
      ]);
      final seven = markers(7);
      expect(seven.first, ColumnMarker.backlog);
      expect(seven[1], ColumnMarker.inProgress);
      expect(seven.sublist(2, 6), everyElement(ColumnMarker.review));
      expect(seven.last, ColumnMarker.done);
    });
  });

  group('serverBoardFromJson', () {
    test('maps a full snapshot', () {
      final board = serverBoardFromJson(<String, Object?>{
        'board': <String, Object?>{
          'id': 'b1',
          'title': 'Roadmap',
          'owner_id': 'u1',
          'role': 'editor',
          'created_at': '2026-03-01T12:00:00Z',
          'updated_at': '2026-03-01T12:30:00Z',
        },
        'columns': <Object?>[
          <String, Object?>{
            'id': 'c1',
            'title': 'To do',
            'rank': 'a',
            'version': 3,
          },
        ],
        'cards': <Object?>[
          <String, Object?>{
            'id': 'k1',
            'column_id': 'c1',
            'title': 'Write tests',
            'description': 'All of them',
            'rank': 'V',
            'version': 2,
            'description_version': 4,
            'created_by': 'u1',
            'updated_by': 'u2',
            'created_at': '2026-03-01T12:00:00Z',
            'updated_at': '2026-03-01T14:00:00+02:00',
          },
        ],
        'members': <Object?>[
          <String, Object?>{
            'user_id': 'u1',
            'display_name': 'Anna',
            'avatar_color': '#7C3AED',
            'role': 'owner',
            'joined_at': '2026-03-01T12:00:00Z',
          },
        ],
        'seq': 41,
      });

      expect(board.info.id, 'b1');
      expect(board.info.seq, 41);
      expect(board.info.role, BoardRole.editor);
      expect(board.model.id, 'b1');
      expect(board.model.title, 'Roadmap');
      expect(board.model.seq, 41);
      expect(board.model.columns.single.version, 3);
      expect(board.model.columns.single.marker, ColumnMarker.backlog);

      final card = board.model.cards.single;
      expect(card.id, 'k1');
      expect(card.columnId, 'c1');
      expect(card.description, 'All of them');
      expect(card.version, 2);
      expect(card.descriptionVersion, 4);
      expect(card.createdBy, 'u1');
      expect(card.updatedBy, 'u2');
      expect(card.updatedAt, DateTime.utc(2026, 3, 1, 12));
      expect(card.createdAt.isUtc, isTrue);
      expect(card.updatedAt.isUtc, isTrue);
      expect(card.archived, isFalse);

      final member = board.model.members.single;
      expect(member.userId, 'u1');
      expect(member.name, 'Anna');
      expect(member.role, BoardRole.owner);
    });

    test('sorts columns by rank and assigns markers after sorting', () {
      final board = serverBoardFromJson(snapshotJson());

      expect(board.model.columns.map((c) => c.id), <String>[
        'col-a',
        'col-m',
        'col-b',
      ]);
      expect(board.model.columns.map((c) => c.marker), <ColumnMarker>[
        ColumnMarker.backlog,
        ColumnMarker.inProgress,
        ColumnMarker.done,
      ]);
    });

    test('ordering follows base62 code units, not locale rules', () {
      final board = serverBoardFromJson(
        snapshotJson(
          columns: <Map<String, Object?>>[
            columnJson(id: 'lower', rank: 'a'),
            columnJson(id: 'upper', rank: 'Z'),
            columnJson(id: 'digit', rank: '9'),
            columnJson(id: 'long', rank: 'a1'),
          ],
        ),
      );

      expect(board.model.columns.map((c) => c.id), <String>[
        'digit',
        'upper',
        'lower',
        'long',
      ]);
    });

    test('markers adapt to the number of columns', () {
      for (final count in <int>[1, 2, 3, 4, 5, 6]) {
        final board = serverBoardFromJson(
          snapshotJson(
            columns: <Map<String, Object?>>[
              for (var i = 0; i < count; i++)
                columnJson(id: 'c$i', rank: 'm${String.fromCharCode(97 + i)}'),
            ],
            cards: const [],
          ),
        );
        final markers = board.model.columns.map((c) => c.marker).toList();

        expect(markers.first, ColumnMarker.backlog);
        if (count > 1) {
          expect(markers.last, ColumnMarker.done);
        }
        expect(board.model.columns.map((c) => c.id), [
          for (var i = 0; i < count; i++) 'c$i',
        ]);
      }
    });

    test('empty columns, cards and members are valid', () {
      final board = serverBoardFromJson(
        snapshotJson(columns: const [], cards: const [], members: const []),
      );

      expect(board.model.columns, isEmpty);
      expect(board.model.cards, isEmpty);
      expect(board.model.members, isEmpty);
    });

    test('member colors are normalized when valid and kept when not', () {
      final board = serverBoardFromJson(
        snapshotJson(
          members: <Map<String, Object?>>[
            memberJson(userId: 'a', avatarColor: '#0ea5e9'),
            memberJson(userId: 'b', avatarColor: 'teal'),
          ],
        ),
      );

      expect(board.model.members.map((m) => m.avatarColor), <String>[
        '#0EA5E9',
        'teal',
      ]);
    });

    test('board role comes from board.role and member roles from members', () {
      final board = serverBoardFromJson(
        snapshotJson(
          board: boardJson(role: 'viewer'),
          members: <Map<String, Object?>>[
            memberJson(userId: 'a', role: 'owner'),
            memberJson(userId: 'b', role: 'viewer'),
          ],
        ),
      );

      expect(board.info.role, BoardRole.viewer);
      expect(board.model.members.map((m) => m.role), <BoardRole>[
        BoardRole.owner,
        BoardRole.viewer,
      ]);
    });

    for (final field in <String>[
      'board',
      'columns',
      'cards',
      'members',
      'seq',
    ]) {
      test('requires $field', () {
        expect(
          () => serverBoardFromJson(snapshotJson()..remove(field)),
          throwsFormatException,
        );
      });
    }

    for (final field in <String>['id', 'title', 'rank', 'version']) {
      test('column requires $field', () {
        final column = columnJson(id: 'c', rank: 'a')..remove(field);
        expect(
          () => serverBoardFromJson(
            snapshotJson(columns: <Map<String, Object?>>[column]),
          ),
          throwsFormatException,
        );
      });
    }

    for (final field in <String>[
      'id',
      'column_id',
      'title',
      'description',
      'rank',
      'version',
      'description_version',
      'created_by',
      'updated_by',
      'created_at',
      'updated_at',
    ]) {
      test('card requires $field', () {
        final card = cardJson(id: 'k', columnId: 'c')..remove(field);
        expect(
          () => serverBoardFromJson(
            snapshotJson(cards: <Map<String, Object?>>[card]),
          ),
          throwsFormatException,
        );
      });
    }

    for (final field in <String>[
      'user_id',
      'display_name',
      'avatar_color',
      'role',
    ]) {
      test('member requires $field', () {
        final member = memberJson(userId: 'u')..remove(field);
        expect(
          () => serverBoardFromJson(
            snapshotJson(members: <Map<String, Object?>>[member]),
          ),
          throwsFormatException,
        );
      });
    }

    test('a snapshot seq must be an integer', () {
      expect(
        () => serverBoardFromJson(snapshotJson()..['seq'] = 1.5),
        throwsFormatException,
      );
    });

    test('non-objects are rejected', () {
      expect(() => serverBoardFromJson(null), throwsFormatException);
      expect(() => serverBoardFromJson(<Object?>[]), throwsFormatException);
    });

    test('result lists are immutable', () {
      final board = serverBoardFromJson(snapshotJson());

      expect(
        () => board.model.cards.add(board.model.cards.first),
        throwsUnsupportedError,
      );
      expect(() => board.model.columns.clear(), throwsUnsupportedError);
    });
  });
}
