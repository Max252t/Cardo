import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_notices.dart';
import 'package:cardo/features/board/presentation/widgets/board_snackbar.dart';
import 'package:cardo/l10n/app_localizations.dart';
import 'package:cardo/l10n/app_localizations_ru.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

final DateTime _t = DateTime.utc(2026, 1, 1);

PendingOp _item(
  String opId, {
  PendingOpStatus status = PendingOpStatus.sent,
  OpRejection? rejection,
  int failedAttempts = 0,
}) {
  return PendingOp(
    op: moveOp('a1', colB, opId: opId),
    status: status,
    createdAt: _t,
    rejection: rejection,
    failedAttempts: failedAttempts,
  );
}

BoardSyncState _state(List<PendingOp> pending) {
  return BoardSyncState(
    confirmed: makeBoard(),
    lastSeq: 10,
    pending: pending,
    connection: ConnectionStatus.connected,
  );
}

void main() {
  group('noticesBetween', () {
    test('nothing without rejections', () {
      expect(noticesBetween(null, _state(const <PendingOp>[])), isEmpty);
      expect(
        noticesBetween(_state(const <PendingOp>[]), _state([_item('1')])),
        isEmpty,
      );
    });

    test('a newly rejected op yields one notice with the actor name', () {
      const nack = OpRejection(
        reason: NackReason.versionConflict,
        actorId: 'u1',
      );
      final before = _state([_item('1')]);
      final after = _state([
        _item('1', status: PendingOpStatus.rejected, rejection: nack),
      ]);
      final notices = noticesBetween(before, after);
      expect(notices.length, 1);
      expect(notices.single.opId, '1');
      expect(notices.single.rejection, nack);
      expect(notices.single.actorName, 'One');
      expect(notices.single.retrying, isFalse);
    });

    test('works from a null previous state', () {
      const nack = OpRejection(reason: NackReason.forbidden);
      final after = _state([
        _item('1', status: PendingOpStatus.rejected, rejection: nack),
      ]);
      expect(noticesBetween(null, after).single.actorName, isNull);
    });

    test('an unknown actor id gives no name', () {
      const nack = OpRejection(
        reason: NackReason.versionConflict,
        actorId: 'stranger',
      );
      final after = _state([
        _item('1', status: PendingOpStatus.rejected, rejection: nack),
      ]);
      expect(noticesBetween(null, after).single.actorName, isNull);
    });

    test('an already rejected op does not repeat', () {
      const nack = OpRejection(reason: NackReason.forbidden);
      final rejected = _item(
        '1',
        status: PendingOpStatus.rejected,
        rejection: nack,
      );
      expect(noticesBetween(_state([rejected]), _state([rejected])), isEmpty);
    });

    test('a rejected op without rejection data is ignored', () {
      final after = _state([_item('1', status: PendingOpStatus.rejected)]);
      expect(noticesBetween(null, after), isEmpty);
    });

    test('a retry yields a retrying internal notice', () {
      final before = _state([_item('1')]);
      final after = _state([_item('1', failedAttempts: 1)]);
      final notices = noticesBetween(before, after);
      expect(notices.length, 1);
      expect(notices.single.retrying, isTrue);
      expect(notices.single.rejection.reason, NackReason.internal);
    });

    test('an unchanged attempt count yields nothing', () {
      final same = _state([_item('1', failedAttempts: 1)]);
      expect(noticesBetween(same, same), isEmpty);
    });

    test('final internal failure is a non-retrying notice', () {
      const nack = OpRejection(reason: NackReason.internal);
      final before = _state([_item('1', failedAttempts: 2)]);
      final after = _state([
        _item(
          '1',
          status: PendingOpStatus.rejected,
          rejection: nack,
          failedAttempts: 2,
        ),
      ]);
      final notices = noticesBetween(before, after);
      expect(notices.single.retrying, isFalse);
      expect(notices.single.rejection.reason, NackReason.internal);
    });

    test('several rejections keep their order', () {
      const nack = OpRejection(reason: NackReason.notFound);
      final after = _state([
        _item('1', status: PendingOpStatus.rejected, rejection: nack),
        _item('2', status: PendingOpStatus.rejected, rejection: nack),
      ]);
      expect(noticesBetween(null, after).map((n) => n.opId), <String>[
        '1',
        '2',
      ]);
    });

    test('BoardNotice equality', () {
      const nack = OpRejection(reason: NackReason.forbidden);
      const a = BoardNotice(opId: '1', rejection: nack, retrying: false);
      const b = BoardNotice(opId: '1', rejection: nack, retrying: false);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(const BoardNotice(opId: '1', rejection: nack, retrying: true)),
      );
    });
  });

  group('nackMessage (DESIGN section 8)', () {
    final AppLocalizations l10n = AppLocalizationsRu();

    String message(OpRejection rejection, {String? actor, bool? retrying}) {
      return nackMessage(
        l10n,
        rejection,
        actorName: actor,
        retrying: retrying ?? false,
      );
    }

    test('forbidden', () {
      expect(
        message(const OpRejection(reason: NackReason.forbidden)),
        'Нет прав на это действие.',
      );
    });

    test('validation error uses the limit', () {
      expect(
        message(
          const OpRejection(reason: NackReason.validationError, limit: 500),
        ),
        'Слишком длинный текст: максимум 500 символов.',
      );
    });

    test('validation error defaults to 500', () {
      expect(
        message(const OpRejection(reason: NackReason.validationError)),
        'Слишком длинный текст: максимум 500 символов.',
      );
    });

    test('version conflict names the actor', () {
      expect(
        message(
          const OpRejection(reason: NackReason.versionConflict),
          actor: 'Максим',
        ),
        'Карточку уже переместил Максим.',
      );
    });

    test('version conflict without actor', () {
      expect(
        message(const OpRejection(reason: NackReason.versionConflict)),
        'Карточку уже изменил другой участник.',
      );
    });

    test('not found', () {
      expect(
        message(const OpRejection(reason: NackReason.notFound)),
        'Карточка уже в архиве.',
      );
    });

    test('internal while retrying and when final', () {
      const internal = OpRejection(reason: NackReason.internal);
      expect(
        message(internal, retrying: true),
        'Не удалось сохранить. Пробуем ещё раз…',
      );
      expect(message(internal), 'Не удалось сохранить изменение.');
    });

    test('rate limited', () {
      expect(
        message(const OpRejection(reason: NackReason.rateLimited)),
        'Слишком много изменений. Попробуйте через минуту.',
      );
    });

    test('every reason has a non-empty message', () {
      for (final reason in NackReason.values) {
        expect(message(OpRejection(reason: reason)), isNotEmpty);
      }
    });
  });

  group('nackHasDismiss', () {
    test('only version_conflict has the dismiss action', () {
      for (final reason in NackReason.values) {
        expect(
          nackHasDismiss(reason),
          reason == NackReason.versionConflict,
          reason: reason.name,
        );
      }
    });

    test('dismiss label is Ponyatno', () {
      expect(AppLocalizationsRu().snackbarDismiss, 'Понятно');
    });
  });
}
