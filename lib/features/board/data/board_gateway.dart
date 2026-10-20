import '../domain/board_op.dart';
import '../domain/board_session.dart';

abstract interface class BoardGateway {
  BoardSnapshot snapshot();

  Future<OpOutcome> submit(BoardOp op);
}
