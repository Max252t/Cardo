import 'dart:math' as math;

import 'realtime_policy.dart';

Duration reconnectDelay(
  int attempt,
  math.Random random, {
  Duration minimum = Duration.zero,
}) {
  final exponent = math.min(attempt, RealtimePolicy.maxBackoffExponent);
  final raw = RealtimePolicy.backoffBase.inMilliseconds * (1 << exponent);
  final capped = math.min(raw, RealtimePolicy.backoffMax.inMilliseconds);
  final jitter =
      1 + (random.nextDouble() * 2 - 1) * RealtimePolicy.backoffJitter;
  final jittered = (capped * jitter).round();
  return Duration(milliseconds: math.max(jittered, minimum.inMilliseconds));
}

int countdownSeconds(Duration delay) {
  final ms = delay.inMilliseconds;
  return ms <= 0 ? 0 : (ms + 999) ~/ 1000;
}
