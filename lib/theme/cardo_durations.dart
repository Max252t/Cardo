abstract final class CardoDurations {
  static const Duration syncConfirmDelay = Duration(milliseconds: 700);
  static const Duration nackHold = Duration(milliseconds: 2400);
  static const Duration syncRetryDelay = Duration(milliseconds: 1500);
  static const Duration snackbar = Duration(seconds: 4);
  static const Duration lostDraftSnackbar = Duration(seconds: 10);
  static const Duration nowTick = Duration(minutes: 1);
  static const Duration selfExitWindow = Duration(seconds: 30);
  static const Duration boardsRefresh = Duration(seconds: 30);
}
