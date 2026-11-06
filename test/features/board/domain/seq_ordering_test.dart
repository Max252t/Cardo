import 'dart:math' as math;

import 'package:cardo/features/board/domain/apply_event.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/domain/seq_ordering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';
import '../helpers/event_factory.dart';

List<int> seqs(SeqIntake intake) =>
    intake.ready.map((event) => event.seq).toList();

void main() {
  group('applies only last + 1', () {
    test('the next event is ready and moves lastSeq', () {
      final ordering = SeqOrdering(5);

      final intake = ordering.accept(renamed(6));

      expect(seqs(intake), [6]);
      expect(ordering.lastSeq, 6);
      expect(intake.hasGap, isFalse);
      expect(ordering.hasGap, isFalse);
      expect(intake.duplicateOpIds, isEmpty);
    });

    test('an event above last + 1 is buffered and not applied', () {
      final ordering = SeqOrdering(5);

      final intake = ordering.accept(renamed(8));

      expect(intake.ready, isEmpty);
      expect(intake.hasGap, isTrue);
      expect(ordering.lastSeq, 5);
      expect(ordering.bufferedCount, 1);
      expect(ordering.firstBufferedSeq, 8);
      expect(ordering.hasGap, isTrue);
    });

    test('events in order are ready one by one', () {
      final ordering = SeqOrdering(0);

      for (var seq = 1; seq <= 4; seq++) {
        expect(seqs(ordering.accept(renamed(seq))), [seq]);
      }

      expect(ordering.lastSeq, 4);
    });

    test('a non-positive seq is ignored entirely', () {
      final ordering = SeqOrdering(0);

      final intake = ordering.accept(renamed(0, opId: 'x'));
      final negative = ordering.accept(renamed(-3, opId: 'y'));

      expect(intake.isEmpty, isTrue);
      expect(negative.isEmpty, isTrue);
      expect(ordering.lastSeq, 0);
      expect(ordering.hasGap, isFalse);
    });

    test('firstBufferedSeq is the minimum of the buffer', () {
      final ordering = SeqOrdering(0)
        ..accept(renamed(9))
        ..accept(renamed(4))
        ..accept(renamed(7));

      expect(ordering.firstBufferedSeq, 4);
      expect(ordering.bufferedCount, 3);
    });

    test('firstBufferedSeq is null for an empty buffer', () {
      expect(SeqOrdering(3).firstBufferedSeq, isNull);
    });
  });

  group('duplicates', () {
    test('seq <= last is a duplicate and is not ready', () {
      final ordering = SeqOrdering(5);

      final same = ordering.accept(renamed(5));
      final older = ordering.accept(renamed(2));

      expect(same.ready, isEmpty);
      expect(older.ready, isEmpty);
      expect(ordering.lastSeq, 5);
    });

    test('a duplicate without op_id reports nothing', () {
      final intake = SeqOrdering(5).accept(renamed(4));

      expect(intake.duplicateOpIds, isEmpty);
      expect(intake.isEmpty, isTrue);
    });

    test('a duplicate carrying an op_id resolves that op_id', () {
      final ordering = SeqOrdering(5);

      final intake = ordering.accept(renamed(5, opId: 'pending-1'));

      expect(intake.duplicateOpIds, ['pending-1']);
      expect(intake.ready, isEmpty);
      expect(intake.isEmpty, isFalse);
    });

    test('a duplicate of an already applied event does not rewind lastSeq', () {
      final ordering = SeqOrdering(0)
        ..accept(renamed(1))
        ..accept(renamed(2));

      ordering.accept(renamed(1, opId: 'late'));

      expect(ordering.lastSeq, 2);
    });

    test('the same buffered seq twice keeps one entry', () {
      final ordering = SeqOrdering(0)
        ..accept(renamed(5))
        ..accept(renamed(5));

      expect(ordering.bufferedCount, 1);
    });

    test('the lists exposed by an intake are unmodifiable', () {
      final intake = SeqOrdering(0).accept(renamed(1, opId: 'a'));

      expect(() => intake.ready.add(renamed(2)), throwsUnsupportedError);
      expect(() => intake.duplicateOpIds.add('b'), throwsUnsupportedError);
    });
  });

  group('buffer and drain', () {
    test('closing the gap drains the buffer in seq order', () {
      final ordering = SeqOrdering(0)
        ..accept(renamed(4))
        ..accept(renamed(3))
        ..accept(renamed(2));

      final intake = ordering.accept(renamed(1));

      expect(seqs(intake), [1, 2, 3, 4]);
      expect(ordering.lastSeq, 4);
      expect(intake.hasGap, isFalse);
      expect(ordering.bufferedCount, 0);
    });

    test('a partial drain leaves the tail buffered and the gap reported', () {
      final ordering = SeqOrdering(0)
        ..accept(renamed(2))
        ..accept(renamed(3))
        ..accept(renamed(6));

      final intake = ordering.accept(renamed(1));

      expect(seqs(intake), [1, 2, 3]);
      expect(intake.hasGap, isTrue);
      expect(ordering.firstBufferedSeq, 6);
      expect(ordering.lastSeq, 3);
    });

    test('hasGap on the intake reflects a still-open gap', () {
      final ordering = SeqOrdering(0);

      expect(ordering.accept(renamed(3)).hasGap, isTrue);
      expect(ordering.accept(renamed(2)).hasGap, isTrue);
      expect(ordering.accept(renamed(1)).hasGap, isFalse);
    });

    test('clearBuffer drops buffered events and the gap', () {
      final ordering = SeqOrdering(0)
        ..accept(renamed(3))
        ..accept(renamed(4));

      ordering.clearBuffer();

      expect(ordering.hasGap, isFalse);
      expect(ordering.bufferedCount, 0);
      expect(ordering.lastSeq, 0);
    });

    test('a buffered event whose seq got covered is reported as duplicate', () {
      final ordering = SeqOrdering(0)
        ..accept(renamed(2, opId: 'two'))
        ..accept(renamed(3, opId: 'three'));

      final intake = ordering.rebase(3);

      expect(intake.ready, isEmpty);
      expect(intake.duplicateOpIds, unorderedEquals(['two', 'three']));
      expect(ordering.hasGap, isFalse);
    });
  });

  group('rebase after a snapshot', () {
    test('rebase sets lastSeq', () {
      final ordering = SeqOrdering(2);

      final intake = ordering.rebase(40);

      expect(ordering.lastSeq, 40);
      expect(intake.isEmpty, isTrue);
      expect(intake.hasGap, isFalse);
    });

    test('buffered events at or below the snapshot are discarded', () {
      final ordering = SeqOrdering(0)
        ..accept(renamed(5, opId: 'a'))
        ..accept(renamed(6, opId: 'b'))
        ..accept(renamed(7));

      final intake = ordering.rebase(6);

      expect(intake.duplicateOpIds, unorderedEquals(['a', 'b']));
      expect(seqs(intake), [7]);
      expect(ordering.lastSeq, 7);
      expect(ordering.bufferedCount, 0);
    });

    test('buffered events above the snapshot drain when contiguous', () {
      final ordering = SeqOrdering(0)
        ..accept(renamed(9))
        ..accept(renamed(10))
        ..accept(renamed(11));

      final intake = ordering.rebase(8);

      expect(seqs(intake), [9, 10, 11]);
      expect(ordering.lastSeq, 11);
      expect(intake.hasGap, isFalse);
    });

    test('a hole above the snapshot keeps the gap open', () {
      final ordering = SeqOrdering(0)
        ..accept(renamed(9))
        ..accept(renamed(12));

      final intake = ordering.rebase(8);

      expect(seqs(intake), [9]);
      expect(intake.hasGap, isTrue);
      expect(ordering.firstBufferedSeq, 12);
    });

    test('after the rebase the old range is a duplicate', () {
      final ordering = SeqOrdering(0)..rebase(20);

      expect(ordering.accept(renamed(20)).ready, isEmpty);
      expect(seqs(ordering.accept(renamed(21))), [21]);
    });
  });

  group('shuffled delivery', () {
    List<BoardEvent> events(int count) => <BoardEvent>[
      for (var seq = 1; seq <= count; seq++)
        renamed(seq, opId: 'op-$seq', title: 'title-$seq'),
    ];

    test('1000 events in random order are applied once, in order', () {
      final source = events(1000);
      final shuffled = List<BoardEvent>.of(source)..shuffle(math.Random(20260));
      final ordering = SeqOrdering(0);
      final applied = <int>[];
      var board = makeBoard().copyWith(seq: 0);

      for (final event in shuffled) {
        final intake = ordering.accept(event);
        for (final ready in intake.ready) {
          applied.add(ready.seq);
          board = applyEvent(board, ready);
        }
      }

      expect(applied, [for (var seq = 1; seq <= 1000; seq++) seq]);
      expect(ordering.lastSeq, 1000);
      expect(ordering.hasGap, isFalse);
      expect(board.seq, 1000);
      expect(board.title, 'title-1000');
    });

    test('random order with random repeats converges the same way', () {
      final random = math.Random(99);
      final source = events(1000);
      final stream = <BoardEvent>[
        ...source,
        for (var i = 0; i < 700; i++) source[random.nextInt(source.length)],
      ]..shuffle(random);
      final ordering = SeqOrdering(0);
      final applied = <int>[];
      final resolved = <String>{};

      for (final event in stream) {
        final intake = ordering.accept(event);
        applied.addAll(seqs(intake));
        resolved.addAll(intake.duplicateOpIds);
      }

      expect(applied, [for (var seq = 1; seq <= 1000; seq++) seq]);
      expect(ordering.lastSeq, 1000);
      expect(resolved, isNotEmpty);
      expect(resolved.every((id) => id.startsWith('op-')), isTrue);
    });

    test('random order with a snapshot rebase in the middle converges', () {
      final random = math.Random(5);
      final stream = events(600)..shuffle(random);
      final ordering = SeqOrdering(0);
      final applied = <int>[];

      for (var i = 0; i < stream.length; i++) {
        if (i == 250) {
          applied.addAll(seqs(ordering.rebase(300)));
        }
        applied.addAll(seqs(ordering.accept(stream[i])));
      }

      expect(ordering.lastSeq, 600);
      expect(ordering.hasGap, isFalse);
      final afterSnapshot = applied.where((seq) => seq > 300).toList();
      expect(afterSnapshot, [for (var seq = 301; seq <= 600; seq++) seq]);
      expect(applied.toSet().length, applied.length);
      expect(applied, orderedEquals(List<int>.of(applied)..sort()));
    });
  });
}
