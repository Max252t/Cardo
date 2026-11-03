import 'package:cardo/core/realtime/realtime_policy.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/close_policy.dart';
import 'package:cardo/features/board/domain/op_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyClose covers every README close code', () {
    const table = <int, CloseAction>{
      1000: CloseAction.reconnect,
      1001: CloseAction.reconnect,
      1009: CloseAction.reconnect,
      1011: CloseAction.reconnect,
      1013: CloseAction.reconnect,
      4001: CloseAction.refreshAndReconnect,
      4003: CloseAction.boardRemoved,
      4004: CloseAction.boardDeleted,
      4008: CloseAction.reconnectSlow,
      4009: CloseAction.reconnect,
      4400: CloseAction.reconnectAfterViolation,
    };

    table.forEach((code, action) {
      test('$code is $action', () {
        expect(classifyClose(code), action);
      });
    });

    test('an abnormal closure without a code reconnects', () {
      expect(classifyClose(null), CloseAction.reconnect);
      expect(classifyClose(1006), CloseAction.reconnect);
    });

    test('an unknown code reconnects', () {
      expect(classifyClose(4999), CloseAction.reconnect);
      expect(classifyClose(0), CloseAction.reconnect);
    });

    test('only 4003 and 4004 are terminal', () {
      final terminal = <int>[
        for (final code in <int?>[
          null,
          1000,
          1001,
          1006,
          1009,
          1011,
          1013,
          4001,
          4003,
          4004,
          4008,
          4009,
          4400,
        ])
          if (isTerminalClose(classifyClose(code))) code!,
      ];

      expect(terminal, [4003, 4004]);
    });

    test('4003 and 4004 never ask for a reconnect action', () {
      expect(classifyClose(4003), isNot(CloseAction.reconnect));
      expect(classifyClose(4004), isNot(CloseAction.reconnect));
      expect(isTerminalClose(CloseAction.refreshAndReconnect), isFalse);
      expect(isTerminalClose(CloseAction.reconnectSlow), isFalse);
    });

    test('the policy constants match the README numbers', () {
      expect(CloseCodes.normal, 1000);
      expect(CloseCodes.goingAway, 1001);
      expect(CloseCodes.tooBig, 1009);
      expect(CloseCodes.syncFailure, 1011);
      expect(CloseCodes.tryAgainLater, 1013);
      expect(CloseCodes.tokenExpired, 4001);
      expect(CloseCodes.accessRevoked, 4003);
      expect(CloseCodes.boardDeleted, 4004);
      expect(CloseCodes.rateAbuse, 4008);
      expect(CloseCodes.slowClient, 4009);
      expect(CloseCodes.protocolViolation, 4400);
    });
  });

  group('textLimitOf', () {
    test('card text operations use the card limits', () {
      expect(
        textLimitOf(
          const CreateCard(
            opId: 'o',
            cardId: 'c',
            columnId: 'k',
            title: 't',
            actorId: 'u',
          ),
        ),
        CardLimits.titleMaxLength,
      );
      expect(
        textLimitOf(
          const EditCardTitle(opId: 'o', cardId: 'c', title: 't', actorId: 'u'),
        ),
        CardLimits.titleMaxLength,
      );
      expect(
        textLimitOf(
          const EditCardDescription(
            opId: 'o',
            cardId: 'c',
            description: 'd',
            baseDescriptionVersion: 1,
            actorId: 'u',
          ),
        ),
        CardLimits.descriptionMaxLength,
      );
    });

    test('column title operations use the column limit of 200', () {
      expect(ColumnLimits.titleMaxLength, 200);
      expect(
        textLimitOf(const CreateColumn(opId: 'o', columnId: 'k', title: 't')),
        200,
      );
      expect(
        textLimitOf(const RenameColumn(opId: 'o', columnId: 'k', title: 't')),
        200,
      );
    });

    test('operations without text have no limit', () {
      expect(
        textLimitOf(
          const MoveCard(
            opId: 'o',
            cardId: 'c',
            toColumnId: 'k',
            baseVersion: 1,
          ),
        ),
        isNull,
      );
      expect(textLimitOf(const ArchiveCard(opId: 'o', cardId: 'c')), isNull);
      expect(
        textLimitOf(const MoveColumn(opId: 'o', columnId: 'k', baseVersion: 1)),
        isNull,
      );
      expect(
        textLimitOf(const ArchiveColumn(opId: 'o', columnId: 'k')),
        isNull,
      );
    });
  });
}
