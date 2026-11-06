import 'package:cardo/shared/widgets/rune_length_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _apply(int max, String text) {
  return RuneLengthLimitingFormatter(max).formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
}

void main() {
  test('keeps text within the limit untouched', () {
    expect(_apply(3, 'abc').text, 'abc');
  });

  test('truncates by runes and never splits a surrogate pair', () {
    final result = _apply(2, '😀😀😀');
    expect(result.text, '😀😀');
    expect(result.text.runes.length, 2);
    expect(result.selection.end, result.text.length);
  });

  test('a pasted string over the limit is cut to the limit', () {
    expect(_apply(5, 'abcdefghij').text, 'abcde');
  });
}
