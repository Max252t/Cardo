import '../../../../core/network/api_failure.dart';
import '../../../../core/result/result.dart';
import '../../../boards/domain/board_info.dart';
import '../../domain/board_event.dart';

abstract interface class BoardCatchUpSource {
  Future<Result<EventsPage, ApiFailure>> getEvents(
    String boardId,
    int afterSeq,
  );

  Future<Result<ServerBoard, ApiFailure>> getBoard(String boardId);
}
