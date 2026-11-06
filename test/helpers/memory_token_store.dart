import 'package:cardo/features/auth/domain/auth_tokens.dart';
import 'package:cardo/features/auth/domain/token_store.dart';

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.current]);

  RefreshCredential? current;
  final List<String> log = <String>[];
  Future<void>? writeGate;
  bool failOnRead = false;
  bool failOnWrite = false;
  bool failOnClear = false;

  int get writes => log.where((entry) => entry == 'write').length;

  int get clears => log.where((entry) => entry == 'clear').length;

  @override
  Future<RefreshCredential?> read() async {
    log.add('read');
    if (failOnRead) {
      throw Exception('read failed');
    }
    return current;
  }

  @override
  Future<void> write(RefreshCredential credential) async {
    if (failOnWrite) {
      throw Exception('write failed');
    }
    final gate = writeGate;
    if (gate != null) {
      await gate;
    }
    log.add('write');
    current = credential;
  }

  @override
  Future<void> clear() async {
    if (failOnClear) {
      throw Exception('clear failed');
    }
    log.add('clear');
    current = null;
  }
}
