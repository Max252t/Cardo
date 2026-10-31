class AppConfig {
  const AppConfig._({required this.rawValue, required this.apiBaseUri});

  factory AppConfig.fromEnvironment() =>
      AppConfig.parse(const String.fromEnvironment(apiBaseUrlKey));

  factory AppConfig.parse(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    final valid =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.userInfo.isEmpty;
    return AppConfig._(rawValue: trimmed, apiBaseUri: valid ? uri : null);
  }

  static const String apiBaseUrlKey = 'API_BASE_URL';

  final String rawValue;
  final Uri? apiBaseUri;

  bool get isValid => apiBaseUri != null;

  Uri? get wsBaseUri {
    final base = apiBaseUri;
    if (base == null) {
      return null;
    }
    return base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws');
  }

  @override
  bool operator ==(Object other) =>
      other is AppConfig && other.rawValue == rawValue;

  @override
  int get hashCode => rawValue.hashCode;
}
