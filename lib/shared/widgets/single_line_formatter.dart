import 'package:flutter/services.dart';

final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F-\u009F]');

class SingleLineFormatter extends TextInputFormatter {
  const SingleLineFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!_controlCharacters.hasMatch(newValue.text)) {
      return newValue;
    }
    return newValue.copyWith(
      text: newValue.text.replaceAll(_controlCharacters, ' '),
    );
  }
}
