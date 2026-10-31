import '../domain/board_op.dart';
import '../domain/board_session.dart';

abstract interface class BoardGateway {
  BoardSnapshot snapshot();

  Future<OpOutcome> submit(BoardOp op);
}

abstract interface class BoardRemoteFeed implements BoardGateway {
  Stream<RemoteCardUpdate> get remoteUpdates;
}
