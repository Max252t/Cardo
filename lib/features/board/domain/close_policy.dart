import '../../../core/realtime/realtime_policy.dart';

enum CloseAction {
  refreshAndReconnect,
  reconnect,
  reconnectSlow,
  reconnectAfterViolation,
  boardRemoved,
  boardDeleted,
}

CloseAction classifyClose(int? code) {
  return switch (code) {
    CloseCodes.tokenExpired => CloseAction.refreshAndReconnect,
    CloseCodes.accessRevoked => CloseAction.boardRemoved,
    CloseCodes.boardDeleted => CloseAction.boardDeleted,
    CloseCodes.rateAbuse => CloseAction.reconnectSlow,
    CloseCodes.protocolViolation => CloseAction.reconnectAfterViolation,
    _ => CloseAction.reconnect,
  };
}

bool isTerminalClose(CloseAction action) =>
    action == CloseAction.boardRemoved || action == CloseAction.boardDeleted;
