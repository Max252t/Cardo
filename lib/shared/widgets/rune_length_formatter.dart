import 'dart:math' as math;

import 'package:flutter/services.dart';

class RuneLengthLimitingFormatter extends TextInputFormatter {
  const RuneLengthLimitingFormatter(this.maxRunes);

  final int maxRunes;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= maxRunes) {
      return newValue;
    }
    final text = String.fromCharCodes(newValue.text.runes.take(maxRunes));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: math.min(newValue.selection.end, text.length),
      ),
    );
  }
}
