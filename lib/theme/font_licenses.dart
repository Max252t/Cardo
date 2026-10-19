import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class CardoFontLicenses {
  static const Map<String, String> _files = <String, String>{
    'Bricolage Grotesque': 'assets/fonts/OFL-BricolageGrotesque.txt',
    'Geist': 'assets/fonts/OFL-Geist.txt',
    'Geist Mono': 'assets/fonts/OFL-GeistMono.txt',
  };

  static void register() {
    LicenseRegistry.addLicense(_entries);
  }

  static Stream<LicenseEntry> _entries() async* {
    for (final entry in _files.entries) {
      final text = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks(<String>[entry.key], text);
    }
  }
}
