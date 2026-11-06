enum RelativeAgeKind { justNow, minutes, today, yesterday, days, date }

class RelativeAge {
  const RelativeAge(this.kind, [this.count = 0]);

  final RelativeAgeKind kind;
  final int count;

  @override
  bool operator ==(Object other) {
    return other is RelativeAge && other.kind == kind && other.count == count;
  }

  @override
  int get hashCode => Object.hash(kind, count);

  @override
  String toString() => 'RelativeAge(${kind.name}, $count)';
}

const int _maxRelativeDays = 6;

RelativeAge relativeAge(DateTime then, DateTime now) {
  final elapsed = now.difference(then);
  if (elapsed < const Duration(minutes: 1)) {
    return const RelativeAge(RelativeAgeKind.justNow);
  }
  if (elapsed < const Duration(hours: 1)) {
    return RelativeAge(RelativeAgeKind.minutes, elapsed.inMinutes);
  }
  final thenDay = _dayOf(then.toLocal());
  final nowDay = _dayOf(now.toLocal());
  final days = nowDay.difference(thenDay).inDays;
  if (days <= 0) {
    return const RelativeAge(RelativeAgeKind.today);
  }
  if (days == 1) {
    return const RelativeAge(RelativeAgeKind.yesterday);
  }
  if (days <= _maxRelativeDays) {
    return RelativeAge(RelativeAgeKind.days, days);
  }
  return const RelativeAge(RelativeAgeKind.date);
}

DateTime _dayOf(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
