import 'package:cardo/features/board/domain/relative_age.dart';
import 'package:cardo/features/board/presentation/card_age_text.dart';
import 'package:cardo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final l10n = AppLocalizationsEn();

  setUpAll(() => initializeDateFormatting('en'));

  String text(RelativeAge age, [DateTime? then]) =>
      describeCardAge(l10n, age, then ?? DateTime(2026, 1, 1));

  group('describeCardAge in English', () {
    test('fixed phrases', () {
      expect(text(const RelativeAge(RelativeAgeKind.justNow)), 'just now');
      expect(text(const RelativeAge(RelativeAgeKind.today)), 'today');
      expect(text(const RelativeAge(RelativeAgeKind.yesterday)), 'yesterday');
    });

    test('minutes use singular and plural', () {
      String minutes(int n) => text(RelativeAge(RelativeAgeKind.minutes, n));
      expect(minutes(1), '1 minute ago');
      expect(minutes(2), '2 minutes ago');
      expect(minutes(21), '21 minutes ago');
      expect(minutes(59), '59 minutes ago');
    });

    test('days use singular and plural', () {
      String days(int n) => text(RelativeAge(RelativeAgeKind.days, n));
      expect(days(1), '1 day ago');
      expect(days(2), '2 days ago');
      expect(days(5), '5 days ago');
      expect(days(6), '6 days ago');
    });

    test('date is formatted for English', () {
      expect(
        text(const RelativeAge(RelativeAgeKind.date), DateTime(2025, 12, 3)),
        'Dec 3, 2025',
      );
    });
  });

  group('cardAgeText in English', () {
    final now = DateTime(2026, 1, 15, 12);

    test('goes from the timestamps', () {
      expect(cardAgeText(l10n, now, now), 'just now');
      expect(
        cardAgeText(l10n, now.subtract(const Duration(minutes: 1)), now),
        '1 minute ago',
      );
      expect(
        cardAgeText(l10n, now.subtract(const Duration(minutes: 2)), now),
        '2 minutes ago',
      );
      expect(cardAgeText(l10n, DateTime(2026, 1, 14, 9), now), 'yesterday');
      expect(cardAgeText(l10n, DateTime(2026, 1, 12, 9), now), '3 days ago');
      expect(cardAgeText(l10n, DateTime(2025, 6, 1), now), 'Jun 1, 2025');
    });
  });
}
