import 'dart:ui';

const Locale fallbackAppLocale = Locale('en');

Locale resolveAppLocale(List<Locale>? device, Iterable<Locale> supported) {
  final options = supported.toList(growable: false);
  if (options.isEmpty) {
    return fallbackAppLocale;
  }
  for (final wanted in device ?? const <Locale>[]) {
    for (final option in options) {
      if (option.languageCode == wanted.languageCode &&
          option.scriptCode == wanted.scriptCode &&
          option.countryCode == wanted.countryCode) {
        return option;
      }
    }
    for (final option in options) {
      if (option.languageCode == wanted.languageCode) {
        return option;
      }
    }
  }
  for (final option in options) {
    if (option.languageCode == fallbackAppLocale.languageCode) {
      return option;
    }
  }
  return options.first;
}
