import 'package:cardo/shared/widgets/single_line_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _apply(String text) {
  return const SingleLineFormatter().formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
}

void main() {
  test('leaves a plain line untouched', () {
    expect(_apply('a b').text, 'a b');
  });

  test('replaces line breaks and tabs with a space', () {
    expect(_apply('a\nb\r\nc\td').text, 'a b  c d');
  });

  test('replaces the control characters the server rejects', () {
    expect(_apply('a\u0000b\u007Fc\u0085d').text, 'a b c d');
  });

  test('keeps the length and the selection', () {
    final result = _apply('ab\ncd');
    expect(result.text.length, 5);
    expect(result.selection, const TextSelection.collapsed(offset: 5));
  });

  test('keeps emoji', () {
    expect(_apply('😀\n😀').text, '😀 😀');
  });
}
