abstract final class InviteLink {
  static const String scheme = 'cardo';
  static const String host = 'invite';

  static final RegExp _token = RegExp(r'^[A-Za-z0-9_-]{16,128}$');

  static String build(String token) =>
      Uri(scheme: scheme, host: host, path: '/$token').toString();

  static String? parse(String input) {
    final text = input.trim();
    if (_token.hasMatch(text)) {
      return text;
    }
    final uri = Uri.tryParse(text);
    if (uri == null) {
      return null;
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final String? candidate;
    if (uri.scheme == scheme && uri.host == host && segments.length == 1) {
      candidate = segments.single;
    } else if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        segments.length == 2 &&
        segments.first == host) {
      candidate = segments.last;
    } else {
      candidate = null;
    }
    if (candidate == null || !_token.hasMatch(candidate)) {
      return null;
    }
    return candidate;
  }
}
