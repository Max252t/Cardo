import 'dart:convert';

enum FieldIssue { empty, tooShort, tooLong, invalidFormat }

abstract final class AuthLimits {
  static const int nameMax = 100;
  static const int emailMax = 254;
  static const int passwordMin = 8;
  static const int passwordMax = 128;
}

abstract final class AuthValidators {
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static FieldIssue? name(String value) {
    final length = value.trim().runes.length;
    if (length == 0) {
      return FieldIssue.empty;
    }
    return length > AuthLimits.nameMax ? FieldIssue.tooLong : null;
  }

  static FieldIssue? email(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return FieldIssue.empty;
    }
    if (utf8.encode(trimmed.toLowerCase()).length > AuthLimits.emailMax) {
      return FieldIssue.tooLong;
    }
    return _email.hasMatch(trimmed) ? null : FieldIssue.invalidFormat;
  }

  static FieldIssue? loginEmail(String value) {
    return value.trim().isEmpty ? FieldIssue.empty : null;
  }

  static FieldIssue? loginPassword(String value) {
    return value.isEmpty ? FieldIssue.empty : null;
  }

  static FieldIssue? newPassword(String value) {
    if (value.isEmpty) {
      return FieldIssue.empty;
    }
    final length = value.runes.length;
    if (length < AuthLimits.passwordMin) {
      return FieldIssue.tooShort;
    }
    return length > AuthLimits.passwordMax ? FieldIssue.tooLong : null;
  }
}
