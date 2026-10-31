import 'package:cardo/features/board/domain/relative_age.dart';
import 'package:cardo/features/board/presentation/card_age_text.dart';
import 'package:cardo/l10n/app_localizations.dart';
import 'package:cardo/l10n/app_localizations_ru.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

RelativeAge _age(DateTime then, DateTime now) => relativeAge(then, now);

void main() {
  final now = DateTime(2026, 1, 15, 12);

  group('relativeAge', () {
    test('0 seconds is just now', () {
      expect(_age(now, now).kind, RelativeAgeKind.justNow);
    });

    test('59 seconds is just now', () {
      expect(
        _age(now.subtract(const Duration(seconds: 59)), now).kind,
        RelativeAgeKind.justNow,
      );
    });

    test('1 minute flips to minutes', () {
      expect(
        _age(now.subtract(const Duration(minutes: 1)), now),
        const RelativeAge(RelativeAgeKind.minutes, 1),
      );
    });

    test('59 minutes stays in minutes', () {
      expect(
        _age(now.subtract(const Duration(minutes: 59, seconds: 59)), now),
        const RelativeAge(RelativeAgeKind.minutes, 59),
      );
    });

    test('1 hour on the same day is today', () {
      expect(
        _age(now.subtract(const Duration(hours: 1)), now).kind,
        RelativeAgeKind.today,
      );
      expect(
        _age(DateTime(2026, 1, 15, 0, 5), DateTime(2026, 1, 15, 23, 59)).kind,
        RelativeAgeKind.today,
      );
    });

    test('a future time counts as just now', () {
      expect(
        _age(now.add(const Duration(minutes: 5)), now).kind,
        RelativeAgeKind.justNow,
      );
    });

    test('yesterday follows the local calendar around midnight', () {
      expect(
        _age(DateTime(2026, 1, 14, 23, 59), DateTime(2026, 1, 15, 0, 1)).kind,
        RelativeAgeKind.minutes,
      );
      expect(
        _age(DateTime(2026, 1, 14, 23, 0), DateTime(2026, 1, 15, 0, 5)).kind,
        RelativeAgeKind.yesterday,
      );
      expect(
        _age(DateTime(2026, 1, 14, 0, 1), DateTime(2026, 1, 15, 23, 59)).kind,
        RelativeAgeKind.yesterday,
      );
    });

    test('less than 24 hours but a different day is yesterday', () {
      expect(
        _age(DateTime(2026, 1, 14, 23, 30), DateTime(2026, 1, 15, 8)).kind,
        RelativeAgeKind.yesterday,
      );
    });

    test('more than 24 hours but two calendar days is days', () {
      expect(
        _age(DateTime(2026, 1, 13, 23, 59), DateTime(2026, 1, 15, 0, 30)),
        const RelativeAge(RelativeAgeKind.days, 2),
      );
    });

    test('2 and 6 days are relative', () {
      expect(
        _age(DateTime(2026, 1, 13, 12), now),
        const RelativeAge(RelativeAgeKind.days, 2),
      );
      expect(
        _age(DateTime(2026, 1, 9, 12), now),
        const RelativeAge(RelativeAgeKind.days, 6),
      );
    });

    test('7 and more days become a date', () {
      expect(_age(DateTime(2026, 1, 8, 12), now).kind, RelativeAgeKind.date);
      expect(_age(DateTime(2025, 6, 1), now).kind, RelativeAgeKind.date);
    });

    test('utc inputs are interpreted in the local calendar', () {
      final then = DateTime.utc(2026, 1, 14, 12);
      final current = DateTime.utc(2026, 1, 15, 12);
      expect(_age(then, current).kind, RelativeAgeKind.yesterday);
    });
  });

  group('describeCardAge in Russian', () {
    final l10n = AppLocalizationsRu();

    setUpAll(() => initializeDateFormatting('ru'));
    String text(RelativeAge age, [DateTime? then]) =>
        describeCardAge(l10n, age, then ?? DateTime(2026, 1, 1));

    test('fixed phrases', () {
      expect(text(const RelativeAge(RelativeAgeKind.justNow)), 'только что');
      expect(text(const RelativeAge(RelativeAgeKind.today)), 'сегодня');
      expect(text(const RelativeAge(RelativeAgeKind.yesterday)), 'вчера');
    });

    test('minutes use ICU plural forms', () {
      String minutes(int n) => text(RelativeAge(RelativeAgeKind.minutes, n));
      expect(minutes(1), '1 минуту назад');
      expect(minutes(2), '2 минуты назад');
      expect(minutes(4), '4 минуты назад');
      expect(minutes(5), '5 минут назад');
      expect(minutes(11), '11 минут назад');
      expect(minutes(21), '21 минуту назад');
      expect(minutes(22), '22 минуты назад');
      expect(minutes(59), '59 минут назад');
    });

    test('days use ICU plural forms', () {
      String days(int n) => text(RelativeAge(RelativeAgeKind.days, n));
      expect(days(1), '1 день назад');
      expect(days(2), '2 дня назад');
      expect(days(5), '5 дней назад');
      expect(days(6), '6 дней назад');
    });

    test('date is formatted for the locale', () {
      final value = text(
        const RelativeAge(RelativeAgeKind.date),
        DateTime(2025, 12, 3),
      );
      expect(value, contains('2025'));
      expect(value, contains('3'));
    });

    test('the l10n delegate resolves Russian', () {
      expect(
        AppLocalizations.supportedLocales.map((l) => l.languageCode),
        contains('ru'),
      );
    });
  });
}
