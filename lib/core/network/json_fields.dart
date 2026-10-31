Map<String, dynamic> asJsonMap(Object? value, [String name = 'object']) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw FormatException('Expected $name to be a JSON object');
}

String readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Missing string field "$key"');
}

String readNonEmptyString(Map<String, dynamic> json, String key) {
  final value = readString(json, key);
  if (value.isEmpty) {
    throw FormatException('Empty string field "$key"');
  }
  return value;
}

int readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Missing integer field "$key"');
}

DateTime readDate(Map<String, dynamic> json, String key) {
  final parsed = DateTime.tryParse(readString(json, key));
  if (parsed == null) {
    throw FormatException('Invalid date field "$key"');
  }
  return parsed.toUtc();
}

List<Map<String, dynamic>> readObjectList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is! List<dynamic>) {
    throw FormatException('Missing array field "$key"');
  }
  return <Map<String, dynamic>>[
    for (final item in value) asJsonMap(item, '$key item'),
  ];
}

String normalizeAvatarColor(String value) {
  final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(value.trim());
  if (match == null) {
    throw FormatException('Invalid avatar color "$value"');
  }
  return '#${match.group(1)!.toUpperCase()}';
}
