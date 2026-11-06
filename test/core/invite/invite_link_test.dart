import 'package:cardo/core/invite/invite_link.dart';
import 'package:flutter_test/flutter_test.dart';

const String _token = 'Zm9vYmFyYmF6cXV4LXF1dXhfY29yZ2VfZ3JhdWx0d2Fs';

void main() {
  test('build makes an app link with the token', () {
    expect(InviteLink.build(_token), 'cardo://invite/$_token');
  });

  test('parse reads back what build makes', () {
    expect(InviteLink.parse(InviteLink.build(_token)), _token);
  });

  test('parse accepts a raw token with surrounding spaces', () {
    expect(InviteLink.parse('  $_token \n'), _token);
  });

  test('parse accepts a web link with an invite path', () {
    expect(InviteLink.parse('https://cardo.example/invite/$_token'), _token);
  });

  test('parse rejects text that is not an invite', () {
    expect(InviteLink.parse(''), isNull);
    expect(InviteLink.parse('hello'), isNull);
    expect(InviteLink.parse('cardo://board/$_token'), isNull);
    expect(InviteLink.parse('https://cardo.example/boards/$_token'), isNull);
    expect(InviteLink.parse('cardo://invite/'), isNull);
    expect(InviteLink.parse('cardo://invite/bad token!'), isNull);
    expect(InviteLink.parse('cardo://invite/$_token/extra'), isNull);
  });
}
