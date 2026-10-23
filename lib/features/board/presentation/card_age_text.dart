import '../../../l10n/app_localizations.dart';
import '../domain/relative_age.dart';

String describeCardAge(AppLocalizations l10n, RelativeAge age, DateTime then) {
  return switch (age.kind) {
    RelativeAgeKind.justNow => l10n.cardAgeJustNow,
    RelativeAgeKind.minutes => l10n.cardAgeMinutes(age.count),
    RelativeAgeKind.today => l10n.cardAgeToday,
    RelativeAgeKind.yesterday => l10n.cardAgeYesterday,
    RelativeAgeKind.days => l10n.cardAgeDays(age.count),
    RelativeAgeKind.date => l10n.cardAgeDate(then.toLocal()),
  };
}

String cardAgeText(AppLocalizations l10n, DateTime then, DateTime now) {
  return describeCardAge(l10n, relativeAge(then, now), then);
}
