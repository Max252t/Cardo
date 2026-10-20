import 'dart:math';

import 'package:cardo/core/ranking/rank.dart';
import 'package:flutter_test/flutter_test.dart';

String _randomRank(Random random, {int maxLength = 6}) {
  final length = 1 + random.nextInt(maxLength);
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    final isLast = i == length - 1;
    final index = isLast
        ? 1 + random.nextInt(rankAlphabet.length - 1)
        : random.nextInt(rankAlphabet.length);
    buffer.write(rankAlphabet[index]);
  }
  return buffer.toString();
}

int _byteCompare(String a, String b) {
  final left = a.codeUnits;
  final right = b.codeUnits;
  final shared = min(left.length, right.length);
  for (var i = 0; i < shared; i++) {
    if (left[i] != right[i]) {
      return left[i].compareTo(right[i]);
    }
  }
  return left.length.compareTo(right.length);
}

void main() {
  group('alphabet', () {
    test('has 62 strictly ascending ASCII digits', () {
      expect(rankAlphabet.length, 62);
      final units = rankAlphabet.codeUnits;
      for (var i = 1; i < units.length; i++) {
        expect(units[i], greaterThan(units[i - 1]));
      }
    });

    test('isValidRank accepts base62 without trailing zero', () {
      expect(isValidRank('V'), isTrue);
      expect(isValidRank('a0b'), isTrue);
      expect(isValidRank('zzzz'), isTrue);
    });

    test('isValidRank rejects empty, trailing zero and foreign chars', () {
      expect(isValidRank(''), isFalse);
      expect(isValidRank('a0'), isFalse);
      expect(isValidRank('0'), isFalse);
      expect(isValidRank('a-b'), isFalse);
      expect(isValidRank('a b'), isFalse);
      expect(isValidRank('ыa'), isFalse);
    });
  });

  group('rankInitial', () {
    test('is a valid single middle digit', () {
      final initial = rankInitial();
      expect(isValidRank(initial), isTrue);
      expect(initial.length, 1);
      expect(rankBetween(null, null), initial);
    });
  });

  group('rankBetween property', () {
    test('a < rankBetween(a, b) < b on 2000 random pairs', () {
      final random = Random(20260519);
      var checked = 0;
      while (checked < 2000) {
        final x = _randomRank(random);
        final y = _randomRank(random);
        if (x == y) {
          continue;
        }
        final a = x.compareTo(y) < 0 ? x : y;
        final b = x.compareTo(y) < 0 ? y : x;
        final mid = rankBetween(a, b);
        expect(isValidRank(mid), isTrue, reason: '$a / $b -> $mid');
        expect(compareRanks(a, mid), lessThan(0), reason: '$a / $b -> $mid');
        expect(compareRanks(mid, b), lessThan(0), reason: '$a / $b -> $mid');
        checked++;
      }
      expect(checked, 2000);
    });

    test('a < rankBetween(a, null) on random ranks', () {
      final random = Random(7);
      for (var i = 0; i < 500; i++) {
        final a = _randomRank(random);
        final next = rankBetween(a, null);
        expect(isValidRank(next), isTrue);
        expect(compareRanks(a, next), lessThan(0), reason: '$a -> $next');
      }
    });

    test('rankBetween(null, b) < b on random ranks', () {
      final random = Random(11);
      for (var i = 0; i < 500; i++) {
        final b = _randomRank(random);
        final prev = rankBetween(null, b);
        expect(isValidRank(prev), isTrue, reason: '$b -> $prev');
        expect(compareRanks(prev, b), lessThan(0), reason: '$b -> $prev');
      }
    });

    test('is deterministic', () {
      expect(rankBetween('a', 'c'), rankBetween('a', 'c'));
    });
  });

  group('rankBetween edges', () {
    test('null and null gives the initial rank', () {
      expect(rankBetween(null, null), rankInitial());
    });

    test('null and b gives a smaller rank', () {
      final result = rankBetween(null, 'V');
      expect(compareRanks(result, 'V'), lessThan(0));
      expect(isValidRank(result), isTrue);
    });

    test('a and null gives a greater rank', () {
      final result = rankBetween('V', null);
      expect(compareRanks('V', result), lessThan(0));
      expect(isValidRank(result), isTrue);
    });

    test('before the smallest representable single digit', () {
      final result = rankBetween(null, '1');
      expect(compareRanks(result, '1'), lessThan(0));
      expect(isValidRank(result), isTrue);
    });

    test('after the largest digit', () {
      final result = rankBetween('z', null);
      expect(compareRanks('z', result), lessThan(0));
      expect(isValidRank(result), isTrue);
    });

    test('adjacent single digits extend the length', () {
      final result = rankBetween('a', 'b');
      expect(result.length, greaterThan(1));
      expect(compareRanks('a', result), lessThan(0));
      expect(compareRanks(result, 'b'), lessThan(0));
    });

    test('adjacent with shared long prefix', () {
      final result = rankBetween('abcdefgh', 'abcdefgi');
      expect(compareRanks('abcdefgh', result), lessThan(0));
      expect(compareRanks(result, 'abcdefgi'), lessThan(0));
      expect(isValidRank(result), isTrue);
    });

    test('a is a prefix of b', () {
      final result = rankBetween('V', 'V1');
      expect(compareRanks('V', result), lessThan(0));
      expect(compareRanks(result, 'V1'), lessThan(0));
      expect(isValidRank(result), isTrue);
    });

    test('very long ranks', () {
      final a = '${'z' * 80}1';
      final b = '${'z' * 80}2';
      final result = rankBetween(a, b);
      expect(compareRanks(a, result), lessThan(0));
      expect(compareRanks(result, b), lessThan(0));
      expect(isValidRank(result), isTrue);
    });

    test('200 insertions in a row at the same point stay ordered', () {
      const left = 'V';
      var right = 'W';
      final produced = <String>[];
      for (var i = 0; i < 200; i++) {
        final mid = rankBetween(left, right);
        expect(isValidRank(mid), isTrue, reason: 'step $i: $mid');
        expect(compareRanks(left, mid), lessThan(0), reason: 'step $i');
        expect(compareRanks(mid, right), lessThan(0), reason: 'step $i');
        produced.add(mid);
        right = mid;
      }
      final sorted = List<String>.of(produced)..sort(compareRanks);
      expect(sorted, produced.reversed.toList());
      expect(produced.toSet().length, produced.length);
    });

    test('200 insertions in a row right after the left anchor', () {
      var left = 'V';
      const right = 'W';
      final produced = <String>[];
      for (var i = 0; i < 200; i++) {
        final mid = rankBetween(left, right);
        expect(compareRanks(left, mid), lessThan(0), reason: 'step $i');
        expect(compareRanks(mid, right), lessThan(0), reason: 'step $i');
        produced.add(mid);
        left = mid;
      }
      final sorted = List<String>.of(produced)..sort(compareRanks);
      expect(sorted, produced);
    });

    test('200 appends and 200 prepends stay ordered', () {
      final tail = <String>[rankInitial()];
      for (var i = 0; i < 200; i++) {
        tail.add(rankBetween(tail.last, null));
      }
      final head = <String>[rankInitial()];
      for (var i = 0; i < 200; i++) {
        head.add(rankBetween(null, head.last));
      }
      for (var i = 1; i < tail.length; i++) {
        expect(compareRanks(tail[i - 1], tail[i]), lessThan(0));
      }
      for (var i = 1; i < head.length; i++) {
        expect(compareRanks(head[i], head[i - 1]), lessThan(0));
        expect(isValidRank(head[i]), isTrue);
      }
    });
  });

  group('rankBetween rejects bad input', () {
    test('a equal to b', () {
      expect(() => rankBetween('V', 'V'), throwsArgumentError);
    });

    test('a greater than b', () {
      expect(() => rankBetween('c', 'a'), throwsArgumentError);
    });

    test('invalid a', () {
      expect(() => rankBetween('a-', 'b'), throwsArgumentError);
      expect(() => rankBetween('a0', 'b'), throwsArgumentError);
      expect(() => rankBetween('', 'b'), throwsArgumentError);
    });

    test('invalid b', () {
      expect(() => rankBetween('a', 'b#'), throwsArgumentError);
      expect(() => rankBetween(null, 'b0'), throwsArgumentError);
      expect(() => rankBetween(null, ''), throwsArgumentError);
    });

    test('invalid single anchor', () {
      expect(() => rankBetween('ы', null), throwsArgumentError);
      expect(() => rankBetween(null, 'ы'), throwsArgumentError);
    });
  });

  group('ranksSequence', () {
    test('is empty for zero', () {
      expect(ranksSequence(0), isEmpty);
    });

    test('starts at the initial rank', () {
      expect(ranksSequence(1), <String>[rankInitial()]);
    });

    test('is strictly increasing and valid', () {
      for (final count in <int>[2, 5, 30, 120, 500]) {
        final ranks = ranksSequence(count);
        expect(ranks.length, count);
        for (var i = 0; i < ranks.length; i++) {
          expect(isValidRank(ranks[i]), isTrue, reason: ranks[i]);
          if (i > 0) {
            expect(
              compareRanks(ranks[i - 1], ranks[i]),
              lessThan(0),
              reason: '$count at $i',
            );
          }
        }
      }
    });
  });

  group('compareRanks', () {
    test('matches byte-wise comparison on random ranks', () {
      final random = Random(99);
      for (var i = 0; i < 2000; i++) {
        final a = _randomRank(random, maxLength: 5);
        final b = _randomRank(random, maxLength: 5);
        expect(
          compareRanks(a, b).sign,
          _byteCompare(a, b).sign,
          reason: '$a vs $b',
        );
      }
    });

    test('uppercase sorts before lowercase and digits before letters', () {
      expect(compareRanks('9', 'A'), lessThan(0));
      expect(compareRanks('Z', 'a'), lessThan(0));
      expect(compareRanks('a', 'a1'), lessThan(0));
      expect(compareRanks('a', 'a'), 0);
    });
  });
}
