const String rankAlphabet =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

const int _base = rankAlphabet.length;

int _digit(String char) {
  final index = rankAlphabet.indexOf(char);
  if (index < 0) {
    throw ArgumentError.value(char, 'char', 'not a base62 digit');
  }
  return index;
}

bool isValidRank(String rank) {
  if (rank.isEmpty || rank.endsWith(rankAlphabet[0])) {
    return false;
  }
  for (var i = 0; i < rank.length; i++) {
    if (!rankAlphabet.contains(rank[i])) {
      return false;
    }
  }
  return true;
}

int compareRanks(String a, String b) => a.compareTo(b);

String rankInitial() => rankAlphabet[_base ~/ 2];

String rankBetween(String? a, String? b) {
  if (a != null && !isValidRank(a)) {
    throw ArgumentError.value(a, 'a', 'invalid rank');
  }
  if (b != null && !isValidRank(b)) {
    throw ArgumentError.value(b, 'b', 'invalid rank');
  }
  if (a != null && b != null && compareRanks(a, b) >= 0) {
    throw ArgumentError('rankBetween requires a < b, got "$a" >= "$b"');
  }
  return _midpoint(a ?? '', b);
}

String _midpoint(String a, String? b) {
  if (b != null) {
    var n = 0;
    while (n < b.length && (n < a.length ? a[n] : rankAlphabet[0]) == b[n]) {
      n++;
    }
    if (n > 0) {
      return b.substring(0, n) +
          _midpoint(a.length > n ? a.substring(n) : '', b.substring(n));
    }
  }
  final digitA = a.isNotEmpty ? _digit(a[0]) : 0;
  final digitB = b != null ? _digit(b[0]) : _base;
  if (digitB - digitA > 1) {
    return rankAlphabet[(digitA + digitB) ~/ 2];
  }
  if (b != null && b.length > 1) {
    return b.substring(0, 1);
  }
  return rankAlphabet[digitA] +
      _midpoint(a.length > 1 ? a.substring(1) : '', null);
}

List<String> ranksSequence(int count) {
  final result = <String>[];
  String? previous;
  for (var i = 0; i < count; i++) {
    previous = previous == null ? rankInitial() : rankBetween(previous, null);
    result.add(previous);
  }
  return result;
}
