import '../domain/board_op.dart';
import '../domain/board_session.dart';
import 'realtime/protocol_issue.dart';
import 'sync_signal.dart';

enum SendOutcome { sent, notConnected, tooLarge }

abstract interface class BoardGateway {
  BoardSnapshot snapshot();

  Stream<SyncSignal> get signals;

  Stream<ProtocolIssue> get issues;

  void connect();

  SendOutcome send(BoardOp op);

  void retryNow();

  Future<void> close();

  Future<void> dispose();
}
